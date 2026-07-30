// "Is this token itself valid?" — asked WITHOUT reference to any repo.
//
// The companion to `hf_access_check.dart`, and the reason the app can finally
// name the real problem. That probe asks "can this token fetch this file?",
// and for a gated repo a failure there has two completely different causes
// with completely different fixes:
//
//   • the token is revoked/mistyped        → replace the token
//   • the licence was never accepted       → tap "Agree" on the model page
//
// HuggingFace does not distinguish them in its answer. Probing the gated
// EmbeddingGemma file on 2026-07-30 returned a byte-identical
// `401 + X-Error-Code: GatedRepo` for *no* token and for a garbage token, so
// neither the status code nor the error code can separate the two. That is why
// the old message hedged and listed both causes — it genuinely did not know.
//
// `/api/whoami-v2` settles it, because it involves no repo at all: if the token
// authenticates here, it is a working token, and any gate failure must
// therefore be the licence. Combined:
//
//   whoami valid + repo gated  ⇒ licence not accepted (actionable, one tap)
//   whoami invalid             ⇒ bad token
//
// FAIL-OPEN, exactly as in `hf_access_check.dart`: this only ever runs on a
// path that has ALREADY failed, and every non-answer lands on
// [HfTokenStatus.unknown]. A diagnostic must never invent a new failure.

import 'package:dio/dio.dart';

/// Whether HuggingFace recognises a token.
enum HfTokenStatus {
  /// Authenticated. The token works; anything still refused is about
  /// permissions on the specific repo, not the credential.
  valid,

  /// HuggingFace rejected the credential outright (revoked, mistyped, fake).
  invalid,

  /// Offline, timed out, or an unexpected answer. Callers MUST NOT treat this
  /// as either verdict.
  unknown,
}

/// What `/api/whoami-v2` reports about a token.
class HfTokenInfo {
  final HfTokenStatus status;

  /// HuggingFace username, for confirming to the user *which* account the app
  /// is acting as — "signed in as @you" is the sentence that convinces someone
  /// their token is genuinely fine and the licence is the real blocker.
  final String? username;

  /// Token role: `read`, `write`, or `fineGrained`.
  ///
  /// Worth carrying because of one specific trap: a **fine-grained** token
  /// authenticates perfectly here and STILL fails on gated repos unless the
  /// "Read access to contents of all public gated repos" permission was ticked
  /// when it was created. Without this field that user gets told the licence
  /// is missing, goes and accepts it, and fails again — so it earns a message
  /// of its own.
  final String? role;

  const HfTokenInfo({required this.status, this.username, this.role});

  const HfTokenInfo.unknown()
      : status = HfTokenStatus.unknown,
        username = null,
        role = null;

  /// True when this is a fine-grained token, which needs an explicit
  /// gated-repo permission that a plain read token has by default.
  bool get isFineGrained => role?.toLowerCase() == 'finegrained';
}

/// Seam so the managers stay unit-testable without a network.
abstract class HuggingFaceIdentity {
  Future<HfTokenInfo> whoami(String token);
}

class DioHuggingFaceIdentity implements HuggingFaceIdentity {
  static const _endpoint = 'https://huggingface.co/api/whoami-v2';

  /// Tight, and for a sharper reason than in [DioHuggingFaceAccess]: the user
  /// is already looking at a failed download, so a slow answer here delays an
  /// error message they are waiting on. Better to say less, sooner.
  static const _timeout = Duration(seconds: 10);

  final Dio _dio;

  DioHuggingFaceIdentity({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: _timeout));

  @override
  Future<HfTokenInfo> whoami(String token) async {
    if (token.trim().isEmpty) return const HfTokenInfo.unknown();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _endpoint,
        options: Options(
          headers: {'Authorization': 'Bearer ${token.trim()}'},
          validateStatus: (_) => true,
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
        ),
      );

      final status = response.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return const HfTokenInfo(status: HfTokenStatus.invalid);
      }
      if (status != 200) return const HfTokenInfo.unknown();

      final body = response.data;
      if (body == null) return const HfTokenInfo.unknown();

      // Shape: {"name": "...", "auth": {"accessToken": {"role": "read", …}}}.
      // Read defensively — a missing sub-object costs us the nicety of a
      // username, not the verdict, which the 200 already established.
      final auth = body['auth'];
      final accessToken =
          (auth is Map<String, dynamic>) ? auth['accessToken'] : null;
      return HfTokenInfo(
        status: HfTokenStatus.valid,
        username: body['name'] as String?,
        role: (accessToken is Map<String, dynamic>)
            ? accessToken['role'] as String?
            : null,
      );
    } on DioException {
      return const HfTokenInfo.unknown(); // offline, timeout, TLS, proxy
    } catch (_) {
      return const HfTokenInfo.unknown();
    }
  }
}
