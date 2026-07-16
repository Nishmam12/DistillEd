// Tunable sampling/decoding knobs for a single AI generation request.

import 'package:flutter/foundation.dart' show immutable, listEquals;

/// Parameters passed to [AiProvider.generate].
///
/// A provider applies what it supports and ignores the rest (a runtime with no
/// top-k control simply drops [topK]). Adding a new knob here is therefore
/// non-breaking — no provider is forced to honour it — which keeps the Phase 3
/// router free to grow options without touching implementations.
@immutable
class AiGenerationOptions {
  /// Randomness of sampling. 0.0 = deterministic/greedy, higher = more varied.
  final double temperature;

  /// Hard cap on generated tokens. Null lets the provider use its own default.
  final int? maxTokens;

  /// Generation stops as soon as any of these strings is produced.
  final List<String> stopSequences;

  /// Nucleus-sampling cutoff (0.0–1.0). Null = provider default.
  final double? topP;

  /// Top-k sampling cutoff. Null = provider default.
  final int? topK;

  /// Fixed RNG seed for reproducible output, where the provider supports it.
  final int? seed;

  const AiGenerationOptions({
    this.temperature = 0.7,
    this.maxTokens,
    this.stopSequences = const [],
    this.topP,
    this.topK,
    this.seed,
  });

  /// Deterministic preset for factual/extraction tasks (grammar, recognition
  /// cleanup, structured output) where creativity is unwanted.
  static const AiGenerationOptions precise = AiGenerationOptions(temperature: 0.0);

  AiGenerationOptions copyWith({
    double? temperature,
    int? maxTokens,
    List<String>? stopSequences,
    double? topP,
    int? topK,
    int? seed,
  }) {
    return AiGenerationOptions(
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      stopSequences: stopSequences ?? this.stopSequences,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      seed: seed ?? this.seed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiGenerationOptions &&
          other.temperature == temperature &&
          other.maxTokens == maxTokens &&
          listEquals(other.stopSequences, stopSequences) &&
          other.topP == topP &&
          other.topK == topK &&
          other.seed == seed;

  @override
  int get hashCode => Object.hash(
        temperature,
        maxTokens,
        Object.hashAll(stopSequences),
        topP,
        topK,
        seed,
      );

  @override
  String toString() =>
      'AiGenerationOptions(temperature: $temperature, maxTokens: $maxTokens, '
      'stopSequences: $stopSequences, topP: $topP, topK: $topK, seed: $seed)';
}
