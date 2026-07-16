// The single entry point through which AI features read a page.
//
// Master-plan principle: the AI observes the editor, it never owns it. Every
// feature (Summarize today; the Context Engine, Explain, quizzes, RAG
// chunking later) gets its page understanding from here, so "what the AI can
// see" has exactly one definition:
//   * handwritten ink   → on-device recognition ([recognizedInkText])
//   * typed text        → concatenated in reading order ([typedText])
//   * images (incl. rasterized PDF pages) → flagged needsOcr, not read (OCR
//     is a later phase)
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

class PageContentExtractor {
  final Future<List<SceneElement>> Function(int pageId) _loadElements;
  final HandwritingRecognitionService _recognition;

  PageContentExtractor({
    required Future<List<SceneElement>> Function(int pageId) loadElements,
    required HandwritingRecognitionService recognition,
  })  : _loadElements = loadElements,
        _recognition = recognition;

  /// Extracts everything AI-readable from the page. The recognition language
  /// model for [languageCode] must be present (see
  /// [HandwritingRecognitionService.ensureModelDownloaded]); recognition
  /// failures surface as [RecognitionException].
  Future<PageContent> extractPage(
    int pageId, {
    required String languageCode,
  }) async {
    final elements = await _loadElements(pageId);
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

    // Images (including imported PDF pages, which are rasterized on import):
    // visible content the pipeline cannot read — flag, don't guess.
    for (final e in elements) {
      if (e is ImageElement) {
        sources.add(PageContentSource(
          kind: PageSourceKind.image,
          bounds: _rectOf(e.geometryData),
          needsOcr: true,
        ));
      }
    }

    return PageContent(
      recognizedInkText: ink.text,
      inkTopScore: ink.topScore,
      typedText: textElements.map((e) => e.text.trim()).join('\n'),
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
