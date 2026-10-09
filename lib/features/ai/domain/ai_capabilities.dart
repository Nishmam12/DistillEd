// Static description of what an AI provider can do.

import 'package:flutter/foundation.dart' show immutable;

/// Declares a provider's identity and limits so callers — most importantly the
/// Phase 3 intelligent router — can pick the right backend for a request
/// without inspecting the concrete type.
///
/// This is metadata about the provider, not per-request state; it should be a
/// cheap `const` on each [AiProvider] implementation.
@immutable
class AiCapabilities {
  /// Stable machine identifier, e.g. `gemma-2b-it-local`.
  final String modelId;

  /// Human-readable name for debug UIs and "which model answered" labels.
  final String displayName;

  /// Maximum combined prompt + response tokens the model accepts.
  final int contextWindowTokens;

  /// True for on-device models (offline, private, no per-call cost).
  final bool isLocal;

  const AiCapabilities({
    required this.modelId,
    required this.displayName,
    required this.contextWindowTokens,
    this.isLocal = false,
  });

  @override
  String toString() => 'AiCapabilities($modelId, ctx: $contextWindowTokens, '
      'local: $isLocal)';
}
