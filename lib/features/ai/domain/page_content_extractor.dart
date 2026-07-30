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
//   * charts/diagrams, drawn OR pasted → structured [PageContent.figures] via
//     the VLM figure pass ([FigureAnalyzer]), when one is wired and the caller
//     asked for a deep read
//   * shapes/frames     → no standalone TEXT of their own, but they are the
//     bones of a hand-drawn flowchart, so they ARE rendered into the image the
//     figure pass reads (see [_drawnLayer])
//
// Elements are loaded through an injected loader (wired to
// SceneElementStore.loadForPage in production) so the extractor stays free of
// persistence details and trivially testable.

import 'dart:typed_data';
import 'dart:ui';

import '../../../domain/model/scene_element.dart';
import '../data/handwriting/handwriting_recognition_service.dart';
import '../data/ocr/gemma_vision_ocr_service.dart';
import 'ai_exception.dart';
import 'figure.dart';
import 'figure_analyzer.dart';
import 'page_content.dart';

/// Reads the text out of the image at [relativeImagePath] (relative to the app
/// documents dir), or '' when there is none. Must not throw: an unreadable
/// picture should cost its own text, not the whole page's.
typedef ImageTextReader = Future<String> Function(String relativeImagePath);

/// Rasterises the given scene elements to a PNG for Gemma vision, or null when
/// there is nothing to draw. Must not throw.
///
/// Called with two different slices: just the handwritten strokes (for the OCR
/// read) and the whole drawn layer including shapes, arrows and their text
/// labels (for the figure read) — see [PageContentExtractor._drawnLayer].
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

  /// Reads charts and diagrams as structured [FigureDescription]s. Null leaves
  /// [PageContent.figures] empty and the pipeline behaves exactly as it did
  /// before figures existed.
  final FigureAnalyzer? _figures;

  PageContentExtractor({
    required Future<List<SceneElement>> Function(int pageId) loadElements,
    required HandwritingRecognitionService recognition,
    ImageTextReader? readImageText,
    GemmaVisionOcrService? visionOcr,
    InkImageRenderer? renderInk,
    ImageBytesLoader? loadImageBytes,
    FigureAnalyzer? figureAnalyzer,
  })  : _loadElements = loadElements,
        _recognition = recognition,
        _readImageText = readImageText,
        _visionOcr = visionOcr,
        _renderInk = renderInk,
        _loadImageBytes = loadImageBytes,
        _figures = figureAnalyzer;

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
    // The figure pass is a second VLM call per visual, so it rides the same
    // opt-in as the deep read — the passive live loop never pays for it.
    final figureAnalyzer = useVision ? _figures : null;
    final sources = <PageContentSource>[];
    final figures = <FigureDescription>[];

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

      final bytes = await _imageBytesOf(e);
      final text = await _readImageElement(e, bytes, vision, varyVision);
      if (text.isNotEmpty) imageTexts.add(text);

      // A pasted graph is the case that motivated this whole pass: it usually
      // OCRs to a handful of axis labels, so text alone never described it.
      final figure = bytes == null
          ? null
          : await _analyzeFigure(figureAnalyzer, bytes);
      if (figure != null) figures.add(figure);

      sources.add(PageContentSource(
        kind: PageSourceKind.image,
        bounds: _rectOf(e.geometryData),
        // A figure we understood is content we DID read, even with no text.
        needsOcr: text.isEmpty && figure == null,
      ));
    }

    // The hand-drawn figure: strokes, shapes, arrows and their labels rendered
    // together, so a flowchart built from the shape tools is finally visible.
    // Rendered separately from the OCR ink image because that one deliberately
    // excludes shapes and typed labels.
    final drawn = _drawnLayer(elements);
    if (figureAnalyzer != null && drawn.isNotEmpty) {
      final render = _renderInk;
      final png = render == null ? null : await render(drawn);
      if (png != null) {
        final figure = await _analyzeFigure(figureAnalyzer, png);
        if (figure != null) figures.add(figure);
      }
    }

    return PageContent(
      recognizedInkText: inkText,
      inkTopScore: inkScore,
      typedText: textElements.map((e) => e.text.trim()).join('\n'),
      recognizedImageText: imageTexts.join('\n\n'),
      figures: figures,
      sources: sources,
    );
  }

  /// Everything the student DREW, in z-order: strokes, shapes and frames, plus
  /// the text labels bound to them. Images are excluded — each is analysed on
  /// its own bytes above, at full resolution rather than as a scaled-down
  /// rectangle inside a page render.
  ///
  /// Returns empty when the page has no shape and no ink, so a page of pure
  /// typed text never triggers a figure call.
  static List<SceneElement> _drawnLayer(List<SceneElement> elements) {
    final hasVisual = elements.any((e) =>
        (e is FreehandElement && !e.isEraser && e.points.isNotEmpty) ||
        e is SceneShapeElement);
    if (!hasVisual) return const [];
    return [
      for (final e in elements)
        if (e is! ImageElement && !(e is FreehandElement && e.isEraser)) e,
    ];
  }

  /// Runs the figure pass, swallowing everything except a missing local model —
  /// a figure is an enhancement, and a page must still summarize without one.
  Future<FigureDescription?> _analyzeFigure(
      FigureAnalyzer? analyzer, Uint8List bytes) async {
    if (analyzer == null) return null;
    try {
      return await analyzer.analyze(bytes);
    } on AiModelNotReadyException {
      // Same contract as the OCR path: the caller offers the download rather
      // than silently producing a figure-less read.
      rethrow;
    } on AiException {
      return null;
    }
  }

  Future<Uint8List?> _imageBytesOf(ImageElement e) async {
    final loadBytes = _loadImageBytes;
    if (loadBytes == null || e.relativeImagePath.isEmpty) return null;
    return loadBytes(e.relativeImagePath);
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
  ///
  /// [bytes] is the already-loaded image (null when it couldn't be read or no
  /// loader is wired), passed in so the OCR and figure passes decode the file
  /// once between them rather than once each.
  Future<String> _readImageElement(ImageElement e, Uint8List? bytes,
      GemmaVisionOcrService? vision, bool vary) async {
    if (e.relativeImagePath.isEmpty) return '';

    if (vision != null && bytes != null) {
      final result = await vision.read(bytes, vary: vary);
      if (result.passed) return result.text;
      final ml = await _readImageTextOrEmpty(e.relativeImagePath);
      return ml.isNotEmpty ? ml : result.text;
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
