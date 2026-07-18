import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/core/providers/settings_provider.dart' show CloudPrivacy;
import 'package:inkflow/features/ai/domain/ai_message.dart';
import 'package:inkflow/features/ai/domain/features/researcher.dart';
import 'package:inkflow/features/ai/domain/tools/tool.dart';
import 'package:inkflow/features/ai/domain/tools/tool_generation_event.dart';
import 'package:inkflow/features/ai/presentation/research_notifier.dart';

/// Scripted client — same pattern as `researcher_test.dart`.
class _ScriptedClient implements ToolCallingClient {
  final List<List<ToolGenerationEvent>> _responses;
  int _calls = 0;
  _ScriptedClient(this._responses);

  @override
  Stream<ToolGenerationEvent> generateWithTools({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    required List<Tool> tools,
  }) async* {
    for (final event in _responses[_calls++]) {
      yield event;
    }
  }
}

void main() {
  ResearchNotifier notifier(
    List<List<ToolGenerationEvent>> script, {
    CloudPrivacy privacy = CloudPrivacy.askEachTime,
    bool hasSeenFirstCloudCall = false,
  }) {
    var seen = hasSeenFirstCloudCall;
    final researcher =
        Researcher(client: _ScriptedClient(script), tools: const []);
    return ResearchNotifier(
      researcher: researcher,
      privacy: () => privacy,
      hasSeenFirstCloudCall: () => seen,
      markFirstCloudCallSeen: () async => seen = true,
    );
  }

  test('startComposing opens the query box', () {
    final n = notifier([
      [const ToolTextChunk('unused')],
    ]);

    n.startComposing();

    expect(n.state, isA<ResearchComposing>());
  });

  test('a question pauses on ResearchConfirmCloud without calling the model',
      () async {
    final n = notifier([
      [const ToolTextChunk('unused')],
    ]);

    await n.ask('what is 2+2');

    expect(n.state, isA<ResearchConfirmCloud>());
  });

  test('confirmCloudAndAsk proceeds and lands in ready', () async {
    final n = notifier([
      [const ToolTextChunk('The answer is 4.')],
    ]);

    await n.ask('what is 2+2');
    await n.confirmCloudAndAsk();

    final ready = n.state as ResearchReady;
    expect(ready.text, 'The answer is 4.');
  });

  test('cancelCloud returns to idle without calling the model', () async {
    final n = notifier([
      [const ToolTextChunk('unused')],
    ]);

    await n.ask('what is 2+2');
    n.cancelCloud();

    expect(n.state, isA<ResearchIdle>());
  });

  test('an empty question is a no-op', () async {
    final n = notifier([
      [const ToolTextChunk('unused')],
    ]);

    await n.ask('   ');

    expect(n.state, isA<ResearchIdle>());
  });

  test('privacy localOnly reports unavailable and never confirms', () async {
    final n = notifier(
      [
        [const ToolTextChunk('unused')],
      ],
      privacy: CloudPrivacy.localOnly,
    );

    await n.ask('what is 2+2');

    expect(n.state, isA<ResearchUnavailable>());
  });

  test(
      'isFirstEver reflects hasSeenFirstCloudCall, then flips after confirming',
      () async {
    final n = notifier(
      [
        [const ToolTextChunk('answer 1')],
        [const ToolTextChunk('answer 2')],
      ],
      hasSeenFirstCloudCall: false,
    );

    await n.ask('question one');
    expect((n.state as ResearchConfirmCloud).isFirstEver, isTrue);

    await n.confirmCloudAndAsk();
    expect(n.state, isA<ResearchReady>());

    await n.ask('question two');
    expect((n.state as ResearchConfirmCloud).isFirstEver, isFalse);
  });

  test('toolsUsed accumulates onto the ready state', () async {
    final n = notifier([
      [
        const ToolCallRequested(callId: 'c1', name: 'calculator', arguments: {}),
      ],
      [const ToolTextChunk('done')],
    ]);

    await n.ask('question');
    await n.confirmCloudAndAsk();

    final ready = n.state as ResearchReady;
    expect(ready.toolsUsed, ['calculator']);
  });

  test('retry re-confirms rather than skipping the cloud gate', () async {
    final n = notifier([
      [const ToolTextChunk('answer 1')],
      [const ToolTextChunk('answer 2')],
    ]);

    await n.ask('question');
    await n.confirmCloudAndAsk();
    expect(n.state, isA<ResearchReady>());

    await n.retry();

    expect(n.state, isA<ResearchConfirmCloud>(),
        reason: 'a retry is still a new network call, not a continuation '
            'of an already-confirmed one');
  });

  test('reset returns to idle', () async {
    final n = notifier([
      [const ToolTextChunk('answer')],
    ]);

    await n.ask('question');
    await n.confirmCloudAndAsk();
    expect(n.state, isA<ResearchReady>());

    n.reset();
    expect(n.state, isA<ResearchIdle>());
  });
}
