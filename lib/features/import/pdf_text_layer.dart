// Reading a PDF's own text at import and keeping it beside the page images
// (docs/AI_PIPELINE_PLAN.md, item 8).
//
// pdfx renders the pages and has no text API, so PDFium is reached a second way,
// through `pdfrx_engine`, for text only. Nothing here touches the page images.
// The text goes into a `.txt` file next to each page's PNG
// (`StoragePaths.pdfTextSidecar`): no schema, keyed by the same content hash as
// the image, and reading the page later is one file read.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';

import '../../core/constants/storage_paths.dart';

/// Reads the text of every page of a PDF.
abstract class PdfTextSource {
  /// The raw text of each page, in page order; '' for a page with none.
  /// Throws when the file cannot be read as a PDF.
  Future<List<String>> pagesText(String pdfPath);
}

/// [PdfTextSource] over PDFium (`pdfrx_engine`). PDFium runs on its own worker
/// isolate, so reading a long PDF does not block the UI.
class PdfiumTextSource implements PdfTextSource {
  /// [cacheDir] is where PDFium may keep scratch files; the app's temp directory
  /// by default. Injectable so tests need no platform channel.
  PdfiumTextSource({Future<String> Function()? cacheDir})
      : _cacheDir = cacheDir ?? (() async => (await getTemporaryDirectory()).path);

  final Future<String> Function() _cacheDir;

  /// Shared by every source: PDFium is loaded once per process. A failed start
  /// is forgotten, so the next import tries again.
  static Future<void>? _initializing;

  Future<void> _initialize() async {
    final pending = _initializing ??= _startPdfium();
    try {
      await pending;
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _startPdfium() async =>
      pdfrxInitialize(tmpPath: await _cacheDir());

  @override
  Future<List<String>> pagesText(String pdfPath) async {
    await _initialize();
    final document = await PdfDocument.openFile(pdfPath);
    try {
      return [
        for (final page in document.pages)
          _visibleText(page, await page.loadText()),
      ];
    } finally {
      await document.dispose();
    }
  }
}

/// The page's text minus what a reader cannot see. A PDF can carry text sized to
/// nothing or placed off the page; it never shows, but it would reach the model
/// as if the student had read it, so it is a way to plant instructions.
/// (White-on-white text is not caught: that needs the glyph colour.)
String _visibleText(PdfPage page, PdfPageRawText? text) {
  if (text == null) return '';
  final rects = text.charRects;
  if (rects.length != text.fullText.length) return text.fullText;
  final out = StringBuffer();
  for (var i = 0; i < rects.length; i++) {
    final char = text.fullText[i];
    final r = rects[i];
    if (char.trim().isEmpty ||
        isVisibleTextBounds(
          left: r.left,
          bottom: r.bottom,
          right: r.right,
          top: r.top,
          pageWidth: page.width,
          pageHeight: page.height,
        )) {
      out.write(char);
    }
  }
  return out.toString();
}

/// Whether a character with these bounds (PDF points, origin bottom-left) can be
/// seen: at least 2 pt tall (a zero-size font is 0), and overlapping the page.
/// Width is not checked: a combining mark, as in Bangla, can have none.
bool isVisibleTextBounds({
  required double left,
  required double bottom,
  required double right,
  required double top,
  required double pageWidth,
  required double pageHeight,
}) =>
    top - bottom >= 2 &&
    right > 0 &&
    left < pageWidth &&
    top > 0 &&
    bottom < pageHeight;

/// Writes each page's text beside its image.
class PdfTextLayerWriter {
  PdfTextLayerWriter(this._source);

  final PdfTextSource _source;

  /// Keeps the text of the PDF at [pdfPath] beside each of [pageImagePaths]
  /// (absolute, in page order).
  ///
  /// A page with no text still gets an EMPTY file — "looked, found nothing" — so
  /// re-importing a PDF whose pages all have a file never opens it again, like
  /// its page images. A page the reader returned nothing for is left unwritten:
  /// an empty file would claim it had been read.
  ///
  /// Never throws. The text is a shortcut; a PDF that cannot be read for it is
  /// still imported, and its pages are simply read as pictures.
  Future<void> write({
    required String pdfPath,
    required List<String> pageImagePaths,
  }) async {
    if (pageImagePaths.isEmpty) return;
    final targets = [
      for (final image in pageImagePaths) File(StoragePaths.pdfTextSidecar(image)),
    ];
    if (await _allExist(targets)) return;

    final List<String> texts;
    try {
      texts = await _source.pagesText(pdfPath);
    } catch (e) {
      debugPrint('[PdfText] could not read the text of $pdfPath: $e');
      return;
    }

    for (var i = 0; i < targets.length && i < texts.length; i++) {
      final file = targets[i];
      try {
        if (await file.exists()) continue;
        await file.parent.create(recursive: true);
        await file.writeAsString(texts[i].trim().isEmpty ? '' : texts[i]);
      } catch (e) {
        debugPrint('[PdfText] could not keep the text of page ${i + 1}: $e');
      }
    }
  }

  static Future<bool> _allExist(List<File> files) async {
    for (final file in files) {
      if (!await file.exists()) return false;
    }
    return true;
  }
}
