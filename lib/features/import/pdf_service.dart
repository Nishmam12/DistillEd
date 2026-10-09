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

class _PdfRenderPayload {
  final RootIsolateToken token;
  final String filePath;
  final String notebookId;
  final String docsDir;

  _PdfRenderPayload(this.token, this.filePath, this.notebookId, this.docsDir);
}

class PDFService {
  /// [textLayers] keeps each page's own text beside its image so reading the page
  /// later needs no OCR (see `pdf_text_layer.dart`); tests pass a fake.
  PDFService({PdfTextLayerWriter? textLayers})
      : _textLayers = textLayers ?? PdfTextLayerWriter(PdfiumTextSource());

  final PdfTextLayerWriter _textLayers;

  /// Renders all pages of a PDF and creates an ImportedContent for each page.
  /// Runs inside a background isolate to prevent UI thread blocking.
  Future<List<ImportedContent>> renderAll(String filePath, String notebookId) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ImportException('PDF not found at path: $filePath');
    }

    final docsDir = (await getApplicationDocumentsDirectory()).path;
    final token = RootIsolateToken.instance!;
    
    final payload = _PdfRenderPayload(token, filePath, notebookId, docsDir);
    
    // Spawn background isolate
    final pages = await compute(_renderPdfIsolate, payload);

    // The text PDFium can read off each page, kept beside its image. It never
    // fails the import: a PDF it cannot read is simply read as pictures.
    await _textLayers.write(
      pdfPath: filePath,
      pageImagePaths: [for (final p in pages) '$docsDir/${p.relativeImagePath}'],
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

Future<List<ImportedContent>> _renderPdfIsolate(_PdfRenderPayload payload) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(payload.token);

  // Hash the PDF *contents* (off the main thread) for a stable, collision-safe
  // cache key. Falls back to the path hash if the file can't be read for hashing.
  String pdfHash;
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

  PdfDocument? document;
  try {
    document = await PdfDocument.openFile(payload.filePath);
  } catch (e) {
    throw const ImportException('File is not a valid PDF');
  }

  final List<ImportedContent> importedPages = [];
  final failedPages = <int>[];

  try {
    final pageCount = document.pagesCount;

    for (int i = 1; i <= pageCount; i++) {
      final relativeCachePath = StoragePaths.getPdfPageCacheRelativePath(payload.notebookId, pdfHash, i);
      final absoluteCachePath = '${payload.docsDir}/$relativeCachePath';

      final diskFile = File(absoluteCachePath);
      if (!await diskFile.exists()) {
        try {
          final page = await document.getPage(i);
          // 2x for clarity, capped so a huge page cannot exhaust memory.
          final (renderWidth, renderHeight) =
              pdfRenderSize(page.width, page.height);
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
            await diskFile.writeAsBytes(bytes);
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
        '${failedPages.length > 1 ? ' and ${failedPages.length - 1} more' : ''}.');
  }
  return importedPages;
}
