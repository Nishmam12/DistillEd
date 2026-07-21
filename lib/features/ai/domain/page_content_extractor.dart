// The single entry point through which AI features read a page.
//
// Master-plan principle: the AI observes the editor, it never owns it. Every
// feature (Summarize today; the Context Engine, Explain, quizzes, RAG
// chunking later) gets its page understanding from here, so "what the AI can
// see" has exactly one definition:
//   * handwritten ink   → on-device recognition ([recognizedInkText])
//   * typed text        → concatenated in reading order ([typedText])
//   * images (incl. rasterized PDF pages) → on-device OCR
//     ([recognizedImageText]) when an [ImageTextReader] is wired in; still
//     flagged needsOcr when it isn't, or when the image holds no text
//   * shapes/frames     → carry no standalone text (labels are bound
//     TextElements, covered above); ignored
//
// Elements are loaded through an injected loader (wired to
// SceneElementStore.loadForPage in production) so the extractor stays free of
// persistence details and trivially testable.

import '../../../domain/model/scene_element.dart';
import '../data/handwriting/handwriting_recognition_service.dart';
import 'page_content.dart';

import 'dart:ui';

/// Reads the text out of the image at [relativeImagePath] (relative to the app
/// documents dir), or '' when there is none. Must not throw: an unreadable
/// picture should cost its own text, not the whole page's.
typedef ImageTextReader = Future<String> Function(String relativeImagePath);

class PageContentExtractor {
  final Future<List<SceneElement>> Function(int pageId) _loadElements;
  final HandwritingRecognitionService _recognition;

  /// Optional, so tests and any caller that doesn't want OCR get the previous
  /// behaviour — images flagged, not read.
  final ImageTextReader? _readImageText;

  PageContentExtractor({
    required Future<List<SceneElement>> Function(int pageId) loadElements,
    required HandwritingRecognitionService recognition,
    ImageTextReader? readImageText,
  })  : _loadElements = loadElements,
        _recognition = recognition,
        _readImageText = readImageText;

  /// Extracts everything AI-readable from the page. The recognition language
  /// model for [languageCode] must be present (see
  /// [HandwritingRecognitionService.ensureModelDownloaded]); recognition
  /// failures surface as [RecognitionException].
  Future<PageContent> extractPage(
    int pageId, {
    required String languageCode,
  }) async {
    return _extractFrom(await _loadElements(pageId), languageCode);
  }

  /// Extracts AI-readable content from just the selected [elementIds] on
  /// [pageId] — the read-only path for "summarize/explain this selection". The
  /// same ink recognition and reading-order rules as [extractPage] apply to the
  /// subset (ids not on the page are simply absent).
  Future<PageContent> extractSelection(
    int pageId,
    Set<String> elementIds, {
    required String languageCode,
  }) async {
    if (elementIds.isEmpty) return PageContent.empty;
    final selected = [
      for (final e in await _loadElements(pageId))
        if (elementIds.contains(e.id)) e,
    ];
    return _extractFrom(selected, languageCode);
  }

  /// Shared extraction over an already-loaded element list, so page-scope and
  /// selection-scope reads produce identical [PageContent] for the same ink and
  /// text.
  Future<PageContent> _extractFrom(
    List<SceneElement> elements,
    String languageCode,
  ) async {
    if (elements.isEmpty) return PageContent.empty;

    final sources = <PageContentSource>[];

    // Ink → recognized text (one grouped call; stroke order is drawing order).
    final ink = await _recognition.recognizeElements(elements, languageCode);
    final inkBounds = _inkBounds(elements);
    if (inkBounds != null) {
      sources.add(PageContentSource(kind: PageSourceKind.ink, bounds: inkBounds));
    }

    // Typed text in reading order: top-to-bottom, then left-to-right.
    final textElements = [
      for (final e in elements)
        if (e is TextElement && e.text.trim().isNotEmpty) e,
    ]..sort((a, b) {
        final dy = a.geometryData[1].compareTo(b.geometryData[1]);
        return dy != 0 ? dy : a.geometryData[0].compareTo(b.geometryData[0]);
      });
    for (final e in textElements) {
      sources.add(PageContentSource(
        kind: PageSourceKind.typedText,
        bounds: _rectOf(e.geometryData),
      ));
    }

    // Images (including imported PDF pages, which are rasterized on import).
    // Read by OCR when a reader is wired in; still flagged needsOcr when it
    // isn't, or when the image turned out to hold no text — the flag means
    // "there is visible content here the pipeline did not read", which is
    // exactly as true of an unreadable image as of an unwired one.
    final imageTexts = <String>[];
    for (final e in elements) {
      if (e is! ImageElement) continue;

      final reader = _readImageText;
      var text = '';
      if (reader != null && e.relativeImagePath.isNotEmpty) {
        text = (await reader(e.relativeImagePath)).trim();
      }
      if (text.isNotEmpty) imageTexts.add(text);

      sources.add(PageContentSource(
        kind: PageSourceKind.image,
        bounds: _rectOf(e.geometryData),
        needsOcr: text.isEmpty,
      ));
    }

    return PageContent(
      recognizedInkText: ink.text,
      inkTopScore: ink.topScore,
      typedText: textElements.map((e) => e.text.trim()).join('\n'),
      recognizedImageText: imageTexts.join('\n\n'),
      sources: sources,
    );
  }

  /// Union of all non-eraser freehand bounds, or null when the page has none.
  static Rect? _inkBounds(List<SceneElement> elements) {
    Rect? union;
    for (final e in elements) {
      if (e is! FreehandElement || e.isEraser || e.points.isEmpty) continue;
      var minX = e.points.first.x, maxX = minX;
      var minY = e.points.first.y, maxY = minY;
      for (final p in e.points) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
      final r = Rect.fromLTRB(minX, minY, maxX, maxY);
      union = union == null ? r : union.expandToInclude(r);
    }
    return union;
  }

  static Rect _rectOf(List<double> geometryData) => Rect.fromLTRB(
      geometryData[0], geometryData[1], geometryData[2], geometryData[3]);
}
