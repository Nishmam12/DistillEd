// Brings PDFs and photos into Canvas 2.0 as ordinary [ImageElement]s.
//
// Canvas 2.0 had no import path at all: `lib/features/import/` and the
// `ImportedContent` model belong to the legacy 1.0 editor, and 2.0 could render
// an [ImageElement] but never create one. This is that missing half.
//
// What is deliberately NOT reused from the legacy side:
//  * `ImportedContent` — an Isar-embedded model whose `pdfBackground` factory
//    hardcodes a zero rect, because the legacy renderer drew backgrounds
//    full-page and ignored it. 2.0 computes real rects (see fit_image_rect.dart).
//  * `ImageService` — coupled to `PdfCacheManager`; 2.0 caches through
//    [SceneImageCache] instead, and needs the source pixel size back, which the
//    legacy path never returned.
//
// What IS reused: [PDFService.renderAll], which already renders every page in a
// background isolate and caches it on disk under a content hash, so re-importing
// the same PDF costs nothing and cannot collide with a different one.

import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/storage_paths.dart';
import '../../features/import/pdf_service.dart';
import 'document_scanner_port.dart';
import 'png_size.dart';

/// One imported picture, ready to be turned into an [ImageElement] once the
/// caller has decided where it goes.
typedef ImportedImage = ({
  /// Path relative to the app documents dir — never absolute, since those
  /// change between installs. [SceneImageCache] resolves it.
  String relativePath,

  /// Source dimensions, for aspect-fitting. [Size.zero] when they could not be
  /// determined, which callers treat as "fill the target".
  Size pixelSize,

  /// Human-readable provenance, e.g. "lecture.pdf — Page 3".
  String description,
});

/// Largest edge an imported photo is kept at. Matches the legacy import: past
/// this, a phone photo is mostly storage and decode time, not detail.
const int kMaxImportedImageEdge = 2048;

class SceneImportService {
  final PDFService _pdf;
  final ImagePicker _picker;
  final DocumentScannerPort? _scanner;
  final Future<String> Function() _documentsDir;

  /// [scanner] is optional: without one (or on a device that can't scan) the
  /// camera entry is a plain photo. [documentsDir] exists so tests need no
  /// platform channel.
  SceneImportService({
    PDFService? pdf,
    ImagePicker? picker,
    DocumentScannerPort? scanner,
    Future<String> Function()? documentsDir,
  })  : _pdf = pdf ?? PDFService(),
        _picker = picker ?? ImagePicker(),
        _scanner = scanner,
        _documentsDir = documentsDir ??
            (() async => (await getApplicationDocumentsDirectory()).path);

  /// Whether the camera entry opens the document scanner rather than the plain
  /// camera — what the import sheet labels itself from.
  bool get canScan => _scanner?.isSupported ?? false;

