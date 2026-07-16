// Typed failures for the local-LLM stack, so the UI can show actionable
// states instead of raw plugin errors.

class LlmException implements Exception {
  final String message;
  final Object? cause;
  LlmException(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message';
}

/// Not enough free disk space to download the model.
class InsufficientStorageException extends LlmException {
  final int requiredBytes;
  final int availableBytes;
  InsufficientStorageException(
      {required this.requiredBytes, required this.availableBytes})
      : super('Need ${requiredBytes ~/ (1024 * 1024)} MB free, '
            'only ${availableBytes ~/ (1024 * 1024)} MB available.');
}

/// The user cancelled an in-progress model download. (Named to avoid clashing
/// with flutter_gemma's own DownloadCancelledException export.)
class ModelDownloadCancelledException extends LlmException {
  ModelDownloadCancelledException() : super('Model download cancelled.');
}

/// A model download failed (network, server, storage I/O).
class ModelDownloadException extends LlmException {
  ModelDownloadException(super.message, [super.cause]);
}

/// Generation did not finish within the allowed time.
class LlmTimeoutException extends LlmException {
  LlmTimeoutException(Duration timeout)
      : super('The model did not respond within ${timeout.inSeconds}s.');
}

/// The local model is not downloaded/installed yet.
class LlmNotReadyException extends LlmException {
  LlmNotReadyException()
      : super('The on-device model has not been downloaded yet.');
}

/// Generation failed at the runtime layer.
class LlmGenerationException extends LlmException {
  LlmGenerationException(super.message, [super.cause]);
}
