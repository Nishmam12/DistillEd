// Under cloud-first the page is analysed by the cloud. The quality guard used to
// sit in front of that and always ran the page on the DEVICE first, loading the
// 2.6 GB model for a mode that exists to avoid it.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/data/llm/gemma_adapter.dart';
import 'package:margo/features/ai/data/llm/llm_model_spec.dart';
import 'package:margo/features/ai/data/providers/cloud_gateway_provider.dart';
import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/compute_backend.dart';
import 'package:margo/features/ai/domain/page_content.dart';
import 'package:margo/features/ai/presentation/ai_providers.dart';

class _Session implements LlmSession {
  @override
  Future<void> addTurn(String text, {required bool isUser}) async {}
  @override
  Future<String> respond(String prompt) async => '';
  @override
  Stream<String> respondStream(String prompt) => Stream.value(_localJson);
  @override
  Future<String> respondWithImage(String prompt, Uint8List imageBytes) async =>
      '';
  @override
  Future<void> close() async {}
}

const _localJson = '{"currentTopic": "Local topic"}';
const _cloudJson = '{"currentTopic": "Cloud topic"}';

class _Runtime implements LlmRuntime {
  int opens = 0;

  @override
  ComputeBackend? get activeBackend => null;

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

class _FakeCloud extends CloudGatewayProvider {
  _FakeCloud() : super(baseUrl: 'http://unused', modelTier: 'cloud-mid');

  int calls = 0;

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) {
    calls++;
    return Stream.value(_cloudJson);
  }
}

const _page = PageContent(
  recognizedInkText: '',
  typedText: 'Photosynthesis converts light energy into chemical energy stored '
      'in glucose, and it happens in the chloroplasts of plant cells.',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cloud-first analyses on the cloud without loading the device model',
      () async {
    SharedPreferences.setMockInitialValues(
        {'ai.cloudPrivacy': CloudPrivacy.allowCloudForNonSensitive.name});
    final runtime = _Runtime();
    final cloud = _FakeCloud();
    final c = ProviderContainer(overrides: [
      llmRuntimeProvider.overrideWithValue(runtime),
      cloudGatewayMidProvider.overrideWithValue(cloud),
    ]);
    addTearDown(c.dispose);
    // Background analysis has no per-call prompt, so it only goes to the cloud
    // when the student has allowed that without being asked each time. The
    // setting has no setter of its own; it is read from stored preferences.
    c.read(settingsProvider.notifier);
    while (!c.read(settingsProvider).loaded) {
      await Future<void>.delayed(Duration.zero);
    }
    await c
        .read(settingsProvider.notifier)
        .setAiMode(AiProcessingMode.cloudFirst);

    final context = await c.read(contextEngineProvider).analyze(_page);

    expect(context.currentTopic, 'Cloud topic');
    expect(cloud.calls, 1);
    expect(runtime.opens, 0,
        reason: 'the guard ran the page through the 2.6 GB model first');
  });

  test('on-device mode still runs on the device', () async {
    final runtime = _Runtime();
    final cloud = _FakeCloud();
    final c = ProviderContainer(overrides: [
      llmRuntimeProvider.overrideWithValue(runtime),
      cloudGatewayMidProvider.overrideWithValue(cloud),
    ]);
    addTearDown(c.dispose);

    final context = await c.read(contextEngineProvider).analyze(_page);

    expect(context.currentTopic, 'Local topic');
    expect(runtime.opens, greaterThan(0));
    expect(cloud.calls, 0);
  });
}
