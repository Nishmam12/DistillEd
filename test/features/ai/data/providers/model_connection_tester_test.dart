import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/data/providers/model_connection_tester.dart';

const _key = 'sk-test-1234567890abcdef';
const _base = 'https://api.example.com/v1';

class _FakeAdapter implements HttpClientAdapter {
  final int status;
  final String body;
  final DioException? throwsError;
  final requests = <RequestOptions>[];

  _FakeAdapter(this.body, {this.status = 200, this.throwsError});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (throwsError != null) throw throwsError!;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ModelConnectionTester _tester(_FakeAdapter adapter) =>
    ModelConnectionTester(dio: Dio()..httpClientAdapter = adapter);

void main() {
  test('a good key returns the models it can use, in name order', () async {
    final adapter = _FakeAdapter(jsonEncode({
      'data': [
        {'id': 'zeta'},
        {'id': 'alpha'},
      ],
    }));

    final result =
        await _tester(adapter).listModels(baseUrl: _base, apiKey: _key);

    expect((result as ConnectionOk).modelIds, ['alpha', 'zeta']);
  });

  test('asks the models address with the key as a bearer header', () async {
    final adapter = _FakeAdapter('{"data":[]}');

    await _tester(adapter).listModels(baseUrl: '$_base/', apiKey: _key);

    final request = adapter.requests.single;
    expect(request.uri.toString(), '$_base/models');
    expect(request.method, 'GET');
    expect(request.headers['Authorization'], 'Bearer $_key');
  });

  test('a rejected key says so', () async {
    final result = await _tester(_FakeAdapter('{}', status: 401))
        .listModels(baseUrl: _base, apiKey: _key);

    expect((result as ConnectionFailed).message, contains('rejected the key'));
  });

  test('a provider with no model list says there is none to pick from',
      () async {
    final result = await _tester(_FakeAdapter('{}', status: 404))
        .listModels(baseUrl: _base, apiKey: _key);

    expect(result, isA<ConnectionNoModelList>());
  });

  test('a reply in an unknown shape is treated as no model list', () async {
    final result = await _tester(_FakeAdapter('{"hello":"world"}'))
        .listModels(baseUrl: _base, apiKey: _key);

    expect(result, isA<ConnectionNoModelList>());
  });

  test('an unreachable host names the host', () async {
    final adapter = _FakeAdapter(
      '',
      throwsError: DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      ),
    );

    final result =
        await _tester(adapter).listModels(baseUrl: _base, apiKey: _key);

    expect((result as ConnectionFailed).message, contains('api.example.com'));
  });

  test('an address that is not https is refused before anything is sent',
      () async {
    final adapter = _FakeAdapter('{"data":[]}');

    final result = await _tester(adapter)
        .listModels(baseUrl: 'http://api.example.com/v1', apiKey: _key);

    expect(result, isA<ConnectionFailed>());
    expect(adapter.requests, isEmpty);
  });

  test('a failure never repeats the key', () async {
    for (final status in [400, 401, 403, 429, 500]) {
      final result = await _tester(
        _FakeAdapter('{"error":"bad key $_key"}', status: status),
      ).listModels(baseUrl: _base, apiKey: _key);

      expect((result as ConnectionFailed).message, isNot(contains(_key)),
          reason: 'HTTP $status');
    }
  });

  group('checking one typed model', () {
    const sse = 'data: {"choices":[{"delta":{"content":"hi"}}]}\n\n'
        'data: [DONE]\n\n';

    test('a model that answers is confirmed', () async {
      final result = await _tester(_FakeAdapter(sse)).probe(
        baseUrl: _base,
        apiKey: _key,
        modelId: 'typed-model',
        label: 'My AI',
      );

      expect((result as ConnectionOk).modelIds, ['typed-model']);
    });

    test('a model the provider does not have is reported', () async {
      final result = await _tester(_FakeAdapter('{}', status: 404)).probe(
        baseUrl: _base,
        apiKey: _key,
        modelId: 'typed-model',
        label: 'My AI',
      );

      expect((result as ConnectionFailed).message, contains('typed-model'));
    });
  });
}
