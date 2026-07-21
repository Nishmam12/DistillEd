// Wraps ML Kit Digital Ink Recognition (stroke-based, NOT image OCR) for the
// AI platform: language-model management, ink → ML Kit Ink conversion (with
// timestamp synthesis for legacy strokes), per-page recognition, page-order
// concatenation, and the meaningfulness gate.
//
// Two ink sources feed the same conversion core: legacy [Stroke] lists and
// editor-2.0 [FreehandElement]s — both carry the same [StrokePoint]s
// (including the capture timestamp `t`).

import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as mlkit;

import '../../../../domain/model/scene_element.dart';
import '../../../editor/domain/models/stroke.dart';
import '../../domain/handwriting/ink_lines.dart';
import '../../domain/recognition_result.dart';
import '../../domain/meaningfulness_gate.dart';

/// The per-stroke fields the ML Kit conversion needs, shared by legacy
/// [Stroke] and editor-2.0 [FreehandElement].
typedef _InkSource = ({List<StrokePoint> points, bool isEraser});

/// Thrown when recognition fails at the platform layer (e.g. language model
/// missing). Carries a user-actionable message.
class RecognitionException implements Exception {
  final String message;
  final Object? cause;
  RecognitionException(this.message, [this.cause]);

  @override
  String toString() => 'RecognitionException: $message';
}

class HandwritingRecognitionService {
  /// Synthetic timing for strokes that predate the `t` field (legacy .ink
  /// files): ~10 ms between points, 300 ms between strokes (per spec; also the
  /// gap used when rebasing real-timestamped strokes onto the shared timeline).
  static const int synthPointGapMs = 10;
  static const int synthStrokeGapMs = 300;

  final MeaningfulnessGate _gate;
  final mlkit.DigitalInkRecognizerModelManager _modelManager;

  /// One recognizer per language, created lazily and closed on [dispose].
  final Map<String, mlkit.DigitalInkRecognizer> _recognizers = {};

  HandwritingRecognitionService({
    MeaningfulnessGate gate = const MeaningfulnessGate(),
    mlkit.DigitalInkRecognizerModelManager? modelManager,
  })  : _gate = gate,
        _modelManager =
            modelManager ?? mlkit.DigitalInkRecognizerModelManager();

  // ---- Language model management (models are ~20 MB, managed by ML Kit) ----

  Future<bool> isModelDownloaded(String languageCode) =>
      _modelManager.isModelDownloaded(languageCode);

  /// Downloads the recognition model for [languageCode] if not present.
  /// Wi-Fi is preferred but not required — the models are small.
  Future<void> ensureModelDownloaded(String languageCode) async {
    if (await _modelManager.isModelDownloaded(languageCode)) return;
    final ok =
        await _modelManager.downloadModel(languageCode, isWifiRequired: false);
    if (!ok) {
      throw RecognitionException(
          'Could not download the handwriting model for "$languageCode".');
    }
  }

  Future<bool> deleteModel(String languageCode) =>
      _modelManager.deleteModel(languageCode);

  // ---- Stroke → Ink conversion ---------------------------------------------

  /// Converts InkFlow strokes to an ML Kit [mlkit.Ink], skipping eraser and
  /// empty strokes.
  ///
  /// All strokes are rebased onto one continuous, monotonic timeline:
  /// * a stroke whose every point carries a real `t` keeps its internal deltas
  ///   (real pen dynamics) but starts [synthStrokeGapMs] after the previous
  ///   stroke ends;
  /// * a stroke with any missing `t` (legacy files, pre-`t` pixel-erase splits)
  ///   is fully synthesized at [synthPointGapMs] per point.
  /// Rebasing matters because real timestamps are monotonic-since-boot while
  /// synthetic ones start at 0 — mixing them raw would produce wild gaps and
  /// out-of-order strokes, which degrades recognition.
  static mlkit.Ink strokesToInk(List<Stroke> strokes) => _toInk([
        for (final s in strokes) (points: s.points, isEraser: s.isEraser),
      ]);

  /// Editor-2.0 variant: converts the freehand ink among [elements]. Non-ink
  /// elements (shapes, text, images, frames) are ignored.
  static mlkit.Ink elementsToInk(List<SceneElement> elements) => _toInk([
        for (final e in elements)
          if (e is FreehandElement) (points: e.points, isEraser: e.isEraser),
      ]);

