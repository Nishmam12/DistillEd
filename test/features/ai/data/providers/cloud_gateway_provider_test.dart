import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/providers/cloud_gateway_provider.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/tools/tool.dart';
import 'package:inkflow/features/ai/domain/tools/tool_generation_event.dart';

class _FakeTool implements Tool {
  @override
  String get name => 'calculator';
  @override
  String get description => 'Evaluates math.';
  @override
  Map<String, dynamic> get parameterSchema => const {
        'type': 'object',
        'properties': {
          'expression': {'type': 'string'},
        },
        'required': ['expression'],
      };
  @override
  Future<ToolExecutionResult> execute(Map<String, dynamic> arguments) async =>
      throw UnimplementedError();
}

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

  group('CloudGatewayProvider.generateWithTools (Loop 3.4)', () {
    test('yields text chunks then a tool_call event', () async {
      final adapter = _FakeAdapter(
        sseBody: 'data: {"text": "Let me check. "}\n\n'
            'data: {"tool_call": {"call_id": "call_1", "name": "calculator", '
            '"arguments": {"expression": "2+2"}}}\n\n',
      );
      final provider = _providerWith(adapter);

      final events = await provider
          .generateWithTools(prompt: 'what is 2+2', tools: [_FakeTool()])
          .toList();

      expect(events, hasLength(2));
      expect((events[0] as ToolTextChunk).text, 'Let me check. ');
      final call = events[1] as ToolCallRequested;
      expect(call.callId, 'call_1');
      expect(call.name, 'calculator');
      expect(call.arguments, {'expression': '2+2'});
    });

    test('sends the tools field mapped to OpenAI function-schema shape',
        () async {
      final adapter = _FakeAdapter(sseBody: 'data: {"text": "ok"}\n\n');
      final provider = _providerWith(adapter);

      await provider
          .generateWithTools(prompt: 'hi', tools: [_FakeTool()])
          .toList();

      final body = adapter.lastOptions!.data as Map;
      final tools = body['tools'] as List;
      expect(tools, hasLength(1));
      final fn = (tools.first as Map)['function'] as Map;
      expect(fn['name'], 'calculator');
      expect((tools.first as Map)['type'], 'function');
    });

    test('sends tool_call_id / tool_calls history fields when present',
        () async {
      final adapter = _FakeAdapter(sseBody: 'data: {"text": "ok"}\n\n');
      final provider = _providerWith(adapter);

      await provider.generateWithTools(
        prompt: '',
        tools: [_FakeTool()],
        history: [
          const AiMessage.user('what is 2+2'),
          const AiMessage(
            role: AiRole.assistant,
            content: '',
            toolCalls: [
              {
                'id': 'call_1',
                'type': 'function',
                'function': {'name': 'calculator', 'arguments': '{"expression":"2+2"}'},
              },
            ],
          ),
          const AiMessage(role: AiRole.tool, content: '4', toolCallId: 'call_1'),
        ],
      ).toList();

      final body = adapter.lastOptions!.data as Map;
      final history = body['history'] as List;
      expect(history, hasLength(3));
      expect(history[1]['tool_calls'], isNotNull);
      expect(history[2]['tool_call_id'], 'call_1');
    });

    test('a mid-stream error event still throws AiGenerationException',
        () async {
      final adapter = _FakeAdapter(
        sseBody: 'data: {"text": "partial"}\n\ndata: {"error": "boom"}\n\n',
      );
      final provider = _providerWith(adapter);

      final received = <ToolGenerationEvent>[];
      await expectLater(
        provider
            .generateWithTools(prompt: 'hi', tools: [_FakeTool()])
            .listen(received.add, onError: (e) => throw e)
            .asFuture<void>(),
        throwsA(isA<AiGenerationException>()),
      );
      expect(received, hasLength(1));
      expect((received.first as ToolTextChunk).text, 'partial');
    });
  });
}
