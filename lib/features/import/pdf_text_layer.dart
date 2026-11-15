// Reading a PDF's own text at import and keeping it beside the page images
// (docs/AI_PIPELINE_PLAN.md, item 8).
//
// pdfx renders the pages and has no text API, so PDFium is reached a second way,
// through `pdfrx_engine`, for text only. Nothing here touches the page images.
// The text goes into a `.txt` file next to each page's PNG
// (`StoragePaths.pdfTextSidecar`): no schema, keyed by the same content hash as
// the image, and reading the page later is one file read.

import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';

import '../../core/constants/storage_paths.dart';
import '../../domain/model/page_words.dart';

/// Reads the text of every page of a PDF.
abstract class PdfTextSource {
  /// The raw text of each page, in page order; '' for a page with none.
  /// Throws when the file cannot be read as a PDF.
  Future<List<String>> pagesText(String pdfPath);

  /// The visible words of each page and where they sit, in page order.
  /// Throws when the file cannot be read as a PDF.
  Future<List<PageWords>> pagesWords(String pdfPath);
}

/// [PdfTextSource] over PDFium (`pdfrx_engine`). PDFium runs on its own worker
/// isolate, so reading a long PDF does not block the UI.
class PdfiumTextSource implements PdfTextSource {
  /// [cacheDir] is where PDFium may keep scratch files; the app's temp directory
  /// by default. Injectable so tests need no platform channel.
  PdfiumTextSource({Future<String> Function()? cacheDir})
    : _cacheDir =
          cacheDir ?? (() async => (await getTemporaryDirectory()).path);

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

  /// The last PDF read, so the writer asking for text and then words opens the
  /// file once.
  String? _lastPath;
  List<({String text, PageWords words})>? _last;

  Future<List<({String text, PageWords words})>> _read(String pdfPath) async {
    if (_lastPath == pdfPath && _last != null) return _last!;
    await _initialize();
    final document = await PdfDocument.openFile(pdfPath);
    try {
      final out = <({String text, PageWords words})>[];
      for (final page in document.pages) {
        final raw = await page.loadText();
        out.add((
          text: _visibleText(page, raw),
          words: raw == null || raw.charRects.length != raw.fullText.length
              ? PageWords.empty
              : wordsFromPdfChars(
                  text: raw.fullText,
                  rects: [
                    for (final r in raw.charRects)
                      (left: r.left, bottom: r.bottom, right: r.right, top: r.top),
                  ],
                  pageWidth: page.width,
                  pageHeight: page.height,
                ),
        ));
      }
      _lastPath = pdfPath;
      _last = out;
      return out;
    } finally {
      await document.dispose();
    }
  }

  @override
  Future<List<String>> pagesText(String pdfPath) async =>
      [for (final p in await _read(pdfPath)) p.text];

  @override
  Future<List<PageWords>> pagesWords(String pdfPath) async =>
      [for (final p in await _read(pdfPath)) p.words];
}

/// A character's bounds in PDF points, origin bottom-left (as PDFium gives
/// them).
typedef PdfCharRect = ({double left, double bottom, double right, double top});

/// The visible words of a PDF page from its characters and their bounds.
///
/// Words are split on whitespace; each box is the union of its characters'
/// boxes, flipped to a top-left origin and normalised to the page. A new line
/// starts at a line break in the text, or when a word sits clearly below the
/// one before (some PDFs place lines without a break). Hidden characters (see
/// [isVisibleTextBounds]) are left out, as they are from the text.
PageWords wordsFromPdfChars({
  required String text,
  required List<PdfCharRect> rects,
  required double pageWidth,
  required double pageHeight,
}) {
  if (pageWidth <= 0 || pageHeight <= 0 || rects.length != text.length) {
    return PageWords.empty;
  }
  final words = <PageWord>[];
  var line = 0;
  var pendingBreak = false;
  final buffer = StringBuffer();
  double? l, t, r, b; // top-left origin, points

  void flush() {
    if (buffer.isEmpty || l == null) {
      buffer.clear();
      return;
    }
    final box = Rect.fromLTRB(l! / pageWidth, t! / pageHeight,
        r! / pageWidth, b! / pageHeight);
    if (words.isNotEmpty) {
      final prev = words.last.box;
      final below = box.top > prev.top + prev.height * 0.6 &&
          box.center.dy > prev.bottom;
      if (pendingBreak || below) line++;
    }
    pendingBreak = false;
    words.add(PageWord(text: buffer.toString(), box: box, line: line));
    buffer.clear();
    l = t = r = b = null;
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char.trim().isEmpty) {
      flush();
      if (char == '\n' || char == '\r') pendingBreak = true;
      continue;
    }
    final c = rects[i];
    if (!isVisibleTextBounds(
      left: c.left,
      bottom: c.bottom,
      right: c.right,
      top: c.top,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
    )) {
      continue;
    }
    final top = pageHeight - c.top;
    final bottom = pageHeight - c.bottom;
    l = l == null ? c.left : (c.left < l! ? c.left : l);
    r = r == null ? c.right : (c.right > r! ? c.right : r);
    t = t == null ? top : (top < t! ? top : t);
    b = b == null ? bottom : (bottom > b! ? bottom : b);
    buffer.write(char);
  }
  flush();
  return PageWords(source: PageWordsSource.pdf, words: words);
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
  /// (absolute, in page order), the first of which is PDF page [firstPage]
  /// (1-based) — not page 1 when only part of the document was imported.
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
    int firstPage = 1,
  }) async {
    if (pageImagePaths.isEmpty) return;
    final offset = firstPage < 1 ? 0 : firstPage - 1;
    final targets = [
      for (final image in pageImagePaths)
        File(StoragePaths.pdfTextSidecar(image)),
    ];
    final wordTargets = [
      for (final image in pageImagePaths)
        File(StoragePaths.pdfWordsSidecar(image)),
    ];
    final needText = !await _allExist(targets);
    final needWords = !await _allExist(wordTargets);
    if (!needText && !needWords) return;

    if (needWords) await _writeWords(pdfPath, wordTargets, offset);
    if (!needText) return;

    final List<String> texts;
    try {
      texts = await _source.pagesText(pdfPath);
    } catch (e) {
      debugPrint('[PdfText] could not read the text of $pdfPath: $e');
      return;
    }

    for (var i = 0; i < targets.length && offset + i < texts.length; i++) {
      final file = targets[i];
      try {
        if (await file.exists()) continue;
        await file.parent.create(recursive: true);
        // tmp + rename, so a kill mid-write cannot leave partial text that the
        // exists() checks would trust.
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(
          texts[offset + i].trim().isEmpty ? '' : texts[offset + i],
          flush: true,
        );
        await tmp.rename(file.path);
      } catch (e) {
        debugPrint('[PdfText] could not keep the text of page ${i + 1}: $e');
      }
    }
  }

  /// Keeps each page's words beside its image. A page with no words still gets
  /// a file, so it is not read again off the picture later.
  Future<void> _writeWords(String pdfPath, List<File> targets, int offset) async {
    final List<PageWords> words;
    try {
      words = await _source.pagesWords(pdfPath);
    } catch (e) {
      debugPrint('[PdfText] could not read the words of $pdfPath: $e');
      return;
    }
    for (var i = 0; i < targets.length && offset + i < words.length; i++) {
      final file = targets[i];
      try {
        if (await file.exists()) continue;
        await file.parent.create(recursive: true);
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(words[offset + i].encode(), flush: true);
        await tmp.rename(file.path);
      } catch (e) {
        debugPrint('[PdfText] could not keep the words of page ${i + 1}: $e');
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
