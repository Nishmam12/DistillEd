// A cheap "can this token actually fetch this file?" probe, run BEFORE a
// multi-hundred-megabyte download commits.
//
// Why: the only pre-download token check used to be "is the string non-empty".
// A token that is expired, revoked, write-scoped, or — by far the most common —
// belongs to someone who never clicked "Acknowledge licence" on the gated model
// page passes that check happily, and the user then watches a 175 MB download
// crawl for minutes before dying on an auth error. One HEAD request tells us
// the same thing in ~200 ms.
//
// FAIL-OPEN is the governing rule here: this probe may only ever *veto* a
// download on a definitive auth answer from HuggingFace. Anything else — no
// connectivity, a timeout, a proxy, an unexpected status — returns
// [HfAccess.unknown] and the download proceeds exactly as it would have. A
// diagnostic must never become a new way for a working download to fail.

import 'package:dio/dio.dart';

/// Outcome of a preflight probe.
enum HfAccess {
  /// The file is fetchable with the credentials supplied.
  ok,

  /// HuggingFace answered `X-Error-Code: GatedRepo` — the repo is gated and we
  /// are not on its authorized list.
  ///
  /// This says the GATE is what blocked us. It does NOT say whether the token
  /// or the un-accepted licence is at fault, and the HTTP status cannot settle
  /// that either: probing
  /// `litert-community/embeddinggemma-300m/resolve/main/…tflite` on 2026-07-30
  /// returned a byte-identical `401 + GatedRepo` for no token AND for a
  /// garbage token. Resolving it needs a second, independent question — "is
  /// this token valid at all?" — which is what `hf_token_check.dart` asks.
  gated,

  /// Credentials were rejected and HuggingFace did NOT blame the gate, so the
  /// token itself is the problem (revoked, mistyped, wrong host).
  unauthorized,

  /// HTTP 404 — the URL itself is wrong/moved. Not a user problem.
  notFound,

  /// No usable answer. Callers MUST treat this as "go ahead and download".
  unknown,
}

/// Seam so the managers stay unit-testable without a network.
abstract class HuggingFaceAccess {
  Future<HfAccess> check(String url, {String? token});
}

class DioHuggingFaceAccess implements HuggingFaceAccess {
  final Dio _dio;

  /// Probe timeouts are deliberately tight. This runs in front of a download
  /// the user is waiting on, and a slow answer is worth less than just starting
  /// the download — a timeout lands on [HfAccess.unknown], which proceeds.
  static const _timeout = Duration(seconds: 10);

  DioHuggingFaceAccess({Dio? dio})
      : _dio = dio ??
            // connectTimeout is a BaseOptions-only knob in dio 5, so it has to
            // be set here rather than per-request below — without it an
            // unreachable host hangs past both other timeouts.
            Dio(BaseOptions(connectTimeout: _timeout));

  @override
  Future<HfAccess> check(String url, {String? token}) async {
    try {
      final response = await _dio.head<void>(
        url,
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          // huggingface.co answers the auth question itself and only THEN
          // 302s to the CDN that serves the bytes. Not following the redirect
          // keeps the probe to a single request against the host whose answer
          // we actually care about, and avoids CDN edges that handle HEAD
          // inconsistently.
          followRedirects: false,
          validateStatus: (_) => true,
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
        ),
      );

      final status = response.statusCode ?? 0;
      // A redirect IS the success signal here: it means auth passed and
      // HuggingFace is handing us off to the CDN.
      if (status >= 200 && status < 400) return HfAccess.ok;

      // Trust HuggingFace's own diagnosis over the status code. It sets
      // `X-Error-Code: GatedRepo` on BOTH 401 and 403 for a gated repo (and
      // exposes the header through CORS precisely so clients read it), so
      // branching on 401-vs-403 — as this used to — mislabels a licence
      // problem as a bad token. Checked before the status switch for exactly
      // that reason.
      if (_errorCode(response) == 'gatedrepo') return HfAccess.gated;

      return switch (status) {
        401 || 403 => HfAccess.unauthorized,
        404 => HfAccess.notFound,
        _ => HfAccess.unknown,
      };
    } on DioException {
      return HfAccess.unknown; // offline, timeout, TLS, proxy — let it proceed
    } catch (_) {
      return HfAccess.unknown;
    }
  }

  /// HuggingFace's machine-readable failure reason, lowercased, or null.
  ///
  /// Dio lowercases header NAMES but not values, and the documented spelling
  /// is `GatedRepo`, so the value is normalised here rather than at each
  /// comparison.
  static String? _errorCode(Response<void> response) =>
      response.headers.value('x-error-code')?.trim().toLowerCase();
}
