// Gemma-vision OCR: the PRIMARY recogniser for the AI platform.
//
// This is the competition's headline capability — Gemma 4, not ML Kit, reading
// the page. It takes a rendered image (a page of handwriting rasterised to PNG,
// or an imported photo/PDF page) and returns Gemma's transcription, judged by
// the same [MeaningfulnessGate] the ML Kit path uses.
//
// Gemma runs first and does the real work. Two things sit strictly behind it:
//   * an auto-RETRY — if the first (deterministic) read looks like gibberish,
//     a second attempt at a higher temperature with a more coaxing prompt gets
//     a chance to escape a bad decode;
//   * ML Kit — the caller's LAST-RESORT fallback, used only when every Gemma
//     attempt failed the gate (see [PageContentExtractor]). Cloud escalation
//     (after 2 local failures, user-prompted) is Phase 2.

import 'dart:typed_data';

import '../../domain/ai_exception.dart';
import '../../domain/image_transcriber.dart';
import '../../domain/meaningfulness_gate.dart';

/// The outcome of a Gemma-vision read.
class GemmaOcrResult {
  /// Gemma's best transcription. When [passed] is false this is its best-effort
  /// text (possibly poor) — kept so the caller can use it if its own fallback
  /// turns up nothing.
  final String text;

  /// Whether some attempt's transcription passed the plausibility gate. When
  /// true, the caller should prefer [text] over any fallback.
  final bool passed;

  /// How many times Gemma was actually invoked (0 when the model wasn't even
  /// reachable and the call threw before any attempt).
  final int attempts;

  const GemmaOcrResult(
      {required this.text, required this.passed, required this.attempts});

  static const empty = GemmaOcrResult(text: '', passed: false, attempts: 0);
}

class GemmaVisionOcrService {
  final ImageTranscriber _transcriber;
  final MeaningfulnessGate _gate;

  /// Supplies a fresh random seed per sampled attempt so a re-read (and each
  /// retry) reads differently instead of repeating the last decode.
  final int Function() _seedSource;

  /// Total Gemma attempts per read: the first deterministic pass plus retries.
  /// 2 = one read + one retry, per the plan.
  final int maxAttempts;

  GemmaVisionOcrService({
    required ImageTranscriber transcriber,
    // Lenient by design: Gemma produces coherent prose or nothing, so the gate
    // here only guards against empty / symbol-garbage output, not the ML Kit
    // confidence score (Gemma has none). Real quality is Gemma's to deliver.
    MeaningfulnessGate gate =
        const MeaningfulnessGate(minWords: 2, minAlphaRatio: 0.4),
    this.maxAttempts = 2,
    int Function()? seedSource,
  })  : _transcriber = transcriber,
        _gate = gate,
        _seedSource = seedSource ?? _makeSeedSource();

  /// Whether [text] is a transcription worth keeping, by the SAME gate this
  /// service applies to its own attempts.
  ///
  /// Exposed so a transcription obtained elsewhere — the merged figure read,
  /// which returns `verbatim_text` from one shared vision call — is held to an
  /// identical standard before it is accepted in place of a dedicated pass.
  /// Sharing the gate is the point: two different bars would mean the cheaper
  /// path could quietly keep text this service would have rejected.
  bool accepts(String text) =>
      text.trim().isNotEmpty && _gate.evaluate(text).passed;

  /// A closure over its own counter, so successive calls never collide even
  /// within the same microsecond.
  static int Function() _makeSeedSource() {
    var counter = 0;
    return () {
      counter = (counter + 1) & 0x7fffffff;
      return (DateTime.now().microsecondsSinceEpoch ^ (counter * 0x9E3779B1)) &
          0x7fffffff;
    };
  }

  /// First, deterministic read — greedy decode for the most faithful pass.
  static const String _prompt =
      'You are a precise OCR engine. Transcribe every piece of text in this '
      'image — handwritten or printed — exactly as it appears, preserving line '
      'breaks and reading order (top to bottom, left to right). Do not '
      'translate, summarise, explain, or correct spelling. If a word is '
      'unclear, give your single best reading. Output only the transcribed text.';

  /// Retry read — a different, more coaxing prompt at a non-zero temperature so
  /// the second attempt is not a deterministic repeat of the first.
  static const String _retryPrompt =
      'Read this image line by line and write out all the text you can see, '
      'including messy or partial handwriting, doing your best on unclear words. '
      'Keep the original line breaks. Return only the text you read — no notes, '
      'no headings, no commentary.';

  /// Transcribes [imageBytes], stopping as soon as an attempt passes the gate.
  ///
  /// [vary] is what makes "Re-read" meaningful. A normal (first-open) read does
  /// a deterministic greedy pass first — the most faithful transcription — and
  /// only samples on its retry. A re-read samples from the very first attempt
  /// with a fresh seed, so it produces a genuinely different reading each time
  /// and can recover a word the deterministic pass misread. Without this,
  /// re-reading a page that already read cleanly returns byte-identical text and
  /// looks broken.
  ///
  /// Rethrows [AiModelNotReadyException] so the caller can offer the model
  /// download — a missing Gemma is not something ML Kit should paper over,
  /// because the downstream analysis needs Gemma too. A per-attempt
  /// [AiGenerationException] is swallowed as a failed attempt (the next attempt,
  /// or the caller's fallback, takes over).
  Future<GemmaOcrResult> read(Uint8List imageBytes, {bool vary = false}) async {
    var best = '';
    var attempts = 0;

    for (var i = 0; i < maxAttempts; i++) {
      // Deterministic only for the first attempt of a normal read; a re-read
      // and every retry sample so they differ from the last pass.
      final sampled = vary || i > 0;
      final temperature =
          vary ? (i == 0 ? 0.35 : 0.55) : (i == 0 ? 0.0 : 0.30);
      final String text;
      try {
        attempts++;
        text = (await _transcriber.transcribeImage(
          imageBytes,
          prompt: i == 0 ? _prompt : _retryPrompt,
          temperature: temperature,
          randomSeed: sampled ? _seedSource() : null,
        ))
            .trim();
      } on AiModelNotReadyException {
        rethrow;
      } on AiException {
        continue; // this attempt failed to run; try the next / fall back
      }

      if (best.isEmpty) best = text; // keep the first non-empty as the backstop
      if (text.isNotEmpty && _gate.evaluate(text).passed) {
        return GemmaOcrResult(text: text, passed: true, attempts: attempts);
      }
    }

    return GemmaOcrResult(text: best, passed: false, attempts: attempts);
  }
}
