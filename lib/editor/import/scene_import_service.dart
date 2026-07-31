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

  SceneImportService({PDFService? pdf, ImagePicker? picker})
      : _pdf = pdf ?? PDFService(),
        _picker = picker ?? ImagePicker();

  /// Lets the user choose a PDF. Null when they cancel.
  Future<String?> pickPdfPath() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    return result?.files.single.path;
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
    final docsDir = (await getApplicationDocumentsDirectory()).path;

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
    final docsDir = (await getApplicationDocumentsDirectory()).path;

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
