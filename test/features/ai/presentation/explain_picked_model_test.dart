// Explain when the student has picked a cloud model. Explain keeps its own
// "use the cloud?" step in the panel (it had one before there was a picker);
// these tests pin how that step behaves once the cloud model is one they chose.

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/data/llm/model_download_manager.dart';
import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/features/explainer.dart';
import 'package:margo/features/ai/domain/routing/intelligent_router.dart'
    show CloudRouteDecision, CloudTier;
import 'package:margo/features/ai/presentation/explain_notifier.dart';

class _FakeProvider implements AiProvider {
  final prompts = <String>[];

  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'picked',
        displayName: 'picked',
        contextWindowTokens: 32000,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    prompts.add(prompt);
    yield 'An explanation.';
  }
}

void main() {
  late _FakeProvider provider;
  late bool consented;

  ExplainNotifier build(CloudRouteDecision? decision) => ExplainNotifier(
        explainer: Explainer(provider: provider),
        downloads: ModelDownloadManager(),
        evaluateCloudRoute: (_) async => decision,
        hasSeenFirstCloudCall: () => true,
        markFirstCloudCallSeen: () async => consented = true,
      );

  ExplainRequest request() => ExplainRequest(
        resolveContent: () async => 'Entropy measures disorder.',
        mode: ExplainMode.intermediate,
      );

  setUp(() {
    provider = _FakeProvider();
    consented = false;
  });

  test('the question names the picked model and where the text goes',
      () async {
    final notifier = build(const CloudRouteDecision(
      CloudTier.mid,
      modelName: 'My AI · Big',
      host: 'api.example.com',
    ));

    await notifier.run(request());

    final confirm = notifier.state as ExplainConfirmCloud;
    expect(confirm.modelName, 'My AI · Big');
    expect(confirm.host, 'api.example.com');
    expect(provider.prompts, isEmpty, reason: 'nothing sent before a yes');
  });

  test('a yes sends it and labels the explanation with the model', () async {
    final notifier = build(const CloudRouteDecision(
      CloudTier.mid,
      modelName: 'My AI · Big',
    ));
    await notifier.run(request());

    await notifier.confirmCloudAndRun();

    final ready = notifier.state as ExplainReady;
    expect(ready.fromCloud, isTrue);
    expect(ready.modelName, 'My AI · Big');
    expect(provider.prompts, hasLength(1));
    expect(consented, isTrue);
  });

  test('when no question is needed it goes straight to the picked model',
      () async {
    final notifier = build(const CloudRouteDecision(
      CloudTier.mid,
      modelName: 'My AI · Big',
      needsConfirm: false,
    ));

    await notifier.run(request());

    final ready = notifier.state as ExplainReady;
    expect(ready.text, 'An explanation.');
    expect(ready.fromCloud, isTrue);
    expect(ready.modelName, 'My AI · Big');
  });

  test('a cancel sends nothing', () async {
    final notifier = build(const CloudRouteDecision(
      CloudTier.mid,
      modelName: 'My AI · Big',
    ));
    await notifier.run(request());

    notifier.cancelCloud();

    expect(notifier.state, isA<ExplainIdle>());
    expect(provider.prompts, isEmpty);
  });

  test('a cloud route with no model named still asks, as it always has',
      () async {
    final notifier = build(const CloudRouteDecision(CloudTier.mid));

    await notifier.run(request());

    final confirm = notifier.state as ExplainConfirmCloud;
    expect(confirm.modelName, isNull);
  });
}
