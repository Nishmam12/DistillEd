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

import 'dart:typed_data';
import 'dart:ui';

import '../../../domain/model/scene_element.dart';
import '../data/handwriting/handwriting_recognition_service.dart';
import '../data/ocr/gemma_vision_ocr_service.dart';
import 'page_content.dart';

/// Reads the text out of the image at [relativeImagePath] (relative to the app
/// documents dir), or '' when there is none. Must not throw: an unreadable
/// picture should cost its own text, not the whole page's.
typedef ImageTextReader = Future<String> Function(String relativeImagePath);

/// Rasterises the handwritten ink among a page's elements to a PNG for Gemma
/// vision, or null when there is nothing to draw. Must not throw.
typedef InkImageRenderer = Future<Uint8List?> Function(
    List<SceneElement> inkElements);

/// Loads the raw bytes of the image at [relativeImagePath] for Gemma vision, or
/// null when it can't be read. Must not throw.
typedef ImageBytesLoader = Future<Uint8List?> Function(String relativeImagePath);

class PageContentExtractor {
  final Future<List<SceneElement>> Function(int pageId) _loadElements;
  final HandwritingRecognitionService _recognition;

  /// Optional, so tests and any caller that doesn't want OCR get the previous
  /// behaviour — images flagged, not read.
  final ImageTextReader? _readImageText;

  /// Gemma-vision OCR — the PRIMARY recogniser when a caller asks for a deep
  /// read (`useVision: true`). Null (or the render/loader seams below unset)
  /// falls the whole path back to ML Kit, exactly as before.
  final GemmaVisionOcrService? _visionOcr;
  final InkImageRenderer? _renderInk;
  final ImageBytesLoader? _loadImageBytes;

  PageContentExtractor({
    required Future<List<SceneElement>> Function(int pageId) loadElements,
    required HandwritingRecognitionService recognition,
    ImageTextReader? readImageText,
    GemmaVisionOcrService? visionOcr,
    InkImageRenderer? renderInk,
    ImageBytesLoader? loadImageBytes,
  })  : _loadElements = loadElements,
        _recognition = recognition,
        _readImageText = readImageText,
        _visionOcr = visionOcr,
        _renderInk = renderInk,
        _loadImageBytes = loadImageBytes;

  /// Extracts everything AI-readable from the page. The recognition language
  /// model for [languageCode] must be present (see
  /// [HandwritingRecognitionService.ensureModelDownloaded]); recognition
  /// failures surface as [RecognitionException].
  ///
  /// [useVision] selects the PRIMARY recogniser: Gemma vision when true (with
  /// ML Kit as a last-resort fallback for anything Gemma reads poorly), ML Kit
  /// alone when false. The heavy Gemma pass is opt-in per read so the passive
  /// live loop can stay light — see [ContextEngineNotifier].
  ///
  /// [varyVision] asks Gemma for a fresh, differently-sampled reading (the
  /// "Re-read" path) instead of the deterministic first pass — so re-reading a
  /// page that already read cleanly can still change and correct a misread.
  Future<PageContent> extractPage(
    int pageId, {
    required String languageCode,
    bool useVision = false,
    bool varyVision = false,
  }) async {
    return _extractFrom(await _loadElements(pageId), languageCode,
        useVision: useVision, varyVision: varyVision);
  }

  /// Extracts AI-readable content from just the selected [elementIds] on
  /// [pageId] — the read-only path for "summarize/explain this selection". The
  /// same ink recognition and reading-order rules as [extractPage] apply to the
  /// subset (ids not on the page are simply absent).
  Future<PageContent> extractSelection(
    int pageId,
    Set<String> elementIds, {
    required String languageCode,
    bool useVision = false,
    bool varyVision = false,
  }) async {
    if (elementIds.isEmpty) return PageContent.empty;
    final selected = [
      for (final e in await _loadElements(pageId))
        if (elementIds.contains(e.id)) e,
    ];
    return _extractFrom(selected, languageCode,
        useVision: useVision, varyVision: varyVision);
  }

