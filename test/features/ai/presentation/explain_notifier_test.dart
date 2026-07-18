import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/features/explainer.dart';
import 'package:inkflow/features/ai/domain/routing/intelligent_router.dart'
    show CloudRouteDecision, CloudTier;
import 'package:inkflow/features/ai/presentation/explain_notifier.dart';

// ---- Fakes ------------------------------------------------------------------

class _ScriptedProvider implements AiProvider {
  final List<String> chunks;
  final Object? throwError;
  String? lastSystemPrompt;

  _ScriptedProvider(this.chunks, {this.throwError});

  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'scripted',
        displayName: 'Scripted',
        contextWindowTokens: 4096,
        isLocal: true,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    lastSystemPrompt = systemPrompt;
    if (throwError != null) throw throwError!;
    for (final c in chunks) {
      yield c;
    }
  }

  @override
  Future<List<double>> embed(String text) async => throw UnimplementedError();
}

class _FakeInstaller implements ModelInstaller {
  @override
  Future<bool> isInstalled(String modelId) async => true;
  @override
  Future<void> install({
    required LlmModelSpec spec,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<void> uninstall(String modelId) async {}
}

class _FakeStorage implements DeviceStorage {
  @override
  Future<int> freeBytes() async => 1 << 62;
}

// ---- Tests ------------------------------------------------------------------

void main() {
  ExplainNotifier notifier(AiProvider provider) => ExplainNotifier(
        explainer: Explainer(provider: provider),
        downloads: ModelDownloadManager(
            installer: _FakeInstaller(), storage: _FakeStorage()),
      );

  ExplainRequest request(ExplainMode mode, {String content = 'the passage'}) =>
      ExplainRequest(resolveContent: () async => content, mode: mode);

  test('streams chunks and lands in ready with the full text', () async {
    final n = notifier(_ScriptedProvider(['Photo', 'synth', 'esis']));
    final states = <ExplainState>[];
    n.addListener(states.add, fireImmediately: false);

    await n.run(request(ExplainMode.beginner));

    expect(states.whereType<ExplainPreparing>(), isNotEmpty);
    expect(states.whereType<ExplainStreaming>(), isNotEmpty);
    final ready = n.state as ExplainReady;
    expect(ready.text, 'Photosynthesis');
    expect(ready.mode, ExplainMode.beginner);
  });

  test('empty content is a non-retryable error, no model call', () async {
    final provider = _ScriptedProvider(['unused']);
    final n = notifier(provider);

    await n.run(request(ExplainMode.beginner, content: '   '));

    final error = n.state as ExplainError;
    expect(error.retryable, isFalse);
    expect(provider.lastSystemPrompt, isNull, reason: 'model was never called');
  });

  test('a not-ready model surfaces an offer-download error', () async {
    final n = notifier(_ScriptedProvider(const [],
        throwError: const AiModelNotReadyException('no model')));

    await n.run(request(ExplainMode.intermediate));

    final error = n.state as ExplainError;
    expect(error.offerModelDownload, isTrue);
  });

  test('changeMode re-runs the same passage at the new depth', () async {
    final provider = _ScriptedProvider(['ok']);
    final n = notifier(provider);

    await n.run(request(ExplainMode.beginner));
    expect((n.state as ExplainReady).mode, ExplainMode.beginner);

    await n.changeMode(ExplainMode.advanced);

    expect((n.state as ExplainReady).mode, ExplainMode.advanced);
    expect(provider.lastSystemPrompt,
        Explainer.systemPromptFor(ExplainMode.advanced));
  });

  test('reset returns to idle', () async {
    final n = notifier(_ScriptedProvider(['ok']));
    await n.run(request(ExplainMode.beginner));
    expect(n.state, isA<ExplainReady>());

    n.reset();
    expect(n.state, isA<ExplainIdle>());
  });

  group('Phase 3 cloud-confirm gate', () {
    ExplainNotifier routedNotifier(
      AiProvider provider, {
      required CloudRouteDecision? Function(String) evaluate,
      bool hasSeenFirstCloudCall = false,
    }) {
      var seen = hasSeenFirstCloudCall;
      return ExplainNotifier(
        explainer: Explainer(provider: provider),
        downloads: ModelDownloadManager(
            installer: _FakeInstaller(), storage: _FakeStorage()),
        evaluateCloudRoute: (content) async => evaluate(content),
        hasSeenFirstCloudCall: () => seen,
        markFirstCloudCallSeen: () async => seen = true,
      );
    }

    test('a cloud decision pauses on ExplainConfirmCloud without calling the model',
        () async {
      final provider = _ScriptedProvider(['unused']);
      final n = routedNotifier(provider,
          evaluate: (_) => const CloudRouteDecision(CloudTier.mid));

      await n.run(request(ExplainMode.beginner));

      final confirm = n.state as ExplainConfirmCloud;
      expect(confirm.tier, CloudTier.mid);
      expect(provider.lastSystemPrompt, isNull, reason: 'model was never called');
    });

    test('a local decision (null) skips confirmation entirely', () async {
      final provider = _ScriptedProvider(['local answer']);
      final n = routedNotifier(provider, evaluate: (_) => null);

      await n.run(request(ExplainMode.beginner));

      final ready = n.state as ExplainReady;
      expect(ready.text, 'local answer');
      expect(ready.fromCloud, isFalse);
    });

    test('confirmCloudAndRun proceeds and marks fromCloud on the result',
        () async {
      final provider = _ScriptedProvider(['cloud answer']);
      final n = routedNotifier(provider,
          evaluate: (_) => const CloudRouteDecision(CloudTier.frontier));

      await n.run(request(ExplainMode.beginner));
      expect(n.state, isA<ExplainConfirmCloud>());

      await n.confirmCloudAndRun();

      final ready = n.state as ExplainReady;
      expect(ready.text, 'cloud answer');
      expect(ready.fromCloud, isTrue);
    });

    test('cancelCloud returns to idle without calling the model', () async {
      final provider = _ScriptedProvider(['unused']);
      final n = routedNotifier(provider,
          evaluate: (_) => const CloudRouteDecision(CloudTier.mid));

      await n.run(request(ExplainMode.beginner));
      n.cancelCloud();

      expect(n.state, isA<ExplainIdle>());
      expect(provider.lastSystemPrompt, isNull);
    });

    test('isFirstEver reflects hasSeenFirstCloudCall, then flips after confirming',
        () async {
      final provider = _ScriptedProvider(['cloud answer']);
      final n = routedNotifier(
        provider,
        evaluate: (_) => const CloudRouteDecision(CloudTier.mid),
        hasSeenFirstCloudCall: false,
      );

      await n.run(request(ExplainMode.beginner));
      expect((n.state as ExplainConfirmCloud).isFirstEver, isTrue);

      await n.confirmCloudAndRun();
      expect(n.state, isA<ExplainReady>());

      // A second request should no longer be flagged as the first-ever call.
      await n.run(request(ExplainMode.beginner, content: 'another passage'));
      expect((n.state as ExplainConfirmCloud).isFirstEver, isFalse);
    });
  });
}
