// Pins the one decision this probe exists to make: WHY HuggingFace said no.
//
// The status code cannot answer it. Probing the real gated EmbeddingGemma file
// on 2026-07-30 returned a byte-identical `401 + X-Error-Code: GatedRepo` with
// no token and with a garbage token, so a mapping built on 401-vs-403 — which
// is what this file used to do — reports a licence problem as a bad token.
// `X-Error-Code` is the signal that survives.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/llm/hf_access_check.dart';

/// Replays a canned status + headers without a network.
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.statusCode, {this.headers = const {}, this.throws});

  final int statusCode;
  final Map<String, List<String>> headers;
  final Object? throws;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (throws != null) throw throws!;
    return ResponseBody.fromString('', statusCode, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

DioHuggingFaceAccess _probe(int status,
    {Map<String, List<String>> headers = const {}, Object? throws}) {
  final dio = Dio()
    ..httpClientAdapter = _CannedAdapter(status, headers: headers,
        throws: throws);
  return DioHuggingFaceAccess(dio: dio);
}

const _gatedHeader = {
  'x-error-code': ['GatedRepo']
};

void main() {
  const url = 'https://huggingface.co/owner/repo/resolve/main/model.tflite';

  test('a redirect counts as success — auth passed, CDN is next', () async {
    // HuggingFace answers the auth question itself and only THEN 302s to the
    // bytes, so the redirect IS the "yes".
    expect(await _probe(302).check(url, token: 'hf_x'), HfAccess.ok);
  });

  test('200 is success', () async {
    expect(await _probe(200).check(url, token: 'hf_x'), HfAccess.ok);
  });

  group('X-Error-Code outranks the status code', () {
    test('401 + GatedRepo is a GATE refusal, not a bad token', () async {
      // The exact shape the live API returns. Reading this as `unauthorized`
      // is what produced "HuggingFace rejected your token" for users whose
      // token was perfectly fine.
      expect(await _probe(401, headers: _gatedHeader).check(url, token: 'hf_x'),
          HfAccess.gated);
    });

    test('403 + GatedRepo is the same refusal', () async {
      // HuggingFace is not consistent about which status a gated repo gets,
      // which is precisely why the status must not be the discriminator.
      expect(await _probe(403, headers: _gatedHeader).check(url, token: 'hf_x'),
          HfAccess.gated);
    });

    test('the header value is matched case-insensitively', () async {
      expect(
          await _probe(401, headers: {
            'x-error-code': ['gatedrepo']
          }).check(url, token: 'hf_x'),
          HfAccess.gated);
    });
  });

  group('without that header the credential is what is in doubt', () {
    test('a bare 401 is a token problem', () async {
      expect(await _probe(401).check(url, token: 'hf_x'),
          HfAccess.unauthorized);
    });

    test('a bare 403 is a token problem too', () async {
      expect(await _probe(403).check(url, token: 'hf_x'),
          HfAccess.unauthorized);
    });

    test('an unrelated error code does not become a gate refusal', () async {
      expect(
          await _probe(401, headers: {
            'x-error-code': ['InvalidCredentials']
          }).check(url, token: 'hf_x'),
          HfAccess.unauthorized);
    });
  });

  test('404 means the URL moved, which is our bug not the user\'s', () async {
    expect(await _probe(404).check(url, token: 'hf_x'), HfAccess.notFound);
  });

  group('fail-open', () {
    // The governing rule: a diagnostic may VETO a download on a definitive
    // answer, and must never become a new way for a working download to fail.
    test('an unexpected status proceeds', () async {
      expect(await _probe(500).check(url, token: 'hf_x'), HfAccess.unknown);
    });

    test('a network failure proceeds', () async {
      final probe = _probe(0,
          throws: DioException.connectionError(
              requestOptions: RequestOptions(path: ''),
              reason: 'offline'));
      expect(await probe.check(url, token: 'hf_x'), HfAccess.unknown);
    });

    test('a non-Dio throw proceeds', () async {
      expect(await _probe(0, throws: StateError('boom')).check(url),
          HfAccess.unknown);
    });
  });
}
