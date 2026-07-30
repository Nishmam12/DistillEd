// Translates flutter_gemma's typed download failures into our [LlmException]
// family, so the UI can tell the user what to actually DO.
//
// Why this file exists: the plugin already classifies every failure precisely
// (`DownloadError.unauthorized/forbidden/rateLimited/notFound/serverError/
// network`), and both download managers used to throw all of it away behind a
// single `catch (e) => ModelDownloadException('… download failed.')`. The
// common real-world case — a perfectly valid token whose owner never accepted
// the model's licence, which HuggingFace answers with 403 — reached the user as
// "Embedding model download failed.", pointing at nothing.
//
// The plugin's own `toUserMessage()` is not used: it tells the user to call
// `FlutterGemma.initialize(huggingFaceToken:)`, an API detail of a package they
// have never heard of, when the real fix is a screen in this app.

import 'package:flutter_gemma/flutter_gemma.dart';

import 'llm_exceptions.dart';

/// Maps [error] onto the most actionable [LlmException] available.
///
/// [modelName] names the model in the message; [hadToken] decides which of the
/// two auth remedies to suggest. Already-typed [LlmException]s pass through
/// untouched so a specific failure raised deeper in the stack is never
/// re-wrapped into a vaguer one.
LlmException translateDownloadFailure(
  Object error, {
  required String modelName,
  required bool hadToken,
}) {
  if (error is LlmException) return error;

  if (error is DownloadException) {
    return switch (error.error) {
      // 401 (no/!valid credentials) and 403 (valid token, no licence access)
      // share a remedy screen, and HuggingFace is not consistent about which
      // one a gated repo returns — so they share an exception that names both.
      UnauthorizedError() ||
      ForbiddenError() =>
        ModelAuthException(modelName, hadToken: hadToken, cause: error),
      RateLimitedError() => ModelRateLimitedException(error),
      NetworkError() ||
      ServerError() =>
        ModelNetworkException(modelName, error),
      CanceledError() => ModelDownloadCancelledException(),
      // A 404 on a URL that used to work means the upstream repo moved or
      // renamed the file — nothing the user can fix, so say so plainly rather
      // than sending them to check their connection.
      NotFoundError() => ModelDownloadException(
          '$modelName is no longer available at its download URL. This needs '
          'an app update — please report it.',
          error),
      UnknownError(:final message) =>
        ModelDownloadException('Could not download $modelName. $message', error),
    };
  }

  return ModelDownloadException('Could not download $modelName.', error);
}
