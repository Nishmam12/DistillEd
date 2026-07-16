// Wraps ML Kit Digital Ink Recognition (stroke-based, NOT image OCR) for the
// summarize feature: language-model management, InkFlow-stroke → ML Kit Ink
// conversion (with timestamp synthesis for legacy strokes), per-page
// recognition, page-order concatenation, and the meaningfulness gate.

import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as mlkit;

import '../../../editor/domain/models/stroke.dart';
import '../models/recognition_result.dart';
import 'meaningfulness_gate.dart';

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
  static mlkit.Ink strokesToInk(List<Stroke> strokes) {
    final ink = mlkit.Ink();
    int clock = 0;
    bool first = true;

    for (final stroke in strokes) {
      if (stroke.isEraser || stroke.points.isEmpty) continue;

      final startAt = first ? 0 : clock + synthStrokeGapMs;
      first = false;

      final hasFullTiming = stroke.points.every((p) => p.t != null);
      final mlStroke = mlkit.Stroke();

      if (hasFullTiming) {
        final base = stroke.points.first.t!;
        int prev = startAt;
        for (final p in stroke.points) {
          // Clamp to be monotonically non-decreasing (defensive: real event
          // timestamps should already be ordered).
          final t = startAt + (p.t! - base);
          final clamped = t < prev ? prev : t;
          mlStroke.points.add(mlkit.StrokePoint(x: p.x, y: p.y, t: clamped));
          prev = clamped;
        }
        clock = prev;
      } else {
        for (int i = 0; i < stroke.points.length; i++) {
          final p = stroke.points[i];
          mlStroke.points.add(mlkit.StrokePoint(
              x: p.x, y: p.y, t: startAt + i * synthPointGapMs));
        }
        clock = startAt + (stroke.points.length - 1) * synthPointGapMs;
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
  }) async {
    final ink = strokesToInk(strokes);
    if (ink.strokes.isEmpty) return const PageRecognition.empty();

    final recognizer = _recognizers.putIfAbsent(
      languageCode,
      () => mlkit.DigitalInkRecognizer(languageCode: languageCode),
    );

    final List<mlkit.RecognitionCandidate> candidates;
    try {
      candidates = await recognizer.recognize(
        ink,
        context: writingArea == null
            ? null
            : mlkit.DigitalInkRecognitionContext(writingArea: writingArea),
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

    final text = pages
        .map((p) => p.text.trim())
        .where((t) => t.isNotEmpty)
        .join('\n\n');
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
