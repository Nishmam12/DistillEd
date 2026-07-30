// The repo-independent second opinion that lets the app stop guessing.
//
// A gated repo refuses a missing token, a dead token, and an un-licensed token
// identically, so "is this token valid?" cannot be answered by asking about the
// repo. `/api/whoami-v2` involves no repo at all — a 200 here means the
// credential works, and any remaining refusal must be about the gate.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/llm/hf_token_check.dart';

class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.statusCode, {this.body, this.throws});

  final int statusCode;
  final Object? body;
  final Object? throws;

  RequestOptions? sawRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    sawRequest = options;
    if (throws != null) throw throws!;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(DioHuggingFaceIdentity, _CannedAdapter) _identity(int status,
    {Object? body, Object? throws}) {
  final adapter = _CannedAdapter(status, body: body, throws: throws);
  final dio = Dio()..httpClientAdapter = adapter;
  return (DioHuggingFaceIdentity(dio: dio), adapter);
}

void main() {
  test('a 200 means the token works, and reports who it belongs to', () async {
    final (identity, _) = _identity(200, body: {
      'name': 'afnan',
      'auth': {
        'accessToken': {'role': 'read', 'displayName': 'distilled'}
      }
    });

    final info = await identity.whoami('hf_good');
    expect(info.status, HfTokenStatus.valid);
    // The username is what makes the licence message credible — it proves the
    // app read the token and HuggingFace accepted it.
    expect(info.username, 'afnan');
    expect(info.role, 'read');
    expect(info.isFineGrained, isFalse);
  });

  test('a fine-grained token is flagged', () async {
    // Authenticates fine, yet still fails on gated repos unless the gated-repo
    // permission was ticked — so it needs a different instruction from either
    // "your token is dead" or "accept the licence".
    final (identity, _) = _identity(200, body: {
      'name': 'afnan',
      'auth': {
        'accessToken': {'role': 'fineGrained'}
      }
    });

    expect((await identity.whoami('hf_fg')).isFineGrained, isTrue);
  });

  test('a 200 with an unexpected body shape is still a valid token', () async {
    // The 200 already settled the verdict; losing the username costs a nicety,
    // not the diagnosis.
    final (identity, _) = _identity(200, body: {'unexpected': true});
    final info = await identity.whoami('hf_good');
    expect(info.status, HfTokenStatus.valid);
    expect(info.username, isNull);
    expect(info.role, isNull);
  });

  test('a 401 means the credential itself is bad', () async {
    final (identity, _) = _identity(401, body: {'error': 'Invalid username'});
    expect((await identity.whoami('hf_dead')).status, HfTokenStatus.invalid);
  });

  test('a 403 is also a rejected credential', () async {
    final (identity, _) = _identity(403);
    expect((await identity.whoami('hf_dead')).status, HfTokenStatus.invalid);
  });

  test('the token is sent as a bearer credential', () async {
    final (identity, adapter) = _identity(200, body: {'name': 'afnan'});
    await identity.whoami('  hf_padded  ');
    // Trimmed, because a token pasted from a browser routinely arrives with
    // whitespace and an untrimmed one would 401 for no visible reason.
    expect(adapter.sawRequest?.headers['Authorization'], 'Bearer hf_padded');
  });

  group('fail-open — a diagnostic must never invent a verdict', () {
    test('an empty token is unknown, not invalid', () async {
      final (identity, adapter) = _identity(200);
      expect((await identity.whoami('   ')).status, HfTokenStatus.unknown);
      expect(adapter.sawRequest, isNull, reason: 'no point asking');
    });

    test('being offline is unknown, not invalid', () async {
      final (identity, _) = _identity(0,
          throws: DioException.connectionError(
              requestOptions: RequestOptions(path: ''), reason: 'offline'));
      expect((await identity.whoami('hf_good')).status, HfTokenStatus.unknown);
    });

    test('a 500 is unknown', () async {
      final (identity, _) = _identity(500);
      expect((await identity.whoami('hf_good')).status, HfTokenStatus.unknown);
    });

    test('a non-Dio throw is unknown', () async {
      final (identity, _) = _identity(0, throws: StateError('boom'));
      expect((await identity.whoami('hf_good')).status, HfTokenStatus.unknown);
    });
  });
}
