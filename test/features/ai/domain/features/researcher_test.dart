import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_message.dart';
import 'package:inkflow/features/ai/domain/features/researcher.dart';
import 'package:inkflow/features/ai/domain/tools/tool.dart';
import 'package:inkflow/features/ai/domain/tools/tool_generation_event.dart';

/// Scripted client: each call to `generateWithTools` pops the next scripted
/// response off the queue and records the request it was given — the same
/// "hand-written fake at the boundary" pattern used for `AiProvider` in
/// `explain_notifier_test.dart`.
class _ScriptedClient implements ToolCallingClient {
  final List<List<ToolGenerationEvent>> _responses;
  final List<Map<String, Object?>> requests = [];
  int _calls = 0;

  _ScriptedClient(this._responses);

  @override
  Stream<ToolGenerationEvent> generateWithTools({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    required List<Tool> tools,
  }) async* {
    requests.add({'prompt': prompt, 'history': history, 'tools': tools});
    if (_calls >= _responses.length) {
      throw StateError('Researcher made more gateway calls than scripted');
    }
    for (final event in _responses[_calls++]) {
      yield event;
    }
  }
}

class _FakeTool implements Tool {
  final String _name;
  final ToolExecutionResult Function(Map<String, dynamic>) _execute;
  _FakeTool(this._name, this._execute);

  @override
  String get name => _name;
  @override
  String get description => 'fake tool';
  @override
  Map<String, dynamic> get parameterSchema => const {'type': 'object'};
  @override
  Future<ToolExecutionResult> execute(Map<String, dynamic> arguments) async =>
      _execute(arguments);
}

void main() {
  group('Researcher', () {
    test('a plain text answer with no tool calls returns directly', () async {
      final client = _ScriptedClient([
        [const ToolTextChunk('The answer is 4.')],
      ]);
      final researcher = Researcher(client: client, tools: const []);

      final events = await researcher.research('what is 2+2').toList();

      expect(events, hasLength(1));
      expect((events.first as ResearchTextChunk).text, 'The answer is 4.');
      expect(client.requests, hasLength(1));
      expect(client.requests.first['prompt'], 'what is 2+2');
      expect(client.requests.first['history'], isNull);
    });

    test('runs a requested tool and recalls with the result appended',
        () async {
      final calculator =
          _FakeTool('calculator', (args) => const ToolExecutionResult.ok('4'));
      final client = _ScriptedClient([
        [
          const ToolCallRequested(
            callId: 'call_1',
            name: 'calculator',
            arguments: {'expression': '2+2'},
          ),
        ],
        [const ToolTextChunk('The answer is 4.')],
      ]);
      final researcher = Researcher(client: client, tools: [calculator]);

      final events = await researcher.research('what is 2+2').toList();

      final toolUsed = events.whereType<ResearchToolUsed>().toList();
      expect(toolUsed, hasLength(1));
      expect(toolUsed.first.toolName, 'calculator');
      expect(events.whereType<ResearchTextChunk>().last.text, 'The answer is 4.');

      expect(client.requests, hasLength(2));
      final recall = client.requests[1];
      expect(recall['prompt'], '', reason: 'nothing new from the user on a recall');
      final history = recall['history'] as List<AiMessage>;
      expect(history, hasLength(3)); // user, assistant(tool_calls), tool
      expect(history[0].role, AiRole.user);
      expect(history[1].role, AiRole.assistant);
      expect(history[1].toolCalls!.first['id'], 'call_1');
      expect(history[2].role, AiRole.tool);
      expect(history[2].toolCallId, 'call_1');
      expect(history[2].content, '4');
    });

    test('an unknown tool name is answered as a tool error, not a crash',
        () async {
      final client = _ScriptedClient([
        [
          const ToolCallRequested(
              callId: 'call_1', name: 'nonexistent', arguments: {}),
        ],
        [const ToolTextChunk('done')],
      ]);
      final researcher = Researcher(client: client, tools: const []);

      final events = await researcher.research('question').toList();

      expect(events.whereType<ResearchToolUsed>().single.toolName, 'nonexistent');
      final recall = client.requests[1];
      final history = recall['history'] as List<AiMessage>;
      expect(history.last.content, contains('Unknown tool'));
    });

    test('runs multiple parallel tool calls from a single turn', () async {
      final calc =
          _FakeTool('calculator', (args) => const ToolExecutionResult.ok('4'));
      final wiki =
          _FakeTool('wikipedia', (args) => const ToolExecutionResult.ok('bio'));
      final client = _ScriptedClient([
        [
          const ToolCallRequested(callId: 'call_1', name: 'calculator', arguments: {}),
          const ToolCallRequested(callId: 'call_2', name: 'wikipedia', arguments: {}),
        ],
        [const ToolTextChunk('done')],
      ]);
      final researcher = Researcher(client: client, tools: [calc, wiki]);

      final events = await researcher.research('question').toList();

      expect(
        events.whereType<ResearchToolUsed>().map((e) => e.toolName),
        ['calculator', 'wikipedia'],
      );

      final history = client.requests[1]['history'] as List<AiMessage>;
      expect(history, hasLength(4)); // user, assistant(2 calls), tool, tool
      expect(history[1].toolCalls, hasLength(2));
      expect(history[2].toolCallId, 'call_1');
      expect(history[3].toolCallId, 'call_2');
    });

    test('stops after maxToolHops rather than looping forever', () async {
      final calc =
          _FakeTool('calculator', (args) => const ToolExecutionResult.ok('x'));
      // Every response keeps asking for another tool call — the loop must
      // still terminate rather than recursing indefinitely.
      final endlessCalls = List.generate(
        Researcher.maxToolHops + 1,
        (_) => [
          const ToolCallRequested(callId: 'call_x', name: 'calculator', arguments: {}),
        ],
      );
      final client = _ScriptedClient(endlessCalls);
      final researcher = Researcher(client: client, tools: [calc]);

      final events = await researcher.research('question').toList();

      // Terminates with a "gave up" message rather than the scripted client's
      // StateError (which would mean the cap didn't hold).
      expect(events.whereType<ResearchTextChunk>().last.text, contains('Stopped'));
      expect(client.requests, hasLength(Researcher.maxToolHops + 1));
    });
  });
}