  static mlkit.Ink _toInk(List<_InkSource> strokes) => _pointsToInk([
        for (final s in strokes)
          if (!s.isEraser && s.points.isNotEmpty) s.points,
      ]);

  /// Builds the ML Kit ink from already-filtered stroke point lists, rebasing
  /// them onto one monotonic timeline (see [strokesToInk] for the rules).
  static mlkit.Ink _pointsToInk(List<List<StrokePoint>> strokes) {
    final ink = mlkit.Ink();
    int clock = 0;
    bool first = true;

    for (final points in strokes) {
      if (points.isEmpty) continue;

      final startAt = first ? 0 : clock + synthStrokeGapMs;
      first = false;

      final hasFullTiming = points.every((p) => p.t != null);
      final mlStroke = mlkit.Stroke();

      if (hasFullTiming) {
        final base = points.first.t!;
        int prev = startAt;
        for (final p in points) {
          // Clamp to be monotonically non-decreasing (defensive: real event
          // timestamps should already be ordered).
          final t = startAt + (p.t! - base);
          final clamped = t < prev ? prev : t;
          mlStroke.points.add(mlkit.StrokePoint(x: p.x, y: p.y, t: clamped));
          prev = clamped;
        }
        clock = prev;
      } else {
        for (int i = 0; i < points.length; i++) {
          final p = points[i];
          mlStroke.points.add(mlkit.StrokePoint(
              x: p.x, y: p.y, t: startAt + i * synthPointGapMs));
        }
        clock = startAt + (points.length - 1) * synthPointGapMs;
      }

      ink.strokes.add(mlStroke);
    }

    return ink;
  }

  // ---- Recognition ----------------------------------------------------------

  /// Recognizes one page of strokes. Returns [PageRecognition.empty] when the
  /// page has no recognizable ink.
  Future<PageRecognition> recognizePage(
    List<Stroke> strokes,
    String languageCode, {
    mlkit.WritingArea? writingArea,
  }) {
    return _recognizeSources([
      for (final s in strokes) (points: s.points, isEraser: s.isEraser),
    ], languageCode, writingArea: writingArea);
  }

  /// Editor-2.0 variant of [recognizePage]: recognizes the freehand ink among
  /// one page's [elements].
  Future<PageRecognition> recognizeElements(
    List<SceneElement> elements,
    String languageCode, {
    mlkit.WritingArea? writingArea,
  }) {
    return _recognizeSources([
      for (final e in elements)
        if (e is FreehandElement) (points: e.points, isEraser: e.isEraser),
    ], languageCode, writingArea: writingArea);
  }

  /// How much already-recognized text to offer ML Kit as [preContext]. It only
  /// wants the characters immediately before the insertion point, and a long
  /// tail would bias the language model toward earlier, unrelated writing.
  static const int preContextChars = 40;

