import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/data/providers/openai_compatible_provider.dart';
import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/tools/tool.dart';
import 'package:margo/features/ai/domain/tools/tool_generation_event.dart';

const _key = 'sk-test-1234567890abcdef';

/// One canned reply: a status and a body.
class _Reply {
  final int status;
  final String body;
  const _Reply(this.body, {this.status = 200});
}

/// Stands in for the network. Replies are served in order; every request is
/// kept so a test can read what was actually sent.
class _FakeAdapter implements HttpClientAdapter {
  final List<_Reply> replies;
  final DioException? throwsError;
  final requests = <RequestOptions>[];

  _FakeAdapter(this.replies, {this.throwsError});

  Map<String, dynamic> body(int i) => requests[i].data as Map<String, dynamic>;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (throwsError != null) throw throwsError!;
    final reply = replies[requests.length - 1];
    return ResponseBody.fromString(
      reply.body,
      reply.status,
      headers: {
        'content-type': ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _sse(List<Object> events) =>
    '${events.map((e) => 'data: ${e is String ? e : jsonEncode(e)}').join('\n\n')}\n\n';

Map<String, dynamic> _text(String text) => {
      'choices': [
        {
          'delta': {'content': text},
        },
      ],
    };

Map<String, dynamic> _toolDelta(
  int index, {
  String? id,
  String? name,
  String? arguments,
}) =>
    {
      'choices': [
        {
          'delta': {
            'tool_calls': [
              {
                'index': index,
                'id': ?id,
                'function': {'name': ?name, 'arguments': ?arguments},
              },
            ],
          },
        },
      ],
    };

OpenAiCompatibleProvider _provider(
  _FakeAdapter adapter, {
  String baseUrl = 'https://api.example.com/v1',
  String? key = _key,
  bool cloudAllowed = true,
}) =>
    OpenAiCompatibleProvider(
      baseUrl: baseUrl,
      modelId: 'big-model',
      displayName: 'My AI · Big',
      label: 'My AI',
      contextWindowTokens: 32000,
      apiKey: () async => key,
      isCloudAllowed: () => cloudAllowed,
      dio: Dio()..httpClientAdapter = adapter,
    );

class _Calculator implements Tool {
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
      };
  @override
  Future<ToolExecutionResult> execute(Map<String, dynamic> arguments) async =>
      throw UnimplementedError();
}

void main() {
  group('a plain reply', () {
    test('arrives as the text chunks, in order, and ends at [DONE]', () async {
      final adapter = _FakeAdapter([
        _Reply(_sse([_text('Hel'), _text('lo'), '[DONE]', _text('ignored')])),
      ]);

      final chunks = await _provider(adapter).generate(prompt: 'hi').toList();

      expect(chunks, ['Hel', 'lo']);
    });

    test('keep-alive comments and blank lines are not part of it', () async {
      final adapter = _FakeAdapter([
        _Reply(': OPENROUTER PROCESSING\n\n${_sse([_text('ok'), '[DONE]'])}'),
      ]);

      expect(await _provider(adapter).generate(prompt: 'hi').join(), 'ok');
    });

    test('a data line with no space after the colon is read', () async {
      final adapter = _FakeAdapter([
        _Reply('data:${jsonEncode(_text('ok'))}\n\ndata:[DONE]\n\n'),
      ]);

      expect(await _provider(adapter).generate(prompt: 'hi').join(), 'ok');
    });

    test('a chunk with no choices, such as a usage report, is skipped',
        () async {
      final adapter = _FakeAdapter([
        _Reply(_sse([
          _text('ok'),
          {'choices': <Object>[], 'usage': {'total_tokens': 3}},
          '[DONE]',
        ])),
      ]);

      expect(await _provider(adapter).generate(prompt: 'hi').join(), 'ok');
    });

    test('a stream that ends without [DONE] keeps what arrived', () async {
      final adapter = _FakeAdapter([_Reply(_sse([_text('partial')]))]);

      expect(await _provider(adapter).generate(prompt: 'hi').join(), 'partial');
    });
  });

  group('the request', () {
    test('goes to chat/completions under the base address', () async {
      final adapter = _FakeAdapter([_Reply(_sse(['[DONE]']))]);

      await _provider(adapter).generate(prompt: 'hi').drain<void>();

      expect(
        adapter.requests.single.uri.toString(),
        'https://api.example.com/v1/chat/completions',
      );
    });

    test('a trailing slash on the base address does not double up', () async {
      final adapter = _FakeAdapter([_Reply(_sse(['[DONE]']))]);

      await _provider(adapter, baseUrl: 'https://api.example.com/v1beta/openai/')
          .generate(prompt: 'hi')
          .drain<void>();

      expect(
        adapter.requests.single.uri.toString(),
        'https://api.example.com/v1beta/openai/chat/completions',
      );
    });

    test('carries the key as a bearer header, never in the address', () async {
      final adapter = _FakeAdapter([_Reply(_sse(['[DONE]']))]);

      await _provider(adapter).generate(prompt: 'hi').drain<void>();

      final request = adapter.requests.single;
      expect(request.headers['Authorization'], 'Bearer $_key');
      expect(request.uri.toString(), isNot(contains(_key)));
    });

    test('names the model and asks for a stream', () async {
      final adapter = _FakeAdapter([_Reply(_sse(['[DONE]']))]);

      await _provider(adapter).generate(prompt: 'hi').drain<void>();

      expect(adapter.body(0)['model'], 'big-model');
      expect(adapter.body(0)['stream'], isTrue);
    });

    test('sends the system prompt, then history, then the question', () async {
      final adapter = _FakeAdapter([_Reply(_sse(['[DONE]']))]);

      await _provider(adapter).generate(
        prompt: 'and its units?',
        systemPrompt: 'You are a teacher.',
        history: const [
          AiMessage.user('What is entropy?'),
          AiMessage(role: AiRole.assistant, content: 'A measure of disorder.'),
        ],
      ).drain<void>();

      expect(adapter.body(0)['messages'], [
        {'role': 'system', 'content': 'You are a teacher.'},
        {'role': 'user', 'content': 'What is entropy?'},
        {'role': 'assistant', 'content': 'A measure of disorder.'},
        {'role': 'user', 'content': 'and its units?'},
      ]);
    });

    test('passes the sampling options through', () async {
      final adapter = _FakeAdapter([_Reply(_sse(['[DONE]']))]);

      await _provider(adapter).generate(
        prompt: 'hi',
        options: const AiGenerationOptions(
          temperature: 0.2,
          maxTokens: 512,
          topP: 0.9,
        ),
      ).drain<void>();

      expect(adapter.body(0)['temperature'], 0.2);
      expect(adapter.body(0)['max_tokens'], 512);
      expect(adapter.body(0)['top_p'], 0.9);
      expect(adapter.body(0).containsKey('tools'), isFalse);
    });
  });

  group('nothing is sent', () {
    test('while cloud AI is switched off', () async {
      final adapter = _FakeAdapter([_Reply(_sse(['[DONE]']))]);

      await expectLater(
        _provider(adapter, cloudAllowed: false).generate(prompt: 'hi').toList(),
        throwsA(isA<AiUnavailableException>()),
      );
      expect(adapter.requests, isEmpty);
    });

    test('when the connection has no saved key', () async {
      final adapter = _FakeAdapter([_Reply(_sse(['[DONE]']))]);

      await expectLater(
        _provider(adapter, key: null).generate(prompt: 'hi').toList(),
        throwsA(isA<AiUnavailableException>()),
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('a failed request', () {
    Future<AiException> failure(int status, {String body = '{}'}) async {
      final adapter = _FakeAdapter([_Reply(body, status: status)]);
      try {
        await _provider(adapter).generate(prompt: 'hi').toList();
      } on AiException catch (e) {
        return e;
      }
      fail('expected an AiException for HTTP $status');
    }

    test('401 says the key was rejected', () async {
      final e = await failure(401);
      expect(e, isA<AiUnavailableException>());
      expect(e.message, contains('rejected the key'));
    });

    test('403 says the key was rejected', () async {
      expect((await failure(403)).message, contains('rejected the key'));
    });

    test('402 says the account is out of credit', () async {
      final e = await failure(402);
      expect(e, isA<AiUnavailableException>());
      expect(e.message, contains('out of credit'));
    });

    test('404 says the model does not exist there', () async {
      final e = await failure(404);
      expect(e, isA<AiGenerationException>());
      expect(e.message, contains('big-model'));
    });

    test('429 says the limit was reached', () async {
      final e = await failure(429);
      expect(e, isA<AiUnavailableException>());
      expect(e.message, contains('limit'));
    });

    test('any other status is a generation failure with the code', () async {
      final e = await failure(500);
      expect(e, isA<AiGenerationException>());
      expect(e.message, contains('500'));
    });

    test('an unreachable host names the host', () async {
      final adapter = _FakeAdapter(
        const [],
        throwsError: DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        _provider(adapter).generate(prompt: 'hi').toList(),
        throwsA(
          isA<AiUnavailableException>().having(
            (e) => e.message,
            'message',
            contains('api.example.com'),
          ),
        ),
      );
    });

    test('never puts the key in what it reports', () async {
      for (final status in [400, 401, 402, 404, 429, 500]) {
        final e = await failure(
          status,
          body: '{"error":{"message":"Incorrect API key provided: $_key"}}',
        );
        expect(e.toString(), isNot(contains(_key)), reason: 'HTTP $status');
      }
    });
  });

  group('a damaged reply', () {
    test('a line that is not JSON is a generation failure', () async {
      final adapter = _FakeAdapter([_Reply('data: {"choices":[{"del\n\n')]);

      await expectLater(
        _provider(adapter).generate(prompt: 'hi').toList(),
        throwsA(isA<AiGenerationException>()),
      );
    });

    test('an error sent part-way through is a generation failure', () async {
      final adapter = _FakeAdapter([
        _Reply(_sse([
          _text('so far'),
          {'error': {'message': 'upstream overloaded', 'code': 502}},
        ])),
      ]);

      final seen = <String>[];
      await expectLater(
        _provider(adapter).generate(prompt: 'hi').forEach(seen.add),
        throwsA(isA<AiGenerationException>()),
      );
      expect(seen, ['so far'], reason: 'text already received is kept');
    });
  });

  group('a provider that wants different parameters', () {
    test('is asked again with max_completion_tokens when it refuses max_tokens',
        () async {
      final adapter = _FakeAdapter([
        const _Reply(
          '{"error":{"message":"Unsupported parameter: \'max_tokens\'. '
          'Use \'max_completion_tokens\' instead."}}',
          status: 400,
        ),
        _Reply(_sse([_text('ok'), '[DONE]'])),
      ]);
      const options = AiGenerationOptions(maxTokens: 256);

      final text = await _provider(adapter)
          .generate(prompt: 'hi', options: options)
          .join();

      expect(text, 'ok');
      expect(adapter.body(1).containsKey('max_tokens'), isFalse);
      expect(adapter.body(1)['max_completion_tokens'], 256);
    });

    test('is asked again without temperature when it refuses temperature',
        () async {
      final adapter = _FakeAdapter([
        const _Reply(
          '{"error":{"message":"Unsupported value: \'temperature\' does not '
          'support 0.2 with this model."}}',
          status: 400,
        ),
        _Reply(_sse([_text('ok'), '[DONE]'])),
      ]);

      final text = await _provider(adapter).generate(prompt: 'hi').join();

      expect(text, 'ok');
      expect(adapter.body(1).containsKey('temperature'), isFalse);
    });

    test('remembers, so the next question does not pay for a refusal',
        () async {
      final adapter = _FakeAdapter([
        const _Reply('{"error":{"message":"max_tokens is not supported"}}',
            status: 400),
        _Reply(_sse(['[DONE]'])),
        _Reply(_sse(['[DONE]'])),
      ]);
      final provider = _provider(adapter);
      const options = AiGenerationOptions(maxTokens: 256);

      await provider.generate(prompt: 'one', options: options).drain<void>();
      await provider.generate(prompt: 'two', options: options).drain<void>();

      expect(adapter.requests, hasLength(3));
      expect(adapter.body(2)['max_completion_tokens'], 256);
    });

    test('a refusal about anything else is reported, not retried', () async {
      final adapter = _FakeAdapter([
        const _Reply('{"error":{"message":"messages is too long"}}',
            status: 400),
      ]);

      await expectLater(
        _provider(adapter).generate(prompt: 'hi').toList(),
        throwsA(isA<AiGenerationException>()),
      );
      expect(adapter.requests, hasLength(1));
    });
  });

  group('tool calling', () {
    test('offers the tools in the request', () async {
      final adapter = _FakeAdapter([_Reply(_sse(['[DONE]']))]);

      await _provider(adapter)
          .generateWithTools(prompt: 'what is 2+2', tools: [_Calculator()])
          .drain<void>();

      expect(adapter.body(0)['tool_choice'], 'auto');
      expect(adapter.body(0)['tools'], [toolSchema(_Calculator())]);
    });

    test('text arrives as text and a call arrives once it is whole', () async {
      final adapter = _FakeAdapter([
        _Reply(_sse([
          _text('Let me work that out.'),
          _toolDelta(0, id: 'call_1', name: 'calculator', arguments: '{"ex'),
          _toolDelta(0, arguments: 'pression":"2+2"}'),
          '[DONE]',
        ])),
      ]);

      final events = await _provider(adapter)
          .generateWithTools(prompt: 'what is 2+2', tools: [_Calculator()])
          .toList();

      expect(events, hasLength(2));
      expect((events[0] as ToolTextChunk).text, 'Let me work that out.');
      final call = events[1] as ToolCallRequested;
      expect(call.callId, 'call_1');
      expect(call.name, 'calculator');
      expect(call.arguments, {'expression': '2+2'});
    });

    test('two calls in one reply are kept apart by their index', () async {
      final adapter = _FakeAdapter([
        _Reply(_sse([
          _toolDelta(0, id: 'a', name: 'calculator', arguments: '{"expression"'),
          _toolDelta(1, id: 'b', name: 'calculator', arguments: '{"expression"'),
          _toolDelta(0, arguments: ':"1+1"}'),
          _toolDelta(1, arguments: ':"2+2"}'),
          '[DONE]',
        ])),
      ]);

      final calls = (await _provider(adapter)
              .generateWithTools(prompt: 'q', tools: [_Calculator()])
              .toList())
          .cast<ToolCallRequested>();

      expect(calls.map((c) => c.callId), ['a', 'b']);
      expect(calls.map((c) => c.arguments['expression']), ['1+1', '2+2']);
    });

    test('a call with no arguments is a call with none', () async {
      final adapter = _FakeAdapter([
        _Reply(_sse([_toolDelta(0, id: 'a', name: 'calculator'), '[DONE]'])),
      ]);

      final call = (await _provider(adapter)
              .generateWithTools(prompt: 'q', tools: [_Calculator()])
              .toList())
          .single as ToolCallRequested;

      expect(call.arguments, isEmpty);
    });

    test('a call that never got its name is a generation failure', () async {
      final adapter = _FakeAdapter([
        _Reply(_sse([_toolDelta(0, arguments: '{}'), '[DONE]'])),
      ]);

      await expectLater(
        _provider(adapter)
            .generateWithTools(prompt: 'q', tools: [_Calculator()])
            .toList(),
        throwsA(isA<AiGenerationException>()),
      );
    });

    test('arguments that are not JSON are a generation failure', () async {
      final adapter = _FakeAdapter([
        _Reply(_sse([
          _toolDelta(0, id: 'a', name: 'calculator', arguments: '{"expr'),
          '[DONE]',
        ])),
      ]);

      await expectLater(
        _provider(adapter)
            .generateWithTools(prompt: 'q', tools: [_Calculator()])
            .toList(),
        throwsA(isA<AiGenerationException>()),
      );
    });

    test('arguments that grow without end are cut off as a failure', () async {
      final adapter = _FakeAdapter([
        _Reply(_sse([
          _toolDelta(0, id: 'a', name: 'calculator', arguments: '{"x":"'),
          _toolDelta(0, arguments: 'y' * 9000),
          '[DONE]',
        ])),
      ]);

      await expectLater(
        _provider(adapter)
            .generateWithTools(prompt: 'q', tools: [_Calculator()])
            .toList(),
        throwsA(isA<AiGenerationException>()),
      );
    });

    test('a follow-up after a tool result adds no empty user turn', () async {
      final adapter = _FakeAdapter([_Reply(_sse(['[DONE]']))]);
      const toolCalls = [
        {
          'id': 'call_1',
          'type': 'function',
          'function': {'name': 'calculator', 'arguments': '{"expression":"2+2"}'},
        },
      ];

      await _provider(adapter).generateWithTools(
        prompt: '',
        tools: [_Calculator()],
        history: const [
          AiMessage.user('what is 2+2'),
          AiMessage(role: AiRole.assistant, content: '', toolCalls: toolCalls),
          AiMessage(role: AiRole.tool, content: '4', toolCallId: 'call_1'),
        ],
      ).drain<void>();

      expect(adapter.body(0)['messages'], [
        {'role': 'user', 'content': 'what is 2+2'},
        {'role': 'assistant', 'content': '', 'tool_calls': toolCalls},
        {'role': 'tool', 'content': '4', 'tool_call_id': 'call_1'},
      ]);
    });
  });

  test('describes itself as a cloud model with the window it was given', () {
    final capabilities = _provider(_FakeAdapter(const [])).capabilities;

    expect(capabilities.displayName, 'My AI · Big');
    expect(capabilities.contextWindowTokens, 32000);
    expect(capabilities.isLocal, isFalse);
  });
}