  /// Shared extraction over an already-loaded element list, so page-scope and
  /// selection-scope reads produce identical [PageContent] for the same ink and
  /// text.
  ///
  /// When [useVision] is set and the Gemma seams are wired, Gemma vision is the
  /// primary recogniser for both ink and images; ML Kit only backstops what
  /// Gemma reads poorly. A missing Gemma model surfaces as
  /// [AiModelNotReadyException] (so the caller can offer the download) rather
  /// than being silently swallowed by the ML Kit fallback.
  Future<PageContent> _extractFrom(
    List<SceneElement> elements,
    String languageCode, {
    required bool useVision,
    bool varyVision = false,
  }) async {
    if (elements.isEmpty) return PageContent.empty;

    final vision = useVision ? _visionOcr : null;
    final sources = <PageContentSource>[];

    // Ink → recognized text. Gemma vision reads the rendered strokes when asked;
    // otherwise ML Kit's grouped digital-ink call (stroke order is drawing order).
    final inkElements = [
      for (final e in elements)
        if (e is FreehandElement && !e.isEraser && e.points.isNotEmpty) e,
    ];
    final inkBounds = _inkBounds(elements);
    if (inkBounds != null) {
      sources.add(PageContentSource(kind: PageSourceKind.ink, bounds: inkBounds));
    }
    var inkText = '';
    double? inkScore;
    if (inkElements.isNotEmpty) {
      final read = await _readInk(
          inkElements, elements, languageCode, vision, varyVision);
      inkText = read.text;
      inkScore = read.score;
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
    // Gemma vision reads them when asked, ML Kit OCR otherwise. Still flagged
    // needsOcr when nothing could be read — the flag means "there is visible
    // content here the pipeline did not read".
    final imageTexts = <String>[];
    for (final e in elements) {
      if (e is! ImageElement) continue;

      final text = await _readImageElement(e, vision, varyVision);
      if (text.isNotEmpty) imageTexts.add(text);

      sources.add(PageContentSource(
        kind: PageSourceKind.image,
        bounds: _rectOf(e.geometryData),
        needsOcr: text.isEmpty,
      ));
    }

    return PageContent(
      recognizedInkText: inkText,
      inkTopScore: inkScore,
      typedText: textElements.map((e) => e.text.trim()).join('\n'),
      recognizedImageText: imageTexts.join('\n\n'),
      sources: sources,
    );
  }

  /// Reads a page's handwriting. Gemma vision (rendered ink → transcription) is
  /// primary when [vision] is wired; ML Kit digital-ink is the fallback, used
  /// when Gemma isn't available for this read or read the page poorly. Gemma's
  /// best-effort text is kept only when ML Kit turns up nothing.
  Future<({String text, double? score})> _readInk(
    List<SceneElement> inkElements,
    List<SceneElement> allElements,
    String languageCode,
    GemmaVisionOcrService? vision,
    bool vary,
  ) async {
    final render = _renderInk;
    if (vision != null && render != null) {
      final png = await render(inkElements);
      if (png != null) {
        final result = await vision.read(png, vary: vary);
        if (result.passed) return (text: result.text, score: null);
        final ml = await _recognition.recognizeElements(allElements, languageCode);
        final mlText = ml.text.trim();
        return mlText.isNotEmpty
            ? (text: mlText, score: ml.topScore)
            : (text: result.text, score: null);
      }
    }
    final ml = await _recognition.recognizeElements(allElements, languageCode);
    return (text: ml.text, score: ml.topScore);
  }

  /// Reads one image element. Gemma vision is primary when wired; ML Kit OCR
  /// backstops a poor Gemma read, and Gemma's best-effort text is kept only when
  /// ML Kit finds nothing.
  Future<String> _readImageElement(
      ImageElement e, GemmaVisionOcrService? vision, bool vary) async {
    if (e.relativeImagePath.isEmpty) return '';

    final loadBytes = _loadImageBytes;
    if (vision != null && loadBytes != null) {
      final bytes = await loadBytes(e.relativeImagePath);
      if (bytes != null) {
        final result = await vision.read(bytes, vary: vary);
        if (result.passed) return result.text;
        final ml = await _readImageTextOrEmpty(e.relativeImagePath);
        return ml.isNotEmpty ? ml : result.text;
      }
    }
    return _readImageTextOrEmpty(e.relativeImagePath);
  }

  Future<String> _readImageTextOrEmpty(String relativeImagePath) async {
    final reader = _readImageText;
    if (reader == null) return '';
    return (await reader(relativeImagePath)).trim();
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
