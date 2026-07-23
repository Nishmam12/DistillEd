// A backend that can read the text out of an image (OCR via a vision model).
//
// Kept separate from [AiProvider] because vision is a distinct capability with
// a distinct shape — one image in, one transcription out, no streaming — and
// most providers (every cloud tier today) don't have it. The on-device
// [LocalGemmaProvider] implements this over the SAME loaded model it uses for
// text, which is why it lives beside the provider contract: the implementer
// must serialise transcription against generation so the 2.4 GB model is never
// loaded twice at once.

import 'dart:typed_data';

import 'ai_exception.dart';

/// Transcribes the text visible in an image using a vision-capable model.
abstract class ImageTranscriber {
  /// Reads [imageBytes] (a PNG/JPEG) under [prompt] and returns the model's raw
  /// transcription. Deterministic at [temperature] 0.
  ///
  /// [randomSeed] seeds sampling: pass a fresh value each call (with
  /// [temperature] > 0) to get a genuinely different reading — what "re-read"
  /// needs, since a fixed seed at any temperature repeats the same output. Null
  /// uses the runtime default (fixed), which only matters when sampling.
  ///
  /// Throws [AiModelNotReadyException] when the vision model isn't downloaded or
  /// can't load, and [AiGenerationException] when a load succeeds but inference
  /// fails — callers distinguish "can't run" (offer the download) from "ran
  /// badly" (fall back) without string-matching.
  Future<String> transcribeImage(
    Uint8List imageBytes, {
    required String prompt,
    double temperature = 0.0,
    int maxOutputTokens = 1024,
    int? randomSeed,
  });
}
