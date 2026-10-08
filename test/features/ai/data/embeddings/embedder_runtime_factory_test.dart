// A model's format picks its runtime. A bundle has no runtime in this build, and
// says so as a typed failure the UI can show, rather than as a missing file or a
// plugin error. An app-owned prompt is refused before the plugin is touched:
// flutter_edge_ai always prepends its own prefix, so the app's would be doubled.

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_adapter.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_spec.dart';
import 'package:inkflow/features/ai/data/embeddings/local_text_embedder.dart';
import 'package:inkflow/features/ai/domain/ai_exception.dart';
import 'package:inkflow/features/ai/domain/rag/prompt_contract.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

EmbedderSpec _appOwned() => const EmbedderSpec(
      displayName: 'App-owned prompt (test)',
      modelId: 'app-owned-test-appcontract',
      modelUrl: 'https://example.com/model.tflite',
      tokenizerUrl: 'https://example.com/sentencepiece.model',
      format: EmbedderFormat.tfliteWithTokenizer,
      maxInputTokens: 512,
      chunkWords: 250,
      chunkOverlapWords: 30,
      promptContract: PromptContract(
        id: 'appcontract',
        appliedBy: PromptAppliedBy.app,
        titleInText: false,
      ),
      runtimeSupported: true,
      approxSizeBytes: 1024,
      dimensions: 768,
      needsAuth: false,
    );

void main() {
  test('a tflite model runs on the flutter_edge_ai runtime', () {
    expect(
      embeddingRuntimeFor(EmbedderSpec.active),
      isA<EdgeAiEmbeddingRuntime>(),
    );
  });

  test('a bundle has no runtime in this build', () async {
    const spec = EmbedderSpec.embeddingGemma2;
    await expectLater(
      embeddingRuntimeFor(spec).open(spec),
      throwsA(isA<EmbedderRuntimeUnsupportedException>()),
    );
  });

  test('an embedder for a bundle reports it as not ready, with the reason',
      () async {
    final embedder = LocalTextEmbedder(spec: EmbedderSpec.embeddingGemma2);
    await expectLater(
      embedder.embedOne('hello', taskType: EmbedTaskType.query),
      throwsA(
        isA<AiModelNotReadyException>()
            .having((e) => e.message, 'message', contains('cannot run')),
      ),
    );
  });

  test('an app-owned prompt is refused before the plugin is asked', () async {
    // open() must fail on the contract alone, so no plugin call is reached.
    await expectLater(
      EdgeAiEmbeddingRuntime().open(_appOwned()),
      throwsUnsupportedError,
    );
  });
}
