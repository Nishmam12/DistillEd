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
import 'handwriting/ink_trust.dart';
import 'language/language_detector.dart';
import 'page_content.dart';
import 'pdf_text_layer.dart';
import 'pipeline_flags.dart';
import 'read_cache.dart';
import 'recognition_result.dart';

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

/// The transcript of the lectures recorded on page [pageId], rendered as page
/// text, or '' when it has none. Must not throw: a transcript that cannot be
/// read should cost itself, not the page.
typedef LectureTranscriptReader = Future<String> Function(int pageId);

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

  /// True while the work would run on an on-device model that has fallen back
  /// to the CPU, where every vision decode is several times slower. Asked per
  /// read — the backend is only learned when the model first loads. Null means
  /// "never slow", which is the behaviour before this existed.
  final bool Function()? _localIsSlow;

  /// True on a device below the full profile: it drops the optional figure
  /// passes to save RAM, but — unlike a slow one — its output is not cut short,
  /// so what it reads is still worth remembering (as a text-only read).
  final bool Function()? _lite;

  /// Read handwriting with ML Kit first and send Gemma only the lines it cannot
  /// be trusted on — see [kMlKitFirstInk].
  final bool _mlKitFirstInk;

  /// Where finished vision reads are remembered. Null (or [kPersistReads] off)
  /// reads everything afresh each time.
  final ReadCache? _readCache;

  /// The model that answers a read right now, for the cache key — switching
  /// models must read afresh. Asked per read: the mode can change mid-session.
  final String Function()? _readModelId;

  final bool _persistReads;

  /// Tells real text from the noise ML Kit's Latin recogniser makes of a script
  /// it cannot read (Bengali). Null keeps ML Kit's text as it comes.
  final LanguageDetector? _languageDetector;

  /// The text PDFium read off an imported PDF page at import time. A page that
  /// has some needs no OCR and no model — see [_usablePdfText]. Null leaves every
  /// image to be read as a picture, as before.
  final PdfTextLayerReader? _pdfTextLayer;

  /// What was said in the lectures recorded on a page. Null leaves a page's
  /// recordings unread, as before.
  final LectureTranscriptReader? _lectureTranscript;

  PageContentExtractor({
    required Future<List<SceneElement>> Function(int pageId) loadElements,
    required HandwritingRecognitionService recognition,
    ImageTextReader? readImageText,
    GemmaVisionOcrService? visionOcr,
    InkImageRenderer? renderInk,
    ImageBytesLoader? loadImageBytes,
    FigureAnalyzer? figureAnalyzer,
    bool Function()? localIsSlow,
    bool Function()? lite,
    bool mlKitFirstInk = kMlKitFirstInk,
    ReadCache? readCache,
    String Function()? readModelId,
    bool persistReads = kPersistReads,
    LanguageDetector? languageDetector,
    PdfTextLayerReader? pdfTextLayer,
    LectureTranscriptReader? lectureTranscript,
  })  : _loadElements = loadElements,
        _recognition = recognition,
        _readImageText = readImageText,
        _visionOcr = visionOcr,
        _renderInk = renderInk,
        _loadImageBytes = loadImageBytes,
        _figures = figureAnalyzer,
        _localIsSlow = localIsSlow,
        _lite = lite,
        _mlKitFirstInk = mlKitFirstInk,
        _readCache = readCache,
        _readModelId = readModelId,
        _persistReads = persistReads,
        _languageDetector = languageDetector,
        _pdfTextLayer = pdfTextLayer,
        _lectureTranscript = lectureTranscript;

  // ---- The read cache -------------------------------------------------------

  bool get _cacheOn => _persistReads && _readCache != null;

  String _cacheKey(String kind, Uint8List content, String version) =>
      readCacheKey(
        kind: kind,
        content: content,
        version: version,
        modelId: _readModelId?.call() ?? 'local',
      );

  /// The remembered read for [key], or null. A Re-read ([vary]) never looks:
  /// reading it again is the point. Never throws — a cache that fails is a cache
  /// that missed, and must not cost the page its read.
  Future<CachedRead?> _remembered(String key, {required bool vary}) async {
    if (vary) return null;
    try {
      return await _readCache!.find(key);
    } catch (_) {
      return null;
    }
  }

  /// Remembers a finished read. Skipped while the local model is slow: that read
  /// was cut short and had its optional passes dropped, and storing it would pin
  /// the degraded result long after the device is back on the GPU.
  Future<void> _remember(String key, CachedRead read) async {
    if (_localIsSlow?.call() ?? false) return;
    try {
      await _readCache!.save(key, read);
    } catch (_) {
      // See [_remembered].
    }
  }

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
    final content = await _extractFrom(await _loadElements(pageId), languageCode,
        useVision: useVision, varyVision: varyVision);
    // What was SAID on this page, beside what was written. The whole page only —
    // a selection of elements has no recording in it.
    final transcript = await _transcriptOf(pageId);
    return transcript.isEmpty ? content : content.withLectureTranscript(transcript);
  }

  Future<String> _transcriptOf(int pageId) async {
    final reader = _lectureTranscript;
    if (reader == null) return '';
    try {
      return (await reader(pageId)).trim();
    } catch (_) {
      return '';
    }
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
    // opt-in as the deep read — the passive live loop never pays for it. It is
    // also the first thing to go when the local model is running on the CPU:
    // optional, and each one a full vision decode several times slower than on
    // an accelerator. An image's TEXT is not optional, so with this off it is
    // still read, by the plain OCR pass instead of the merged one.
    final figureAnalyzer = useVision &&
            !(_localIsSlow?.call() ?? false) &&
            !(_lite?.call() ?? false)
        ? _figures
        : null;
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
    var inkIsPlainText = false;
    if (inkElements.isNotEmpty) {
      final read = await _readInk(
          inkElements, elements, languageCode, vision, varyVision);
      inkText = read.text;
      inkScore = read.score;
      inkIsPlainText = read.plainText;
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

      // A PDF page that carries its own text is already read: instant, exact, no
      // model. A Re-read skips this on purpose — asking to read it again is
      // asking the model — and so does a page whose text is too short to stand
      // in for it (a scan), or no language (a broken font).
      final layer = varyVision ? null : await _usablePdfText(e.relativeImagePath);
      if (layer != null) {
        imageTexts.add(layer);
        sources.add(PageContentSource(
          kind: PageSourceKind.image,
          bounds: _rectOf(e.geometryData),
          needsOcr: false,
        ));
        continue;
      }

      final bytes = await _imageBytesOf(e);

      // A deep read of this exact picture, with these prompts, by this model, is
      // remembered — an imported page never changes, so it is never read twice.
      // Only the vision path is cached: the ML Kit one is cheap and has its own
      // per-session cache.
      //
      // The full key is for a read that includes the figure pass, or an app that
      // has none. A read that SKIPPED the pass (a slow or lite device) is stored
      // under the text-only key, so it can never pass for "this image has no
      // figure"; and it still finds a full read made earlier, which serves it —
      // the device that skips figures is the one that benefits most from a hit.
      // Slow sessions never write at all (see [_remember]).
      String? imageKey(String version) => _cacheOn && vision != null && bytes != null
          ? _cacheKey('img', bytes, version)
          : null;
      final fullKey = imageKey(_figures == null
          ? GemmaVisionOcrService.cacheVersion
          : '${GemmaVisionOcrService.cacheVersion}'
              '+${FigureAnalyzer.cacheVersion}');
      final textKey = figureAnalyzer == null && _figures != null
          ? imageKey(GemmaVisionOcrService.cacheVersion)
          : null;
      final cacheKey = textKey ?? fullKey; // where THIS read is stored
      var remembered = fullKey == null
          ? null
          : await _remembered(fullKey, vary: varyVision);
      if (remembered == null && textKey != null) {
        remembered = await _remembered(textKey, vary: varyVision);
      }

      String text;
      FigureDescription? figure;
      if (remembered != null) {
        text = remembered.text;
        figure = remembered.figure;
      } else {
        // ONE vision call for both halves when both are wanted. Previously this
        // read the same bytes twice — an OCR pass and a figure pass — and each
        // one prefills the vision encoder at ~2300 patches (a tablet page read
        // measured 19 such passes). Both prompts already ask the model to read
        // every piece of text off the image, so the second call was re-deriving
        // what the first had produced.
        if (bytes != null && figureAnalyzer != null && vision != null) {
          final merged = await _analyzeWithText(figureAnalyzer, bytes);
          figure = merged.figure;
          // `verbatim_text` arrives as a JSON string field, so it is far more
          // exposed to truncation than a raw-text OCR reply. Hold it to the same
          // gate a dedicated read would face, and pay for the second call only
          // when it does not clear it — so a dense page is never transcribed
          // from a clipped field, and the worst case is what this cost before.
          text = vision.accepts(merged.verbatimText)
              ? merged.verbatimText
              : await _readImageElement(e, bytes, vision, varyVision);
        } else {
          text = await _readImageElement(e, bytes, vision, varyVision);
          // A pasted graph is the case that motivated this whole pass: it
          // usually OCRs to a handful of axis labels, so text alone never
          // described it.
          figure = bytes == null
              ? null
              : await _analyzeFigure(figureAnalyzer, bytes);
        }
        // A read that found nothing is as likely a transient failure as a blank
        // picture; remembering it would stop the page ever being read properly.
        if (cacheKey != null && (text.isNotEmpty || figure != null)) {
          await _remember(cacheKey, CachedRead(text: text, figure: figure));
        }
      }
      if (text.isNotEmpty) imageTexts.add(text);
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
    // The drawn layer includes the ink, so without this a deep read of ANY
    // handwriting page ran a full figure pass over it — a vision call whose
    // answer for prose is `{"kind": "none"}`, loading the model just to say so
    // and undoing the point of reading ink with ML Kit first. Ink ML Kit read
    // cleanly line by line is writing, not a drawing; shapes, and ink it could
    // not fully read, still get the pass.
    final hasShapes = elements.any((e) => e is SceneShapeElement);
    if (figureAnalyzer != null &&
        drawn.isNotEmpty &&
        (hasShapes || !inkIsPlainText)) {
      final render = _renderInk;
      final png = render == null ? null : await render(drawn);
      if (png != null) {
        final cacheKey = _cacheOn
            ? _cacheKey('drawn', png, FigureAnalyzer.cacheVersion)
            : null;
        final remembered = cacheKey == null
            ? null
            : await _remembered(cacheKey, vary: varyVision);
        final FigureDescription? figure;
        if (remembered != null) {
          figure = remembered.figure;
        } else {
          figure = await _analyzeFigure(figureAnalyzer, png);
          if (cacheKey != null && figure != null) {
            await _remember(cacheKey, CachedRead(text: '', figure: figure));
          }
        }
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
  /// The merged read, with the same exception contract as [_analyzeFigure]: a
  /// missing model reaches the caller so it can offer the download; any other
  /// failure degrades to "nothing read", which sends the caller to the OCR
  /// fallback rather than losing the page.
  Future<({String verbatimText, FigureDescription? figure})> _analyzeWithText(
      FigureAnalyzer analyzer, Uint8List bytes) async {
    try {
      return await analyzer.analyzeWithText(bytes);
    } on AiModelNotReadyException {
      rethrow;
    } on AiException {
      return (verbatimText: '', figure: null);
    }
  }

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

  /// The page's own PDF text, tidied, when there is enough of it to use — or
  /// null, which sends the image on to OCR / vision exactly as before.
  ///
  /// "Enough" is [hasUsablePdfText], and it must also be a language: a PDF whose
  /// fonts have a broken character map still HAS a text layer, it just is not
  /// text (common with legacy Bangla fonts), and trusting it would index noise.
  Future<String?> _usablePdfText(String relativeImagePath) async {
    final reader = _pdfTextLayer;
    if (reader == null || relativeImagePath.isEmpty) return null;

    final String? raw;
    try {
      raw = await reader(relativeImagePath);
    } catch (_) {
      return null;
    }
    if (raw == null) return null;

    final text = normalizePdfText(raw);
    if (!hasUsablePdfText(text)) return null;
    final detector = _languageDetector;
    if (detector != null && await isUnreadable(text, detector)) return null;
    return text;
  }

  Future<Uint8List?> _imageBytesOf(ImageElement e) async {
    final loadBytes = _loadImageBytes;
    if (loadBytes == null || e.relativeImagePath.isEmpty) return null;
    return loadBytes(e.relativeImagePath);
  }

  /// Reads a page's handwriting.
  ///
  /// On a deep read (vision wired) the default is ML Kit FIRST: it reads the
  /// page line by line in milliseconds with no model load, and Gemma vision is
  /// sent only the lines ML Kit cannot be trusted on, cropped to those lines —
  /// so most handwritten pages never load the 2.6 GB model at all. A Re-read
  /// (vary) skips that and reads the whole page with Gemma, which is what asking
  /// to read it again means.
  ///
  /// Otherwise — flag off, Re-read, or ML Kit cannot carry the page — Gemma
  /// vision (rendered ink → transcription) is primary and ML Kit digital-ink the
  /// fallback, used when Gemma isn't available for this read or read the page
  /// poorly. Gemma's best-effort text is kept only when ML Kit turns up nothing.
  Future<({String text, double? score, bool plainText})> _readInk(
    List<SceneElement> inkElements,
    List<SceneElement> allElements,
    String languageCode,
    GemmaVisionOcrService? vision,
    bool vary,
  ) async {
    final render = _renderInk;
    if (vision != null && render != null) {
      if (_mlKitFirstInk && !vary) {
        final refined = await _readInkMlKitFirst(
            inkElements, languageCode, vision, render);
        if (refined != null) return refined;
        // null: ML Kit cannot carry this page (nothing read, or too much of it
        // is weak), so it goes to Gemma whole, below.
      }
      final png = await render(inkElements);
      if (png != null) {
        final cacheKey = _cacheOn
            ? _cacheKey('ink', png, GemmaVisionOcrService.cacheVersion)
            : null;
        final remembered = cacheKey == null
            ? null
            : await _remembered(cacheKey, vary: vary);
        if (remembered != null) {
          return (text: remembered.text, score: null, plainText: false);
        }

        final result = await vision.read(png, vary: vary);
        if (result.passed) {
          if (cacheKey != null) {
            await _remember(cacheKey, CachedRead(text: result.text));
          }
          return (text: result.text, score: null, plainText: false);
        }
        final ml = await _recognition.recognizeElements(allElements, languageCode);
        final mlText = ml.text.trim();
        return mlText.isNotEmpty
            ? (text: mlText, score: ml.topScore, plainText: false)
            : (text: result.text, score: null, plainText: false);
      }
    }
    final ml = await _recognition.recognizeElements(allElements, languageCode);
    return (text: ml.text, score: ml.topScore, plainText: false);
  }

  /// More separate regions than this and one whole-page read is cheaper than a
  /// model call apiece.
  static const int _maxRefineRegions = 3;

  /// Tokens a region read may use: a little headroom per line over what a line
  /// of handwriting needs, so a two-line crop is not allowed a page's worth.
  static int _regionTokens(int lineCount) =>
      (96 + 48 * lineCount).clamp(128, GemmaVisionOcrService.pageReadTokens);

  /// The ML-Kit-first read: one pass over the page's lines, then Gemma for the
  /// lines that need it. Returns null when ML Kit cannot carry the page, which
  /// sends the caller to the whole-page Gemma read.
  Future<({String text, double? score, bool plainText})?> _readInkMlKitFirst(
    List<SceneElement> inkElements,
    String languageCode,
    GemmaVisionOcrService vision,
    InkImageRenderer render,
  ) async {
    final lines =
        await _recognition.recognizeInkLines(inkElements, languageCode);
    final withText = [
      for (final line in lines)
        if (line.text.trim().isNotEmpty) line,
    ];
    // Not a doodle: if NO line reads, ML Kit is the wrong tool for this
    // handwriting and the page must not come back empty.
    if (withText.isEmpty) return null;

    final median = _medianLineHeight(withText);
    final weak = <int>[
      for (var i = 0; i < lines.length; i++)
        if (inkLineNeedsVision(
          text: lines[i].text,
          score: lines[i].score,
          lineHeight: lines[i].bounds.height,
          medianLineHeight: median,
        ))
          i,
    ];

    final regions = _runsOf(weak);
    // Mostly weak, or many separate regions: ML Kit is struggling with this
    // hand, and one page read beats a handful of small ones.
    if (weak.length * 2 > withText.length || regions.length > _maxRefineRegions) {
      return null;
    }

    // Each weak region is read by Gemma from a crop of just its strokes.
    final elementOf = Map<List<StrokePoint>, FreehandElement>.identity();
    for (final e in inkElements) {
      if (e is FreehandElement) elementOf[e.points] = e;
    }
    final replacement = <int, String>{}; // a region's first line → its text
    final kept = <RecognizedInkLine>[]; // lines whose ML Kit text stands
    final inRegion = <int>{};
    for (final region in regions) {
      inRegion.addAll(region);
      final regionLines = [for (final i in region) lines[i]];
      final mlText = regionLines
          .map((l) => l.text.trim())
          .where((t) => t.isNotEmpty)
          .join('\n');

      final png = await render([
        for (final line in regionLines)
          for (final stroke in line.strokes) elementOf[stroke]!,
      ]);

      // Keyed by the crop itself, so the same handwriting is never sent twice
      // — and moving it on the page does not matter, since the crop is tight.
      final cacheKey = _cacheOn && png != null
          ? _cacheKey('ink', png, GemmaVisionOcrService.cacheVersion)
          : null;
      final remembered =
          cacheKey == null ? null : await _remembered(cacheKey, vary: false);

      GemmaOcrResult? read;
      if (remembered == null && png != null) {
        read = await vision.read(png,
            maxOutputTokens: _regionTokens(regionLines.length));
        if (read.passed && cacheKey != null) {
          await _remember(cacheKey, CachedRead(text: read.text));
        }
      }

      if (remembered != null) {
        replacement[region.first] = remembered.text;
      } else if (read != null && read.passed) {
        replacement[region.first] = read.text;
      } else {
        // Gemma failed the gate, or the crop could not be drawn: ML Kit's
        // reading, however poor, beats losing the lines. (A weak line always
        // HAS ML Kit text — a line that read as nothing is never "weak" — so
        // there is something to keep.)
        replacement[region.first] = mlText;
        kept.addAll(regionLines);
      }
    }

    final parts = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (inRegion.contains(i)) {
        final text = replacement[i]; // only a region's first line carries it
        if (text != null && text.trim().isNotEmpty) parts.add(text.trim());
      } else if (lines[i].text.trim().isNotEmpty) {
        parts.add(lines[i].text.trim());
        kept.add(lines[i]);
      }
    }

    final scores = [for (final line in kept) ...line.segmentScores];
    return (
      text: parts.join('\n'),
      score: scores.isEmpty
          ? null
          : scores.reduce((a, b) => a + b) / scores.length,
      // Every stroke read as text and none of it needed the model: this is
      // handwriting, not a drawing.
      plainText: regions.isEmpty && withText.length == lines.length,
    );
  }

  /// The page's typical line height — what "unusually tall" is measured against.
  static double _medianLineHeight(List<RecognizedInkLine> lines) {
    final heights = [for (final line in lines) line.bounds.height]..sort();
    return heights[heights.length ~/ 2];
  }

  /// Groups consecutive indexes into runs: [1, 2, 4] → [[1, 2], [4]].
  static List<List<int>> _runsOf(List<int> indexes) {
    final runs = <List<int>>[];
    for (final i in indexes) {
      if (runs.isNotEmpty && runs.last.last == i - 1) {
        runs.last.add(i);
      } else {
        runs.add([i]);
      }
    }
    return runs;
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
      final GemmaOcrResult result;
      try {
        result = await vision.read(bytes, vary: vary);
      } on AiModelNotReadyException {
        rethrow; // the UI turns this into the "download the model" offer
      } catch (_) {
        // One image the model chokes on must not cost the page every other
        // image's text; it is read by ML Kit instead, and flagged unread if
        // that finds nothing either.
        return _readImageTextOrEmpty(e.relativeImagePath);
      }
      if (result.passed) return result.text;
      final ml = await _readImageTextOrEmpty(e.relativeImagePath);
      return ml.isNotEmpty ? ml : result.text;
    }
    return _readImageTextOrEmpty(e.relativeImagePath);
  }

  /// ML Kit's reading of an image, or '' when there is none — including when
  /// what it read is not any language. That is what its Latin recogniser makes of
  /// Bengali script, and kept it would be stored and indexed as the page's text;
  /// dropped, the image is honestly "not read" (a deep read has Gemma for it, and
  /// beats this noise as the fallback too).
  Future<String> _readImageTextOrEmpty(String relativeImagePath) async {
    final reader = _readImageText;
    if (reader == null) return '';
    final text = (await reader(relativeImagePath)).trim();
    final detector = _languageDetector;
    if (detector != null && await isUnreadable(text, detector)) return '';
    return text;
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
