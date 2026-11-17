import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/constants/storage_paths.dart';
import '../../data/migration/legacy_models/imported_content.dart';
import 'pdf_text_layer.dart';

class ImportException implements Exception {
  final String message;
  const ImportException(this.message);
  @override
  String toString() => 'ImportException: $message';
}

/// Thrown by [PdfService.pageCount] when the PDF opens only with a password;
/// [PdfService.unlock] makes a copy that opens without one.
class PdfLockedException extends ImportException {
  const PdfLockedException() : super('That PDF is protected with a password.');
}

/// Thrown by [PdfService.renderAll] when the caller cancelled the import.
/// Pages already rendered stay in the cache, so importing again is quicker.
class ImportCancelledException implements Exception {
  const ImportCancelledException();
}

class _PdfRenderPayload {
  final RootIsolateToken token;
  final String filePath;
  final String notebookId;
  final String docsDir;

  /// 1-based, inclusive.
  final int firstPage;
  final int lastPage;

  /// The PDF's content hash when an earlier chunk already worked it out.
  final String? pdfHash;

  _PdfRenderPayload(
    this.token,
    this.filePath,
    this.notebookId,
    this.docsDir, {
    required this.firstPage,
    required this.lastPage,
    this.pdfHash,
  });
}

class PdfService {
  /// [textLayers] keeps each page's own text beside its image so reading the page
  /// later needs no OCR (see `pdf_text_layer.dart`); tests pass a fake.
  /// [pdfium] also unlocks password-protected PDFs.
  PdfService({PdfTextLayerWriter? textLayers, PdfiumTextSource? pdfium})
    : this._(pdfium ?? PdfiumTextSource(), textLayers);

  PdfService._(this._pdfium, PdfTextLayerWriter? textLayers)
    : _textLayers = textLayers ?? PdfTextLayerWriter(_pdfium);

  final PdfiumTextSource _pdfium;
  final PdfTextLayerWriter _textLayers;

  /// How many pages are rendered per background job. Small enough that
  /// progress moves and Cancel answers within a few pages; large enough that
  /// reopening the document per job costs little.
  static const int pagesPerChunk = 4;

  /// How many pages the PDF at [filePath] has.
  ///
  /// Throws [ImportException] when the file is missing or not a PDF.
  Future<int> pageCount(String filePath) async {
    if (!await File(filePath).exists()) {
      throw ImportException('PDF not found at path: $filePath');
    }
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(filePath);
      return document.pagesCount;
    } catch (_) {
      if (await _isLocked(filePath)) throw const PdfLockedException();
      throw const ImportException('File is not a valid PDF');
    } finally {
      await document?.close();
    }
  }

  Future<bool> _isLocked(String filePath) async {
    try {
      return await _pdfium.isLocked(filePath);
    } catch (_) {
      return false; // PDFium can't read it either: simply not a PDF
    }
  }

  /// Unlocks the protected PDF at [filePath] with [password] into a copy with
  /// the same file name (the name an import shows) under the temp directory.
  /// Returns the copy's path, or null when the password is wrong.
  Future<String?> unlock(String filePath, String password) async {
    final name = filePath.split(RegExp(r'[/\\]')).last;
    final out = '${(await getTemporaryDirectory()).path}/unlocked/'
        '${DateTime.now().microsecondsSinceEpoch}/$name';
    return await _pdfium.unlock(filePath, password, out) ? out : null;
  }

  /// Renders pages [firstPage]..[lastPage] (1-based, inclusive; null = to the
  /// end) of a PDF and creates an ImportedContent for each. Runs in background
  /// isolates, [pagesPerChunk] pages at a time, reporting [onProgress] (pages
  /// done, pages asked for) between chunks and stopping with
  /// [ImportCancelledException] once [isCancelled] says so.
  Future<List<ImportedContent>> renderAll(
    String filePath,
    String notebookId, {
    int firstPage = 1,
    int? lastPage,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final count = await pageCount(filePath);
    final first = firstPage.clamp(1, count);
    final last = (lastPage ?? count).clamp(first, count);
    final total = last - first + 1;

    final docsDir = (await getApplicationDocumentsDirectory()).path;
    final token = RootIsolateToken.instance!;

    final pages = <ImportedContent>[];
    String? hash;
    onProgress?.call(0, total);
    for (var from = first; from <= last; from += pagesPerChunk) {
      if (isCancelled?.call() ?? false) throw const ImportCancelledException();
      final to = (from + pagesPerChunk - 1).clamp(from, last);
      final chunk = await compute(
        _renderPdfIsolate,
        _PdfRenderPayload(token, filePath, notebookId, docsDir,
            firstPage: from, lastPage: to, pdfHash: hash),
      );
      hash = chunk.hash;
      pages.addAll(chunk.pages);
      onProgress?.call(to - first + 1, total);
    }
    if (isCancelled?.call() ?? false) throw const ImportCancelledException();

    // The text PDFium can read off each page, kept beside its image. It never
    // fails the import: a PDF it cannot read is simply read as pictures.
    await _textLayers.write(
      pdfPath: filePath,
      pageImagePaths: [
        for (final p in pages) '$docsDir/${p.relativeImagePath}',
      ],
      firstPage: first,
    );
    return pages;
  }
}

