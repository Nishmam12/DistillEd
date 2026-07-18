import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/providers/cloud_gateway_provider.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';

/// Swaps dio's real HTTP transport for a canned response/error — the same
/// "hand-written fake at the boundary" pattern used elsewhere in this suite,
/// applied to the network layer instead of a Dart interface.
class _FakeAdapter implements HttpClientAdapter {
  final String? sseBody;
  final DioException? throwsError;
  RequestOptions? lastOptions;

  _FakeAdapter({this.sseBody, this.throwsError});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    if (throwsError != null) throw throwsError!;
    return ResponseBody.fromString(
      sseBody!,
      200,
      headers: {
        'content-type': ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

CloudGatewayProvider _providerWith(_FakeAdapter adapter, {String tier = 'cloud-mid'}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://fake-gateway'))
    ..httpClientAdapter = adapter;
  return CloudGatewayProvider(baseUrl: 'http://fake-gateway', modelTier: tier, dio: dio);
}

void main() {
  group('CloudGatewayProvider.generate', () {
    test('yields each SSE text chunk in order', () async {
      final adapter = _FakeAdapter(
        sseBody: 'data: {"text": "Hello"}\n\ndata: {"text": " world"}\n\n',
      );
      final provider = _providerWith(adapter);
      final chunks = await provider.generate(prompt: 'hi').toList();
      expect(chunks, ['Hello', ' world']);
    });

    test('sends the device key header and request body', () async {
      final adapter = _FakeAdapter(sseBody: 'data: {"text": "ok"}\n\n');
      final provider = _providerWith(adapter, tier: 'cloud-frontier');
      await provider
          .generate(prompt: 'hi', systemPrompt: 'be terse')
          .toList();

      final sent = adapter.lastOptions!;
      expect(sent.headers['X-Device-Key'], isNotNull);
      expect(sent.data, isA<Map>());
      final body = sent.data as Map;
      expect(body['model_tier'], 'cloud-frontier');
      expect(body['prompt'], 'hi');
      expect(body['system_prompt'], 'be terse');
      expect(body['stream'], true);
    });

    test('preserves partial output then throws on a mid-stream error event',
        () async {
      final adapter = _FakeAdapter(
        sseBody: 'data: {"text": "partial"}\n\ndata: {"error": "boom"}\n\n',
      );
      final provider = _providerWith(adapter);

      final received = <String>[];
      await expectLater(
        provider.generate(prompt: 'hi').listen(
              received.add,
              onError: (e) => throw e,
            ).asFuture<void>(),
        throwsA(isA<AiGenerationException>()),
      );
      expect(received, ['partial']);
    });

    test('maps a connection error to AiUnavailableException', () async {
      final adapter = _FakeAdapter(
        throwsError: DioException(
          requestOptions: RequestOptions(path: '/v1/generate'),
          type: DioExceptionType.connectionError,
        ),
      );
      final provider = _providerWith(adapter);

      expect(
        provider.generate(prompt: 'hi').toList(),
        throwsA(isA<AiUnavailableException>()),
      );
    });

    test('maps a 429 to AiUnavailableException (usage cap)', () async {
      final adapter = _FakeAdapter(
        throwsError: DioException(
          requestOptions: RequestOptions(path: '/v1/generate'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/generate'),
            statusCode: 429,
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      final provider = _providerWith(adapter);

      expect(
        provider.generate(prompt: 'hi').toList(),
        throwsA(isA<AiUnavailableException>()),
      );
    });
  });

  group('CloudGatewayProvider capabilities/embed', () {
    test('capabilities report non-local with a tier-specific id', () {
      final provider = _providerWith(_FakeAdapter(sseBody: ''), tier: 'cloud-frontier');
      expect(provider.capabilities.isLocal, isFalse);
      expect(provider.capabilities.modelId, contains('cloud-frontier'));
      expect(provider.capabilities.supportsEmbeddings, isFalse);
    });

    test('embed throws AiUnsupportedOperationException — no /v1/embed yet',
        () async {
      final provider = _providerWith(_FakeAdapter(sseBody: ''));
      expect(
        provider.embed('anything'),
        throwsA(isA<AiUnsupportedOperationException>()),
      );
    });
  });
}