  /// Recognizes a page of ink one handwritten *segment* at a time.
  ///
  /// ML Kit's recogniser expects the contents of a single writing area, so
  /// feeding it a whole page at once returns junk (observed on device as
  /// `:::::::::` with a hopeless score). Strokes are grouped into lines, each
  /// line is split at table-column gaps, and each segment is normalised to a
  /// consistent scale — raw scene coordinates depend on the zoom the user wrote
  /// at, which the recogniser cannot know — then recognised on its own with a
  /// [mlkit.WritingArea] matching the normalised extent.
  ///
  /// Each segment is also given the text recognised before it as `preContext`,
  /// which is how ML Kit is told what word it is reading into: with it the
  /// recogniser's language model resolves ambiguous letters using the sentence
  /// so far instead of guessing each segment in isolation.
  ///
  /// Segments on a line are joined with a double space (preserving the columns
  /// of a table), lines with a newline.
  ///
  /// An explicit [writingArea] (callers that already know their surface) wins
  /// over the per-segment one.
  Future<PageRecognition> _recognizeSources(
    List<_InkSource> sources,
    String languageCode, {
    mlkit.WritingArea? writingArea,
  }) async {
    final lines = groupStrokesIntoLines([
      for (final s in sources)
        if (!s.isEraser && s.points.isNotEmpty) s.points,
    ]);
    if (lines.isEmpty) return const PageRecognition.empty();

    final texts = <String>[];
    final scores = <double>[];

    for (final line in lines) {
      final segments = <String>[];
      for (final segment in splitLineAtColumnGaps(line)) {
        final normalized = normalizeInkLine(segment);
        final ink = _pointsToInk(normalized.strokes);
        if (ink.strokes.isEmpty) continue;

        // A degenerate segment (a perfectly flat dash) has no area to describe;
        // sending a zero-sized writing area would be worse than sending none.
        final area = writingArea ??
            (normalized.width > 0 && normalized.height > 0
                ? mlkit.WritingArea(
                    width: normalized.width, height: normalized.height)
                : null);

        final result = await _recognizeInk(
          ink,
          languageCode,
          writingArea: area,
          preContext: _preContextFrom(texts, segments),
        );
        final text = result.text.trim();
        if (text.isNotEmpty) segments.add(text);
        if (result.topScore != null) scores.add(result.topScore!);
      }
      if (segments.isNotEmpty) texts.add(segments.join('  '));
    }

    return PageRecognition(
      text: texts.join('\n'),
      // Mean across segments: the whole-page analogue of what a single-ink call
      // used to report, rather than letting one good line flatter the page.
      topScore: scores.isEmpty
          ? null
          : scores.reduce((a, b) => a + b) / scores.length,
      hasInk: true,
    );
  }

  /// The tail of everything recognized so far — earlier [lines] plus the
  /// [segments] already read on the current line. Null when there is nothing
  /// yet, so the first segment on a page is recognised without a hint rather
  /// than with an empty one.
  static String? _preContextFrom(List<String> lines, List<String> segments) {
    final joined = [...lines, ...segments].join(' ').trim();
    if (joined.isEmpty) return null;
    return joined.length <= preContextChars
        ? joined
        : joined.substring(joined.length - preContextChars);
  }

  Future<PageRecognition> _recognizeInk(
    mlkit.Ink ink,
    String languageCode, {
    mlkit.WritingArea? writingArea,
    String? preContext,
  }) async {
    if (ink.strokes.isEmpty) return const PageRecognition.empty();

    final recognizer = _recognizers.putIfAbsent(
      languageCode,
      () => mlkit.DigitalInkRecognizer(languageCode: languageCode),
    );

    final List<mlkit.RecognitionCandidate> candidates;
    try {
      candidates = await recognizer.recognize(
        ink,
        context: writingArea == null && preContext == null
            ? null
            : mlkit.DigitalInkRecognitionContext(
                writingArea: writingArea, preContext: preContext),
      );
    } catch (e) {
      throw RecognitionException(
          'Handwriting recognition failed — is the "$languageCode" model downloaded?',
          e);
    }

    if (candidates.isEmpty) {
      return const PageRecognition(text: '', topScore: null, hasInk: true);
    }
    // Candidates are ordered most-likely first.
    final top = candidates.first;
    return PageRecognition(text: top.text, topScore: top.score, hasInk: true);
  }

  /// Recognizes a whole notebook: [pagesStrokes] must be in page order. Page
  /// texts are concatenated with blank lines and run through the
  /// meaningfulness gate.
  Future<RecognitionOutcome> recognizeNotebook(
    List<List<Stroke>> pagesStrokes,
    String languageCode, {
    mlkit.WritingArea? writingArea,
  }) async {
    final pages = <PageRecognition>[];
    for (final strokes in pagesStrokes) {
      pages.add(
          await recognizePage(strokes, languageCode, writingArea: writingArea));
    }

    final text =
        pages.map((p) => p.text.trim()).where((t) => t.isNotEmpty).join('\n\n');
    final scores = [
      for (final p in pages)
        if (p.topScore != null) p.topScore!,
    ];

    return RecognitionOutcome(
      text: text,
      pages: pages,
      gate: _gate.evaluate(text, topScores: scores),
    );
  }

  /// Closes all cached recognizers.
  Future<void> dispose() async {
    for (final r in _recognizers.values) {
      await r.close();
    }
    _recognizers.clear();
  }
}
