import 'dart:async';

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

/// Emits one chunk, signals [started], then stays open until its subscription
/// is cancelled — models a long, still-running hop so cancellation can be
/// exercised while the notifier is genuinely mid-stream. Backed by a
/// [StreamController] (not `async* … await neverCompletes`) so cancellation
/// grounds out the same way the real Dio-socket stream does — otherwise
/// `subscription.cancel()` would hang on an uncancellable suspension point,
/// which is a test artifact, not how production behaves.
class _HangingClient implements ToolCallingClient {
  final Completer<void> started;
  _HangingClient(this.started);

  @override
  Stream<ToolGenerationEvent> generateWithTools({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    required List<Tool> tools,
  }) {
    late final StreamController<ToolGenerationEvent> controller;
    controller = StreamController<ToolGenerationEvent>(
      onListen: () {
        controller.add(const ToolTextChunk('partial answer'));
        if (!started.isCompleted) started.complete();
        // Deliberately never closed — the run stays "in flight" until the
        // subscriber cancels, at which point the controller tears down cleanly.
      },
    );
    return controller.stream;
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

  ResearchNotifier notifierWith(ToolCallingClient client) {
    return ResearchNotifier(
      researcher: Researcher(client: client, tools: const []),
      privacy: () => CloudPrivacy.askEachTime,
      hasSeenFirstCloudCall: () => true,
      markFirstCloudCallSeen: () async {},
    );
  }

  /// Drives the notifier to a genuinely-streaming state against a hanging
  /// client, so a following `stop()`/`reset()` cancels a live stream.
  Future<ResearchNotifier> streaming() async {
    final started = Completer<void>();
    final n = notifierWith(_HangingClient(started));
    await n.ask('question');
    unawaited(n.confirmCloudAndAsk()); // starts the hang; never returns until cancelled
    await started.future;
    await Future<void>.delayed(Duration.zero); // let the chunk reach the notifier
    expect(n.state, isA<ResearchStreaming>());
    return n;
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

  test('reset cancels a still-streaming run and returns to idle', () async {
    final n = await streaming();

    n.reset();

    expect(n.state, isA<ResearchIdle>(),
        reason: 'the Close button must work mid-stream, not just once the '
            'run settles');
  });

  test('stop cancels a still-streaming run and reopens the query box',
      () async {
    final n = await streaming();

    n.stop();

    expect(n.state, isA<ResearchComposing>(),
        reason: 'Stop abandons the current run but keeps Research open so '
            'the user can immediately ask again');
  });
}
