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

/// HuggingFace rejected the credential itself — revoked, mistyped, or fake.
///
/// Deliberately distinct from [EmbedderTokenRequiredException] ("no token at
/// all") and from [ModelLicenceNotAcceptedException] ("token is fine, licence
/// isn't accepted"): all three are auth failures, and all three need a
/// different action from the user.
///
/// This used to cover the licence case too, and so had to name both causes
/// without knowing which applied — a message that read as an accusation about
/// a token that was usually perfectly good. `hf_token_check.dart` now
/// establishes which one it is before we say anything, so this exception can
/// mean exactly one thing.
class ModelAuthException extends LlmException {
  /// Whether a token was actually sent — decides which fix we tell the user.
  final bool hadToken;

  ModelAuthException(String modelName, {required this.hadToken, Object? cause})
      : super(
            hadToken
                ? 'HuggingFace rejected this token — it may have been revoked, '
                    'or pasted incompletely. Tap Change above to replace it.'
                : '$modelName needs a HuggingFace token. Accept the licence '
                    'for the model, create a read token, and add it in '
                    'Settings → AI.',
            cause);
}

/// The token works, but its owner has never accepted the model's licence.
///
/// The single most common reason a gated download fails, and the only one with
/// a genuinely quick fix — `gated: auto` repos grant access the instant the
/// form is submitted. It carries [modelPageUrl] because the fix is
/// unreachable from inside the app: HuggingFace accepts a licence ONLY from a
/// browser ("Requesting access can only be done from your browser"), so the UI
/// must be able to offer that page as a tap.
class ModelLicenceNotAcceptedException extends LlmException {
  /// The repo page carrying the "Agree and access repository" form.
  final String modelPageUrl;

  /// HuggingFace account the token belongs to, when known. Naming it is what
  /// makes the message land: it proves the token was read and accepted, so the
  /// user stops re-checking the credential and goes to the actual blocker.
  final String? username;

  ModelLicenceNotAcceptedException(
    String modelName, {
    required this.modelPageUrl,
    this.username,
    Object? cause,
  }) : super(
            username != null
                ? 'Your token works (signed in as $username), but the licence '
                    'for $modelName has not been accepted yet. Open the model '
                    'page and tap "Agree and access repository" — access is '
                    'granted instantly.'
                : '$modelName is gated and its licence has not been accepted '
                    'yet. Open the model page and tap "Agree and access '
                    'repository" — access is granted instantly.',
            cause);
}

/// The token authenticates but is fine-grained and lacks gated-repo access.
///
/// Its own exception rather than a footnote on [ModelAuthException], because
/// both of the other messages send this user somewhere useless: the token is
/// not revoked, and accepting the licence will not help while the token cannot
/// read gated repos. Without this they would accept the licence, retry, fail
/// identically, and have no idea why.
class ModelTokenScopeException extends LlmException {
  final String modelPageUrl;

  ModelTokenScopeException(String modelName, {required this.modelPageUrl,
      Object? cause})
      : super(
            'This is a fine-grained token without access to gated repos, so '
            'HuggingFace will not serve $modelName. Either edit the token to '
            'allow "Read access to contents of all public gated repos", or '
            'create a plain Read token instead.',
            cause);
}

/// HuggingFace is rate-limiting downloads (HTTP 429).
class ModelRateLimitedException extends LlmException {
  ModelRateLimitedException([Object? cause])
      : super(
            'HuggingFace is rate-limiting downloads right now. Wait a few '
            'minutes and try again — adding a token in Settings → AI also '
            'raises the limit.',
            cause);
}

/// The download could not reach HuggingFace, or it answered 5xx. Retryable —
/// the plugin already retried internally before this surfaced.
class ModelNetworkException extends LlmException {
  ModelNetworkException(String modelName, [Object? cause])
      : super(
            'Could not download $modelName — check your internet connection '
            'and try again.',
            cause);
}

/// Reclaiming disk space was abandoned because the model index disagreed with
/// itself — a file the app has installed was reported as unused.
///
/// Deliberately a hard stop rather than a warning: the operation it guards
/// deletes multi-gigabyte files, and proceeding on inconsistent bookkeeping is
/// how a user loses a 2.4 GB download they never asked to remove.
class StorageCleanupUnsafeException extends LlmException {
  StorageCleanupUnsafeException()
      : super('Could not safely free up space — the list of installed models '
            'looks inconsistent. Restart the app and try again.');
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
