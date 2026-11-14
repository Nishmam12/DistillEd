import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/data/providers/openai_compatible_provider.dart';
import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/tools/tool.dart';
import 'package:margo/features/ai/domain/tools/tool_generation_event.dart';

const _key = 'sk-test-123';
const _base = 'https://openrouter.ai/api/v1';

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

/// Swaps dio's real HTTP transport for a canned response or error.
class _FakeAdapter implements HttpClientAdapter {
  final String body;
  final int status;
  final String contentType;
  final DioException? throwsError;
  RequestOptions? lastOptions;

  _FakeAdapter({
    this.body = '',
    this.status = 200,
    this.contentType = 'text/event-stream',
    this.throwsError,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    if (throwsError != null) throw throwsError!;
    return ResponseBody.fromString(body, status, headers: {
      'content-type': [contentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Answers each request by the ending of its path, so one call can get a
/// different reply per endpoint.
class _ByPathAdapter implements HttpClientAdapter {
  _ByPathAdapter(this.replies);

  final Map<String, ({int status, String body})> replies;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    final end =
        replies.keys.firstWhere((k) => options.uri.path.endsWith(k));
    final reply = replies[end]!;
    return ResponseBody.fromString(reply.body, reply.status, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Sends one line of text, then the connection drops mid-reply.
class _DroppingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final chunks = Stream<Uint8List>.multi((c) {
      c.add(Uint8List.fromList(
          utf8.encode('data: ${jsonEncode(_text('partial'))}\n\n')));
      c.addError(const HttpException('Connection closed while receiving data'));
      c.close();
    });
    return ResponseBody(chunks, 200, headers: {
      'content-type': ['text/event-stream'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_FakeAdapter a) =>
    Dio(BaseOptions(baseUrl: 'http://elsewhere.invalid'))..httpClientAdapter = a;

OpenAiCompatibleProvider _providerWith(
  _FakeAdapter adapter, {
  String model = 'gpt-test',
  int? contextWindowTokens,
  bool Function()? isCloudAllowed,
}) =>
    OpenAiCompatibleProvider(
      baseUrl: '$_base/',
      apiKey: _key,
      model: model,
      presetId: 'openrouter',
      contextWindowTokens: contextWindowTokens,
      isCloudAllowed: isCloudAllowed,
      dio: _dio(adapter),
    );

String _sse(List<Object> chunks) =>
    chunks.map((c) => 'data: ${c is String ? c : jsonEncode(c)}\n\n').join();

Map<String, Object> _text(String t) => {
      'choices': [
        {
          'delta': {'content': t},
        },
      ],
    };

Map<String, Object> _tool(Map<String, Object> call, {String? finish}) => {
      'choices': [
        {
          'delta': {
            'tool_calls': [call],
          },
          'finish_reason': ?finish,
        },
      ],
    };

DioException _connError() => DioException(
      requestOptions: RequestOptions(
          path: '$_base/chat/completions',
          headers: {'Authorization': 'Bearer $_key'}),
      type: DioExceptionType.connectionError,
    );

Map _body(_FakeAdapter a) => a.lastOptions!.data as Map;
List _messages(_FakeAdapter a) => _body(a)['messages'] as List;

Future<Object> _errorOf(Future<Object?> f) async {
  try {
    await f;
  } catch (e) {
    return e;
  }
  fail('expected an error');
}

void main() {
  test('sends nothing while cloud is not allowed', () async {
    final adapter = _FakeAdapter(body: _sse([_text('x')]));
    final provider = _providerWith(adapter, isCloudAllowed: () => false);

    await expectLater(provider.generate(prompt: 'hi').toList(),
        throwsA(isA<AiUnavailableException>()));
    await expectLater(
        provider.generateWithTools(prompt: 'hi', tools: const []).toList(),
        throwsA(isA<AiUnavailableException>()));
    await expectLater(provider.transcribeImage(Uint8List(1), prompt: 'p'),
        throwsA(isA<AiUnavailableException>()));
    expect(adapter.lastOptions, isNull);
  });

  group('generate', () {
    test('yields each content delta in order', () async {
      final adapter = _FakeAdapter(
          body: _sse([_text('Hello'), _text(' world'), '[DONE]']));
      expect(await _providerWith(adapter).generate(prompt: 'hi').toList(),
          ['Hello', ' world']);
    });

    test('[DONE] ends the stream; comments and blank lines are ignored',
        () async {
      final adapter = _FakeAdapter(
        body: ': OPENROUTER PROCESSING\n\n'
            '\n'
            'data:${jsonEncode(_text('a'))}\n'
            'data: [DONE]\n\n'
            'data: ${jsonEncode(_text('after'))}\n\n',
      );
      expect(await _providerWith(adapter).generate(prompt: 'hi').toList(),
          ['a']);
    });

    test('a chunk with no choices is ignored', () async {
      final adapter = _FakeAdapter(body: _sse([
        {'choices': []},
        {'id': 'x'},
        _text('ok'),
      ]));
      expect(await _providerWith(adapter).generate(prompt: 'hi').toList(),
          ['ok']);
    });

    test('sends the bearer header to the absolute URL, with the body',
        () async {
      final adapter = _FakeAdapter(body: _sse([_text('ok')]));
      await _providerWith(adapter)
          .generate(prompt: 'hi', systemPrompt: 'be terse')
          .toList();

      final sent = adapter.lastOptions!;
      expect(sent.uri.toString(), '$_base/chat/completions');
      expect(sent.headers['Authorization'], 'Bearer sk-test-123');
      final body = _body(adapter);
      expect(body['model'], 'gpt-test');
      expect(body['stream'], true);
      expect(body['temperature'], 0.7);
      expect(body.containsKey('max_tokens'), isFalse);
      expect(body.containsKey('tools'), isFalse);
      expect(body.containsKey('tool_choice'), isFalse);
      expect(_messages(adapter), [
        {'role': 'system', 'content': 'be terse'},
        {'role': 'user', 'content': 'hi'},
      ]);
    });

    test('options set temperature and max_tokens', () async {
      final adapter = _FakeAdapter(body: _sse([_text('ok')]));
      await _providerWith(adapter)
          .generate(
              prompt: 'hi',
              options: const AiGenerationOptions(temperature: 0.2, maxTokens: 50))
          .toList();
      expect(_body(adapter)['temperature'], 0.2);
      expect(_body(adapter)['max_tokens'], 50);
    });

    test('empty system prompt sends no system message; history is role+content',
        () async {
      final adapter = _FakeAdapter(body: _sse([_text('ok')]));
      await _providerWith(adapter).generate(prompt: 'q', systemPrompt: '', history: [
        const AiMessage.user('earlier'),
        const AiMessage(
            role: AiRole.tool, content: '4', toolCallId: 'call_1'),
      ]).toList();
      expect(_messages(adapter), [
        {'role': 'user', 'content': 'earlier'},
        {'role': 'tool', 'content': '4'},
        {'role': 'user', 'content': 'q'},
      ]);
    });

    test('preserves partial output then throws on an object error event',
        () async {
      final adapter = _FakeAdapter(body: _sse([
        _text('partial'),
        {
          'error': {'message': 'upstream overloaded', 'code': 502},
        },
      ]));
      final received = <String>[];
      final error = await _errorOf(_providerWith(adapter)
          .generate(prompt: 'hi')
          .listen(received.add, onError: (Object e) => throw e)
          .asFuture<void>());
      expect(received, ['partial']);
      expect(error, isA<AiGenerationException>());
      expect((error as AiGenerationException).message,
          'The AI provider stopped the reply: upstream overloaded');
    });

    test('an error event without a message reads generically', () async {
      final adapter = _FakeAdapter(body: _sse([
        {
          'error': {'code': 500},
        },
      ]));
      await expectLater(
          _providerWith(adapter).generate(prompt: 'hi').toList(),
          throwsA(isA<AiGenerationException>().having((e) => e.message,
              'message', 'The AI provider stopped the reply.')));
    });

    test('invalid JSON is a malformed response', () async {
      final adapter = _FakeAdapter(body: 'data: {not json\n\n');
      await expectLater(
          _providerWith(adapter).generate(prompt: 'hi').toList(),
          throwsA(isA<AiGenerationException>().having((e) => e.message,
              'message', 'Malformed response from the AI provider.')));
    });

    test('a non-object payload is a malformed response', () async {
      final adapter = _FakeAdapter(body: 'data: [1, 2]\n\n');
      await expectLater(
          _providerWith(adapter).generate(prompt: 'hi').toList(),
          throwsA(isA<AiGenerationException>().having((e) => e.message,
              'message', 'Malformed response from the AI provider.')));
    });
  });

  group('error mapping', () {
    Future<AiException> errorFor(_FakeAdapter adapter,
        {bool tools = false}) async {
      final provider = _providerWith(adapter);
      final e = await _errorOf(tools
          ? provider
              .generateWithTools(prompt: 'hi', tools: [_FakeTool()]).toList()
          : provider.generate(prompt: 'hi').toList());
      expect(e, isA<AiException>());
      final ai = e as AiException;
      expect(ai.cause, isNot(isA<DioException>()));
      expect(ai.toString(), isNot(contains(_key)));
      expect(ai.message, isNot(contains(_key)));
      return ai;
    }

    _FakeAdapter status(int s, [String body = '{"error":"x"}']) =>
        _FakeAdapter(status: s, body: body, contentType: 'application/json');

    test('connection error is unreachable', () async {
      final e = await errorFor(_FakeAdapter(throwsError: _connError()));
      expect(e, isA<AiUnavailableException>());
      expect(e.message, 'AI provider unreachable');
      expect(e.cause, 'connectionError');
    });

    test('401 and 403 are a rejected key', () async {
      for (final s in [401, 403]) {
        final e = await errorFor(status(s));
        expect(e, isA<AiUnavailableException>());
        expect(e.message,
            'Your AI API key was rejected. Check it in Settings.');
        expect(e.cause, 'badResponse HTTP $s');
      }
    });

    test('402 is out of credit', () async {
      final e = await errorFor(status(402));
      expect(e, isA<AiUnavailableException>());
      expect(e.message, 'Your AI provider account is out of credit.');
    });

    test('429 is rate limiting', () async {
      final e = await errorFor(status(429));
      expect(e, isA<AiUnavailableException>());
      expect(e.message,
          'Your AI provider is rate-limiting you. Try again shortly.');
    });

    test('404 is an unknown model', () async {
      final e = await errorFor(status(404));
      expect(e, isA<AiGenerationException>());
      expect(e.message, "The model 'gpt-test' was not found at this provider.");
    });

    test('404 mentioning tool use on a tool call is tools-unsupported',
        () async {
      final e = await errorFor(
          status(404, '{"error":{"message":"No endpoints support Tool Use"}}'),
          tools: true);
      expect(e, isA<AiGenerationException>());
      expect(e.message,
          "The model 'gpt-test' does not support tools, so Research cannot run.");
    });

    test('400 mentioning tools on plain generate is a plain failure',
        () async {
      final e = await errorFor(status(400, 'tools are not supported'));
      expect(e.message, 'AI provider request failed (HTTP 400).');
    });

    test('500 shows a short line, never the Dio essay', () async {
      final e = await errorFor(status(500));
      expect(e, isA<AiGenerationException>());
      expect(e.message, 'AI provider request failed (HTTP 500).');
    });
  });

  group('capabilities', () {
    test('id, name, default window, non-local', () {
      final c = _providerWith(_FakeAdapter()).capabilities;
      expect(c.modelId, 'cloud-openrouter-gpt-test');
      expect(c.displayName, 'gpt-test');
      expect(c.contextWindowTokens, 32000);
      expect(c.isLocal, isFalse);
    });

    test('a positive override is honoured, zero is not', () {
      expect(
          _providerWith(_FakeAdapter(), contextWindowTokens: 128000)
              .capabilities
              .contextWindowTokens,
          128000);
      expect(
          _providerWith(_FakeAdapter(), contextWindowTokens: 0)
              .capabilities
              .contextWindowTokens,
          32000);
    });
  });

  group('generateWithTools', () {
    test('yields text then one call assembled from fragments', () async {
      final adapter = _FakeAdapter(body: _sse([
        _text('Let me check. '),
        _tool({
          'index': 0,
          'id': 'call_1',
          'type': 'function',
          'function': {'name': 'calculator', 'arguments': ''},
        }),
        _tool({
          'index': 0,
          'function': {'arguments': '{"expr'},
        }),
        _tool({
          'index': 0,
          'function': {'arguments': 'ession": '},
        }),
        _tool({
          'index': 0,
          'function': {'arguments': '"2+2"}'},
        }, finish: 'tool_calls'),
        '[DONE]',
      ]));
      final events = await _providerWith(adapter)
          .generateWithTools(prompt: 'what is 2+2', tools: [_FakeTool()])
          .toList();

      expect(events, hasLength(2));
      expect((events[0] as ToolTextChunk).text, 'Let me check. ');
      final call = events[1] as ToolCallRequested;
      expect(call.callId, 'call_1');
      expect(call.name, 'calculator');
      expect(call.arguments, {'expression': '2+2'});
    });

    test('two indices give two calls in first-seen order', () async {
      final adapter = _FakeAdapter(body: _sse([
        _tool({
          'index': 1,
          'id': 'b',
          'function': {'name': 'second', 'arguments': '{}'},
        }),
        _tool({
          'index': 0,
          'id': 'a',
          'function': {'name': 'first', 'arguments': '{"x":1}'},
        }),
      ]));
      final events = await _providerWith(adapter)
          .generateWithTools(prompt: 'x', tools: [_FakeTool()])
          .toList();
      expect(events.cast<ToolCallRequested>().map((c) => c.callId), ['b', 'a']);
      expect((events[1] as ToolCallRequested).arguments, {'x': 1});
    });

    test('empty arguments decode as {}', () async {
      final adapter = _FakeAdapter(body: _sse([
        _tool({
          'index': 0,
          'id': 'c',
          'function': {'name': 'calculator'},
        }),
      ]));
      final events = await _providerWith(adapter)
          .generateWithTools(prompt: 'x', tools: [_FakeTool()])
          .toList();
      expect((events.single as ToolCallRequested).arguments, isEmpty);
    });

    Future<void> expectToolError(List<Object> chunks, String message) =>
        expectLater(
          _providerWith(_FakeAdapter(body: _sse(chunks)))
              .generateWithTools(prompt: 'x', tools: [_FakeTool()])
              .toList(),
          throwsA(isA<AiGenerationException>()
              .having((e) => e.message, 'message', message)),
        );

    test('a call with no id is incomplete', () => expectToolError([
          _tool({
            'index': 0,
            'function': {'name': 'calculator', 'arguments': '{}'},
          }),
        ], 'Model produced an incomplete tool call.'));

    test('a call with no name is incomplete', () => expectToolError([
          _tool({
            'index': 0,
            'id': 'c',
            'function': {'arguments': '{}'},
          }),
        ], 'Model produced an incomplete tool call.'));

    test('bad JSON arguments are malformed', () => expectToolError([
          _tool({
            'index': 0,
            'id': 'c',
            'function': {'name': 'calculator', 'arguments': '{"a":'},
          }, finish: 'tool_calls'),
        ], 'Model produced a malformed tool call.'));

    test('non-object arguments are malformed', () => expectToolError([
          _tool({
            'index': 0,
            'id': 'c',
            'function': {'name': 'calculator', 'arguments': '[1]'},
          }),
        ], 'Model produced a malformed tool call.'));

    test('bad JSON after a length stop reads as cut off', () => expectToolError([
          _tool({
            'index': 0,
            'id': 'c',
            'function': {'name': 'calculator', 'arguments': '{"a":'},
          }, finish: 'length'),
        ], 'The reply was cut off before the tool call finished.'));

    test('arguments over 8000 code points are refused', () => expectToolError([
          _tool({
            'index': 0,
            'id': 'c',
            'function': {'name': 'calculator', 'arguments': '"${'é' * 4000}'},
          }),
          _tool({
            'index': 0,
            'function': {'arguments': '${'é' * 4000}"'},
          }),
        ], 'Tool call arguments are too large.'));

    test('sends tools and tool_choice in function-schema shape', () async {
      final adapter = _FakeAdapter(body: _sse([_text('ok')]));
      await _providerWith(adapter)
          .generateWithTools(prompt: 'hi', tools: [_FakeTool()]).toList();

      final body = _body(adapter);
      final tools = body['tools'] as List;
      expect(tools, hasLength(1));
      expect((tools.first as Map)['type'], 'function');
      expect(((tools.first as Map)['function'] as Map)['name'], 'calculator');
      expect(body['tool_choice'], 'auto');
    });

    test('no tools sends no tools or tool_choice', () async {
      final adapter = _FakeAdapter(body: _sse([_text('ok')]));
      await _providerWith(adapter)
          .generateWithTools(prompt: 'hi', tools: const []).toList();
      expect(_body(adapter).containsKey('tools'), isFalse);
      expect(_body(adapter).containsKey('tool_choice'), isFalse);
    });

    test('tool fields are gated by role; an empty prompt adds no user turn',
        () async {
      final adapter = _FakeAdapter(body: _sse([_text('ok')]));
      const calls = [
        {
          'id': 'call_1',
          'type': 'function',
          'function': {'name': 'calculator', 'arguments': '{"expression":"2+2"}'},
        },
      ];
      await _providerWith(adapter).generateWithTools(
        prompt: '',
        tools: [_FakeTool()],
        history: [
          // Stray fields on the wrong role must not be sent.
          const AiMessage(
              role: AiRole.user,
              content: 'what is 2+2',
              toolCallId: 'stray',
              toolCalls: calls),
          const AiMessage(role: AiRole.assistant, content: '', toolCalls: calls),
          const AiMessage(
              role: AiRole.tool, content: '4', toolCallId: 'call_1'),
        ],
      ).toList();

      final messages = _messages(adapter);
      expect(messages, hasLength(3));
      expect(messages[0], {'role': 'user', 'content': 'what is 2+2'});
      expect(messages[1]['tool_calls'], calls);
      expect((messages[1] as Map).containsKey('tool_call_id'), isFalse);
      expect(messages[2], {
        'role': 'tool',
        'content': '4',
        'tool_call_id': 'call_1',
      });
    });

    test('a mid-stream error keeps earlier events', () async {
      final adapter = _FakeAdapter(body: _sse([
        _text('partial'),
        {'error': 'boom'},
      ]));
      final received = <ToolGenerationEvent>[];
      final error = await _errorOf(_providerWith(adapter)
          .generateWithTools(prompt: 'hi', tools: [_FakeTool()])
          .listen(received.add, onError: (Object e) => throw e)
          .asFuture<void>());
      expect(error, isA<AiGenerationException>());
      expect((error as AiGenerationException).message,
          'The AI provider stopped the reply: boom');
      expect((received.single as ToolTextChunk).text, 'partial');
    });
  });

  group('transcribeImage', () {
    _FakeAdapter json(Object body) => _FakeAdapter(
        body: jsonEncode(body), contentType: 'application/json');

    test('sends one non-streamed image message and returns the text',
        () async {
      final adapter = json({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': '{"kind":"chart"}'},
          },
        ],
      });
      final bytes = Uint8List.fromList([1, 2, 3]);
      final text = await _providerWith(adapter)
          .transcribeImage(bytes, prompt: 'Describe', maxOutputTokens: 300);

      expect(text, '{"kind":"chart"}');
      final sent = adapter.lastOptions!;
      expect(sent.uri.toString(), '$_base/chat/completions');
      expect(sent.headers['Authorization'], 'Bearer sk-test-123');
      final body = _body(adapter);
      expect(body['stream'], false);
      expect(body['model'], 'gpt-test');
      expect(body['temperature'], 0.0);
      expect(body['max_tokens'], 300);
      final content =
          ((body['messages'] as List).single as Map)['content'] as List;
      expect(content[0], {
        'type': 'image_url',
        'image_url': {'url': 'data:image/png;base64,${base64Encode(bytes)}'},
      });
      expect(content[1], {'type': 'text', 'text': 'Describe'});
    });

    test('null content throws no text', () async {
      final adapter = json({
        'choices': [
          {
            'message': {'content': null},
          },
        ],
      });
      await expectLater(
          _providerWith(adapter).transcribeImage(Uint8List(1), prompt: 'p'),
          throwsA(isA<AiGenerationException>().having((e) => e.message,
              'message', 'AI provider returned no text for the image.')));
    });

    test('an error body throws no text', () async {
      final adapter = json({
        'error': {'message': 'nope'},
      });
      await expectLater(
          _providerWith(adapter).transcribeImage(Uint8List(1), prompt: 'p'),
          throwsA(isA<AiGenerationException>().having((e) => e.message,
              'message', 'AI provider returned no text for the image.')));
    });

    test('a picture over 8 MiB sends nothing', () async {
      final adapter = json({});
      await expectLater(
          _providerWith(adapter).transcribeImage(
              Uint8List(OpenAiCompatibleProvider.maxImageBytes + 1),
              prompt: 'p'),
          throwsA(isA<AiGenerationException>().having((e) => e.message,
              'message', 'The picture is too large to send to the cloud.')));
      expect(adapter.lastOptions, isNull);
    });

    test('a rejected key maps like the chat path', () async {
      final adapter = _FakeAdapter(
          status: 401, body: '{}', contentType: 'application/json');
      final e = await _errorOf(
          _providerWith(adapter).transcribeImage(Uint8List(1), prompt: 'p'));
      expect(e, isA<AiUnavailableException>());
      expect(e.toString(), isNot(contains(_key)));
    });
  });

  group('stream failures and key handling', () {
    test('a dropped connection after some text is an AiException, keeping the text',
        () async {
      final provider = OpenAiCompatibleProvider(
        baseUrl: _base,
        apiKey: _key,
        model: 'm',
        presetId: 'openrouter',
        dio: Dio()..httpClientAdapter = _DroppingAdapter(),
      );
      final received = <String>[];
      await expectLater(
        provider.generate(prompt: 'hi').listen(received.add).asFuture<void>(),
        throwsA(isA<AiUnavailableException>()),
      );
      expect(received, ['partial']);
    });

    test('a 200 reply with no SSE lines is malformed, not an empty reply',
        () async {
      final provider = _providerWith(_FakeAdapter(
        body: '<html>Please sign in to the hotel wifi</html>',
        contentType: 'text/html',
      ));
      await expectLater(
        provider.generate(prompt: 'hi').toList(),
        throwsA(isA<AiGenerationException>().having((e) => e.message,
            'message', 'Malformed response from the AI provider.')),
      );
    });

    test('a provider that echoes the key back does not leak it', () async {
      final provider = _providerWith(_FakeAdapter(body: _sse([
        {
          'error': {'message': 'Invalid API key: $_key'},
        },
      ])));
      final error = await _errorOf(provider.generate(prompt: 'hi').toList());
      expect(error, isA<AiGenerationException>());
      expect((error as AiException).message, isNot(contains(_key)));
      expect(error.toString(), isNot(contains(_key)));
    });
  });

  group('listModels', () {
    Future<List<CloudModel>> list(_FakeAdapter a) =>
        OpenAiCompatibleProvider.listModels(
            baseUrl: '$_base/', apiKey: _key, dio: _dio(a));

    _FakeAdapter json(Object body, {int status = 200}) => _FakeAdapter(
        body: jsonEncode(body),
        status: status,
        contentType: 'application/json');

    test('OpenRouter checks the key on /key, since /models answers anyone',
        () async {
      final adapter = _ByPathAdapter({
        '/key': (status: 401, body: '{"error":{"message":"Invalid key"}}'),
        '/models': (status: 200, body: '{"data":[{"id":"x"}]}'),
      });
      await expectLater(
        OpenAiCompatibleProvider.listModels(
            baseUrl: _base, apiKey: _key, dio: Dio()..httpClientAdapter = adapter),
        throwsA(isA<CloudModelListException>()
            .having((e) => e.keyRejected, 'keyRejected', isTrue)),
      );
      expect(adapter.paths, ['/api/v1/key'], reason: 'stops at the key check');
    });

    test('reads the context window under the names Groq and Mistral use',
        () async {
      final models = await list(json({
        'data': [
          {'id': 'groq-model', 'context_window': 8192},
          {'id': 'mistral-model', 'max_context_length': 32768},
        ],
      }));
      expect({for (final m in models) m.id: m.contextLength},
          {'groq-model': 8192, 'mistral-model': 32768});
    });

    test('reads a data list with context lengths, sorted and deduped',
        () async {
      final adapter = json({
        'data': [
          {'id': 'z-model', 'context_length': 128000},
          {'id': 'a-model', 'context_length': 0},
          {'id': 'z-model', 'context_length': 1},
          {'name': 'no id'},
          'junk',
        ],
      });
      final models = await list(adapter);
      expect(models.map((m) => m.id), ['a-model', 'z-model']);
      expect(models[0].contextLength, isNull);
      expect(models[1].contextLength, 128000);
      expect(adapter.lastOptions!.uri.toString(), '$_base/models');
      expect(adapter.lastOptions!.headers['Authorization'], 'Bearer sk-test-123');
    });

    test('strips the Gemini models/ prefix', () async {
      final models = await list(json({
        'data': [
          {'id': 'models/gemini-2.5-flash'},
        ],
      }));
      expect(models.single.id, 'gemini-2.5-flash');
    });

    test('reads a bare list (Together)', () async {
      final models = await list(json([
        {'id': 'meta/llama', 'context_length': 8192},
      ]));
      expect(models.single.id, 'meta/llama');
      expect(models.single.contextLength, 8192);
    });

    Future<CloudModelListException> failure(_FakeAdapter a) async {
      final e = await _errorOf(list(a));
      expect(e, isA<CloudModelListException>());
      expect(e.toString(), isNot(contains(_key)));
      return e as CloudModelListException;
    }

    test('401 is a rejected key', () async {
      final e = await failure(json({}, status: 401));
      expect(e.keyRejected, isTrue);
      expect(e.message, 'Your AI API key was rejected.');
    });

    test('404 is not a rejected key', () async {
      final e = await failure(json({}, status: 404));
      expect(e.keyRejected, isFalse);
      expect(e.message, 'Could not load the model list.');
    });

    test('a connection error is not a rejected key', () async {
      final e = await failure(_FakeAdapter(throwsError: _connError()));
      expect(e.keyRejected, isFalse);
    });

    test('an unparseable body fails', () async {
      final e = await failure(json({'object': 'list'}));
      expect(e.keyRejected, isFalse);
    });
  });
}
