// The Riverpod wiring around the on-device model: who may start a warm-up, and
// that where the model really runs is published for the rest of the app.
//
// Driven through the real providers with only the inference runtime faked,
// because the wiring is the thing under test — a one-line closure that passes
// its own unit tests but is never connected is exactly the failure here.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inkflow/core/providers/settings_provider.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/compute_backend.dart';
import 'package:inkflow/features/ai/domain/device_state.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';

class _Session implements LlmSession {
  @override
  Future<void> addTurn(String text, {required bool isUser}) async {}
  @override
  Future<String> respond(String prompt) async => '';
  @override
  Stream<String> respondStream(String prompt) => const Stream.empty();
  @override
  Future<String> respondWithImage(String prompt, Uint8List imageBytes) async =>
      '';
  @override
  Future<void> close() async {}
}

class _Runtime implements LlmRuntime {
  _Runtime({this.backend});

  final ComputeBackend? backend;
  int opens = 0;

  @override
  ComputeBackend? get activeBackend => backend;

  @override
  Future<LlmSession> open({
    required LlmModelSpec spec,
    required double temperature,
    required int topK,
    required double topP,
    int? maxOutputTokens,
    String? systemInstruction,
    int? randomSeed,
    bool supportImage = false,
    int maxNumImages = 1,
  }) async {
    opens++;
    return _Session();
  }

  @override
  Future<void> releaseModel() async {}
}

class _NotLocal implements AiProvider {
  @override
  AiCapabilities get capabilities => const AiCapabilities(
      modelId: 'x', displayName: 'x', contextWindowTokens: 4096);
  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) =>
      const Stream.empty();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer container(_Runtime runtime) {
    final c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [llmRuntimeProvider.overrideWithValue(runtime)]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  group('localModelWarmerProvider', () {
    test('loads the on-device model when the user shows intent', () async {
      final runtime = _Runtime();
      final c = container(runtime);

      c.read(localModelWarmerProvider)();
      await settle();

      expect(runtime.opens, 1);
    });

    test('does nothing in cloud-first mode — the local model is not used',
        () async {
      final runtime = _Runtime();
      final c = container(runtime);
      await c.read(settingsProvider.notifier).setAiMode(AiProcessingMode.cloudFirst);

      c.read(localModelWarmerProvider)();
      await settle();

      expect(runtime.opens, 0,
          reason: 'loading 2.6 GB for a mode that never touches it');
    });

    test('does nothing on a device too short of RAM to hold the model warm',
        () async {
      // A 4 GB phone cannot spare 2.6 GB for a guess about what the student will
      // do next; the model loads when something actually needs it.
      final runtime = _Runtime();
      final c = ProviderContainer(retry: (_, _) => null, overrides: [
        llmRuntimeProvider.overrideWithValue(runtime),
        deviceProfileProvider.overrideWithValue(AiProfile.cloudAssisted),
      ]);
      addTearDown(c.dispose);

      c.read(localModelWarmerProvider)();
      await settle();

      expect(runtime.opens, 0);
    });

    test('is a harmless no-op when the local provider is not the real one',
        () async {
      final c = ProviderContainer(
          retry: (_, _) => null,
          overrides: [localAiProvider.overrideWithValue(_NotLocal())]);
      addTearDown(c.dispose);

      c.read(localModelWarmerProvider)(); // must not throw
      await settle();
    });
  });

  group('localBackendProvider', () {
    test('is unknown until the model has loaded', () {
      final c = container(_Runtime(backend: ComputeBackend.cpu));
      expect(c.read(localBackendProvider), isNull);
    });

    test('publishes where the model really runs once it has loaded', () async {
      final c = container(_Runtime(backend: ComputeBackend.cpu));

      c.read(localModelWarmerProvider)();
      await settle();

      expect(c.read(localBackendProvider), ComputeBackend.cpu);
    });
  });

  group('device profile', () {
    int contextWindow(AiProfile profile) {
      final c = ProviderContainer(retry: (_, _) => null, overrides: [
        deviceProfileProvider.overrideWithValue(profile),
        llmRuntimeProvider.overrideWithValue(_Runtime()),
      ]);
      addTearDown(c.dispose);
      return c.read(localAiProvider).capabilities.contextWindowTokens;
    }

    test('a lite device gets a smaller window, so every feature re-budgets',
        () {
      // The word budget every feature truncates to is derived from the
      // provider's window (AiRouter.inputWordBudgetFor), so shrinking it here is
      // all that is needed for the whole app to send less.
      expect(contextWindow(AiProfile.lite),
          lessThan(contextWindow(AiProfile.full)));
    });

    test('the default profile is full', () {
      final c = ProviderContainer(
          retry: (_, _) => null,
          overrides: [llmRuntimeProvider.overrideWithValue(_Runtime())]);
      addTearDown(c.dispose);

      expect(c.read(deviceProfileProvider), AiProfile.full);
    });
  });
}