/// Deterministic 60-bit FNV-1a hash of a byte sequence, rendered as zero-padded
/// hex. Unlike `String.hashCode`, this is stable across runs/platforms and is
/// content-based, so the on-disk page cache is reused correctly across launches
/// and two different PDFs cannot collide onto the same cache directory.
String _fnv1aHashHex(List<int> bytes) => _fnvHex(_fnvUpdate(_fnvSeed, bytes));

const int _fnvSeed = 0xcbf29ce484222325;

int _fnvUpdate(int hash, List<int> bytes) {
  const int prime = 0x100000001b3;
  for (final b in bytes) {
    hash = (hash ^ b) * prime;
  }
  return hash;
}

// Mask to 60 bits to guarantee a positive value and a clean hex string.
String _fnvHex(int hash) =>
    (hash & 0x0FFFFFFFFFFFFFFF).toRadixString(16).padLeft(15, '0');

/// Longest side, in pixels, a page is rendered at. 2x the page's size is crisp
/// for a slide (~1,500 px) but a poster-sized page would need ~100 MB for one
/// bitmap.
const double kPdfMaxRenderSide = 4096;

/// The pixel size to render a [width] x [height] pt page at: 2x, capped.
@visibleForTesting
(double, double) pdfRenderSize(double width, double height) {
  final scale = (kPdfMaxRenderSide / (2 * (width > height ? width : height)))
      .clamp(0.0, 1.0);
  final factor = 2.0 * scale;
  return (width * factor, height * factor);
}

/// Test-only accessor for the deterministic content hash used as the PDF cache key.
@visibleForTesting
String pdfContentHashHex(List<int> bytes) => _fnv1aHashHex(bytes);

Future<({String hash, List<ImportedContent> pages})> _renderPdfIsolate(
  _PdfRenderPayload payload,
) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(payload.token);

  // Hash the PDF *contents* (off the main thread) for a stable, collision-safe
  // cache key, once per import: later chunks are handed it. Falls back to the
  // path hash if the file can't be read for hashing.
  String pdfHash;
  final known = payload.pdfHash;
  if (known != null) {
    pdfHash = known;
  } else {
    try {
      // Streamed: a 200 MB PDF is not held in memory just to be hashed.
      var hash = _fnvSeed;
      await for (final chunk in File(payload.filePath).openRead()) {
        hash = _fnvUpdate(hash, chunk);
      }
      pdfHash = _fnvHex(hash);
    } catch (_) {
      pdfHash = _fnv1aHashHex(payload.filePath.codeUnits);
    }
  }

  PdfDocument? document;
  try {
    document = await PdfDocument.openFile(payload.filePath);
  } catch (e) {
    throw const ImportException('File is not a valid PDF');
  }

  final List<ImportedContent> importedPages = [];
  final failedPages = <int>[];

  try {
    final last = payload.lastPage.clamp(1, document.pagesCount);

    for (int i = payload.firstPage; i <= last; i++) {
      final relativeCachePath = StoragePaths.getPdfPageCacheRelativePath(
        payload.notebookId,
        pdfHash,
        i,
      );
      final absoluteCachePath = '${payload.docsDir}/$relativeCachePath';

      final diskFile = File(absoluteCachePath);
      // A zero-length file is a write that died early, not a cached page.
      if (!await diskFile.exists() || await diskFile.length() == 0) {
        try {
          final page = await document.getPage(i);
          // 2x for clarity, capped so a huge page cannot exhaust memory.
          final (renderWidth, renderHeight) = pdfRenderSize(
            page.width,
            page.height,
          );
          final PdfPageImage? pageImage;
          try {
            pageImage = await page.render(
              width: renderWidth,
              height: renderHeight,
              format: PdfPageImageFormat.png,
            );
          } finally {
            await page.close();
          }

          if (pageImage != null) {
            final bytes = pageImage.bytes;
            await diskFile.parent.create(recursive: true);
            // tmp + rename: a kill mid-write must not leave a truncated page
            // that the exists() check above would then trust forever.
            final tmp = File('${diskFile.path}.tmp');
            await tmp.writeAsBytes(bytes, flush: true);
            await tmp.rename(diskFile.path);
          }
        } catch (e) {
          debugPrint('Rendering failed for page $i: $e');
        }
        // No file means a page that would open blank: fail the import (pages
        // already drawn stay cached, so trying again is quick).
        if (!await diskFile.exists()) {
          failedPages.add(i);
          continue;
        }
      }

      final content = ImportedContent.pdfBackground(
        id: '${DateTime.now().microsecondsSinceEpoch}_$i',
        relativeImagePath: relativeCachePath,
        sourceDescription: '${payload.filePath.split('/').last} — Page $i',
      );
      importedPages.add(content);
    }
  } finally {
    await document.close();
  }

  if (failedPages.isNotEmpty) {
    throw ImportException(
      'Could not render page ${failedPages.first} of the PDF'
      '${failedPages.length > 1 ? ' and ${failedPages.length - 1} more' : ''}.',
    );
  }
  return (hash: pdfHash, pages: importedPages);
}
