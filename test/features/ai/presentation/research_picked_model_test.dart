// Research when the student has picked a cloud model. Research keeps its own
// "send this?" step in the panel; these tests pin how it behaves once the
// cloud model is one the student chose.

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/features/researcher.dart';
import 'package:margo/features/ai/domain/tools/tool.dart';
import 'package:margo/features/ai/domain/tools/tool_generation_event.dart';
import 'package:margo/features/ai/presentation/research_notifier.dart';

class _Client implements ToolCallingClient {
  int calls = 0;

  @override
  Stream<ToolGenerationEvent> generateWithTools({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    required List<Tool> tools,
  }) async* {
    calls++;
    yield const ToolTextChunk('An answer.');
  }
}

void main() {
  late _Client client;
  late bool consented;

  ResearchNotifier build({
    bool? needsConfirm,
    ({String name, String? host})? picked,
  }) =>
      ResearchNotifier(
        researcher: Researcher(client: client, tools: const []),
        privacy: () => CloudPrivacy.askEachTime,
        hasSeenFirstCloudCall: () => true,
        markFirstCloudCallSeen: () async => consented = true,
        needsConfirm: needsConfirm == null ? null : () => needsConfirm,
        pickedModel: () => picked,
      );

  setUp(() {
    client = _Client();
    consented = false;
  });

  test('the question names the picked model and where the text goes',
      () async {
    final notifier = build(
      picked: (name: 'My AI · Big', host: 'api.example.com'),
    );

    await notifier.ask('what is the boiling point of ethanol?');

    final confirm = notifier.state as ResearchConfirmCloud;
    expect(confirm.modelName, 'My AI · Big');
    expect(confirm.host, 'api.example.com');
    expect(client.calls, 0, reason: 'nothing sent before a yes');
  });

  test('a yes sends it and is remembered', () async {
    final notifier = build(picked: (name: 'My AI · Big', host: null));
    await notifier.ask('what is the boiling point of ethanol?');

    await notifier.confirmCloudAndAsk();

    expect((notifier.state as ResearchReady).text, 'An answer.');
    expect(client.calls, 1);
    expect(consented, isTrue);
  });

  test('when no question is needed it goes straight to the picked model',
      () async {
    final notifier = build(
      needsConfirm: false,
      picked: (name: 'My AI · Big', host: null),
    );

    await notifier.ask('what is the boiling point of ethanol?');

    expect(notifier.state, isA<ResearchReady>());
    expect(client.calls, 1);
  });

  test('with no model picked it asks every time, as it always has', () async {
    final notifier = build();

    await notifier.ask('what is the boiling point of ethanol?');

    final confirm = notifier.state as ResearchConfirmCloud;
    expect(confirm.modelName, isNull);
    expect(client.calls, 0);
  });
}
