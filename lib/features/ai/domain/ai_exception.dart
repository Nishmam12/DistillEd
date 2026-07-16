// Typed failures surfaced by any AI provider.
//
// Providers throw these (and stream errors emit them) instead of raw
// `Exception` / `UnimplementedError`, so the Phase 3 router can branch on the
// failure kind — fall back to another provider, prompt a model download, or
// surface an offline message — without string-matching.

/// Base type for all AI provider failures. Sealed so exhaustive `switch`
/// handling stays honest as new kinds are added.
sealed class AiException implements Exception {
  /// Human-readable explanation, safe to log.
  final String message;

  /// The underlying error, if this wraps one.
  final Object? cause;

  const AiException(this.message, {this.cause});

  @override
  String toString() =>
      cause == null ? '$runtimeType: $message' : '$runtimeType: $message ($cause)';
}

/// The provider's model is not usable yet — not downloaded, not initialised, or
/// still loading. Callers may trigger a download/warm-up and retry.
final class AiModelNotReadyException extends AiException {
  const AiModelNotReadyException(super.message, {super.cause});
}

/// The provider cannot serve the request right now for an external reason
/// (e.g. a cloud provider with no network). Callers may route elsewhere.
final class AiUnavailableException extends AiException {
  const AiUnavailableException(super.message, {super.cause});
}

/// Generation or embedding started but failed partway.
final class AiGenerationException extends AiException {
  const AiGenerationException(super.message, {super.cause});
}

/// The provider does not implement the requested operation at all — e.g.
/// `embed` on a runtime without embedding support. Distinct from
/// [AiUnavailableException]: retrying or routing won't help unless a different
/// provider supports it.
final class AiUnsupportedOperationException extends AiException {
  const AiUnsupportedOperationException(super.message, {super.cause});
}
