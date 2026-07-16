import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';
import 'package:inkflow/features/ai/domain/features/quiz_generator.dart';
import 'package:inkflow/features/ai/presentation/quiz_notifier.dart';

// ---- Fakes ------------------------------------------------------------------

class _NoopProvider implements AiProvider {
  @override
  AiCapabilities get capabilities => const AiCapabilities(
      modelId: 'noop',
      displayName: 'noop',
      contextWindowTokens: 4096,
      isLocal: true);
  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) =>
      throw UnimplementedError();
  @override
  Future<List<double>> embed(String text) => throw UnimplementedError();
}

/// Scripts `generate` directly so the notifier is isolated from parsing.
class _FakeGenerator extends QuizGenerator {
  final List<QuizQuestion> result;
  final Object? error;
  int calls = 0;

  _FakeGenerator({this.result = const [], this.error})
      : super(provider: _NoopProvider());

  @override
  Future<List<QuizQuestion>> generate({
    required String text,
    required KnowledgeLevel level,
    bool allowCoding = false,
    int count = 5,
  }) async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
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
  const enough =
      'a page with more than fifteen words of real content to build a quiz from today';

  QuizNotifier notifier(_FakeGenerator generator) => QuizNotifier(
        generator: generator,
        downloads: ModelDownloadManager(
            installer: _FakeInstaller(), storage: _FakeStorage()),
      );

  QuizRequest request({String text = enough}) => QuizRequest(
        resolveText: () async => text,
        level: KnowledgeLevel.intermediate,
      );

  test('generates and publishes a ready quiz', () async {
    final gen = _FakeGenerator(result: const [
      QuizQuestion(
          type: QuestionType.trueFalse,
          prompt: 'The sky is blue.',
          options: ['True', 'False'],
          correctIndex: 0,
          correctAnswer: 'True'),
    ]);
    final n = notifier(gen);

    await n.generate(request());

    final ready = n.state as QuizReady;
    expect(ready.questions, hasLength(1));
    expect(gen.calls, 1);
  });

  test('too little content is a non-retryable error, no generation', () async {
    final gen = _FakeGenerator(result: const []);
    final n = notifier(gen);

    await n.generate(request(text: 'too short'));

    final error = n.state as QuizError;
    expect(error.retryable, isFalse);
    expect(gen.calls, 0);
  });

  test('an empty quiz surfaces a retryable error', () async {
    final n = notifier(_FakeGenerator(result: const []));

    await n.generate(request());

    final error = n.state as QuizError;
    expect(error.retryable, isTrue);
    expect(error.offerModelDownload, isFalse);
  });

  test('a missing model offers the download', () async {
    final n = notifier(
        _FakeGenerator(error: const AiModelNotReadyException('no model')));

    await n.generate(request());

    expect((n.state as QuizError).offerModelDownload, isTrue);
  });

  test('reset returns to idle', () async {
    final n = notifier(_FakeGenerator(result: const [
      QuizQuestion(
          type: QuestionType.fillBlank, prompt: 'q', correctAnswer: 'a'),
    ]));
    await n.generate(request());
    expect(n.state, isA<QuizReady>());

    n.reset();
    expect(n.state, isA<QuizIdle>());
  });
}