  /// Lets the user choose a PDF. Null when they cancel.
  Future<String?> pickPdfPath() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    return file?.path;
  }

  /// A fresh identifier for one import, stamped onto every page it produces
  /// ([NotePage.importGroupId]).
  ///
  /// Minted per CALL rather than derived from the file, deliberately: importing
  /// the same lecture twice is two separate documents in the notebook, and the
  /// student asking about "this PDF" means the one they are looking at, not
  /// both copies interleaved.
  static String newImportGroupId() =>
      'import-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';

  /// The file's own name (`lecture.pdf`) from a full [filePath] — the label a
  /// scope menu shows for a "whole PDF" choice.
  static String importSourceNameOf(String filePath) {
    final parts = filePath.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? filePath : parts.last;
  }

  /// Renders every page of the PDF at [filePath], one [ImportedImage] per page
  /// in document order.
  ///
  /// Throws [ImportException] when the file is missing or not a PDF.
  Future<List<ImportedImage>> importPdf(
      String filePath, String notebookId) async {
    final pages = await _pdf.renderAll(filePath, notebookId);
    final docsDir = await _documentsDir();

    final out = <ImportedImage>[];
    for (final page in pages) {
      if (page.relativeImagePath.isEmpty) continue;
      out.add((
        relativePath: page.relativeImagePath,
        pixelSize: await _pngSizeOf('$docsDir/${page.relativeImagePath}'),
        description: page.sourceDescription,
      ));
    }
    return out;
  }

  /// Picks a photo from [source], downscales and re-encodes it off the main
  /// thread, and stores it under the notebook's imports directory. Null when
  /// the user cancels.
  ///
  /// Throws [ImportException] when the picked file cannot be decoded.
  Future<ImportedImage?> importPhoto(
      ImageSource source, String notebookId) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return null;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final relativePath =
        StoragePaths.getFreeImageCacheRelativePath(notebookId, id);
    final docsDir = await _documentsDir();

    final size = await compute(
      _compressAndSave,
      (source: picked.path, destination: '$docsDir/$relativePath'),
    );
    if (size == null) {
      throw const ImportException('That image could not be read.');
    }

    return (
      relativePath: relativePath,
      pixelSize: size,
      description: picked.name,
    );
  }

  /// What the camera entry does: scan a document where the device can, take a
  /// plain photo where it can't — or where the scanner failed to start, so a
  /// missing Google Play service never leaves the user with no camera at all.
  /// Empty when the user backs out of either.
  Future<List<ImportedImage>> importCapture(String notebookId) async {
    if (canScan) {
      try {
        return await importScan(notebookId);
      } on ScanUnavailableException {
        // Fall through to the plain camera.
      }
    }
    final photo = await importPhoto(ImageSource.camera, notebookId);
    return photo == null ? const [] : [photo];
  }

  /// Runs the document scanner and stores each scanned page the way a photo is
  /// stored (downscaled, re-encoded, off the main thread). Empty when the user
  /// backs out.
  ///
  /// Throws [ScanUnavailableException] when there is no scanner or it cannot
  /// start, and [ImportException] when a scanned page cannot be decoded.
  Future<List<ImportedImage>> importScan(String notebookId) async {
    final scanner = _scanner;
    if (scanner == null) throw const ScanUnavailableException('no scanner');

    final paths = await scanner.scan();
    if (paths.isEmpty) return const [];

    final docsDir = await _documentsDir();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final out = <ImportedImage>[];
    for (var i = 0; i < paths.length; i++) {
      final relativePath =
          StoragePaths.getFreeImageCacheRelativePath(notebookId, '${stamp}_$i');
      final size = await compute(
        _compressAndSave,
        (source: paths[i], destination: '$docsDir/$relativePath'),
      );
      if (size == null) {
        throw const ImportException('That scan could not be read.');
      }
      out.add((
        relativePath: relativePath,
        pixelSize: size,
        description: 'Scanned page ${i + 1}',
      ));
    }
    return out;
  }

  /// The name a multi-page scan goes by in the scope menu — the scan has no file
  /// name, so it is named by when it was taken ("Scan 2 Oct, 09:05").
  static String scanSourceName(DateTime when) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Scan ${when.day} ${months[when.month - 1]}, '
        '${two(when.hour)}:${two(when.minute)}';
  }

  /// Reads a cached page's dimensions from its PNG header. [Size.zero] when the
  /// file is unreadable or isn't a PNG the header reader understands — the
  /// import still proceeds, the caller just fills the target instead of
  /// preserving an aspect ratio it couldn't measure.
  Future<Size> _pngSizeOf(String absolutePath) async {
    try {
      final file = File(absolutePath);
      if (!await file.exists()) return Size.zero;
      // Only the first 24 bytes matter; no need to pull a whole page bitmap in.
      final head = await file.openRead(0, 24).expand((c) => c).toList();
      return pngPixelSize(Uint8List.fromList(head)) ?? Size.zero;
    } catch (_) {
      return Size.zero;
    }
  }
}

/// Runs on a background isolate: decode, downscale to [kMaxImportedImageEdge],
/// re-encode as JPEG and write. Returns the saved image's size, or null if the
/// source could not be decoded.
Size? _compressAndSave(({String source, String destination}) job) {
  try {
    final decoded = img.decodeImage(File(job.source).readAsBytesSync());
    if (decoded == null) return null;

    var out = decoded;
    if (out.width > kMaxImportedImageEdge || out.height > kMaxImportedImageEdge) {
      out = img.copyResize(
        out,
        width: out.width >= out.height ? kMaxImportedImageEdge : null,
        height: out.height > out.width ? kMaxImportedImageEdge : null,
      );
    }

    final file = File(job.destination);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodeJpg(out, quality: 85));

    return Size(out.width.toDouble(), out.height.toDouble());
  } catch (_) {
    return null;
  }
}
