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

  /// Whether [AiProvider.generate] yields incremental chunks (vs. one final
  /// chunk). The contract is a stream either way; this flags true token
  /// streaming for UI that shows live typing.
  final bool supportsStreaming;

  /// Whether the provider can accept image input (Phase 4 vision).
  final bool supportsVision;

  /// Whether [AiProvider.embed] is implemented (vs. throwing
  /// `AiUnsupportedOperationException`). Drives Phase 2 RAG.
  final bool supportsEmbeddings;

  /// True for on-device models (offline, private, no per-call cost).
  final bool isLocal;

  /// Rough USD cost of an average call, for the router's cost factor.
  /// 0 for local models.
  final double approxCostPerCallUsd;

  const AiCapabilities({
    required this.modelId,
    required this.displayName,
    required this.contextWindowTokens,
    this.supportsStreaming = true,
    this.supportsVision = false,
    this.supportsEmbeddings = false,
    this.isLocal = false,
    this.approxCostPerCallUsd = 0.0,
  });

  @override
  String toString() => 'AiCapabilities($modelId, ctx: $contextWindowTokens, '
      'local: $isLocal, embeddings: $supportsEmbeddings)';
}
