// Two embedders on one model slot (docs/TECH_MIGRATION_PLAN.md, phase 4.5): the
// serving model and a rollout's target are never loaded together. The target's
// load releases the serving session first, and serving loads again, on its own,
// when a question needs it.

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/ai/data/embeddings/embedder_slot.dart';
import 'package:distill_ed/features/ai/data/embeddings/embedder_spec.dart';
import 'package:distill_ed/features/ai/data/embeddings/embedder_adapter.dart';
import 'package:distill_ed/features/ai/data/embeddings/local_text_embedder.dart';
import 'package:distill_ed/features/ai/data/llm/llm_exceptions.dart';
import 'package:distill_ed/features/ai/domain/ai_exception.dart';
import 'package:distill_ed/features/ai/domain/rag/prompt_contract.dart';
import 'package:distill_ed/features/ai/domain/rag/text_embedder.dart';

EmbedderSpec _spec(String name) => EmbedderSpec(
      displayName: name,
      modelId: '$name-titled',
      modelUrl: 'https://example.com/$name.tflite',
      tokenizerUrl: 'https://example.com/$name-tokenizer.model',
      format: EmbedderFormat.tfliteWithTokenizer,
      maxInputTokens: 512,
      chunkWords: 250,
      chunkOverlapWords: 30,
      promptContract: PromptContract.pluginGemma300m,
      runtimeSupported: true,
      approxSizeBytes: 1,
      dimensions: 3,
      needsAuth: false,
    );

class _Session implements EmbeddingSession {
  _Session(this.name, this.log);

  final String name;
  final List<String> log;

  @override
  Future<List<List<double>>> embedAll(
    List<String> texts, {
    required EmbedTaskType taskType,
  }) async {
    log.add('embed $name');
    return [for (final _ in texts) [1.0, 0.0, 0.0]];
  }

  @override
  Future<void> close() async => log.add('close $name');
}

class _Runtime implements EmbeddingRuntime {
  _Runtime(this.log, {this.failFor});

  final List<String> log;

  /// The model id whose open fails, if any.
  final String? failFor;

  @override
  Future<EmbeddingSession> open(EmbedderSpec spec) async {
    if (spec.modelId == failFor) throw LlmNotReadyException();
    log.add('open ${spec.displayName}');
    return _Session(spec.displayName, log);
  }
}

void main() {
  final serving = _spec('serving');
  final target = _spec('target');

  test('the target load releases the serving session first, and serving reloads on its own',
      () async {
    final log = <String>[];
    final slot = EmbedderSlot();
    final runtime = _Runtime(log);
    final servingEmbedder = LocalTextEmbedder(
      spec: serving,
      runtime: runtime,
      idleUnloadDelay: const Duration(minutes: 10),
      slot: slot,
    );
    final targetEmbedder = LocalTextEmbedder(
      spec: target,
      runtime: runtime,
      idleUnloadDelay: const Duration(minutes: 10),
      slot: slot,
    );

    await servingEmbedder.embedOne('question', taskType: EmbedTaskType.query);
    await targetEmbedder.embedOne('page', taskType: EmbedTaskType.document);
    await servingEmbedder.embedOne('question', taskType: EmbedTaskType.query);

    expect(log, [
      'open serving',
      'embed serving',
      'close serving',
      'open target',
      'embed target',
      'close target',
      'open serving',
      'embed serving',
    ]);
    await servingEmbedder.release();
    await targetEmbedder.release();
  });

  test('a target that fails to open leaves the slot free, so serving loads with no release',
      () async {
    final log = <String>[];
    final slot = EmbedderSlot();
    final runtime = _Runtime(log, failFor: target.modelId);
    final servingEmbedder = LocalTextEmbedder(
      spec: serving,
      runtime: runtime,
      idleUnloadDelay: const Duration(minutes: 10),
      slot: slot,
    );
    final targetEmbedder = LocalTextEmbedder(
      spec: target,
      runtime: runtime,
      idleUnloadDelay: const Duration(minutes: 10),
      slot: slot,
    );

    await expectLater(
      targetEmbedder.embedOne('page', taskType: EmbedTaskType.document),
      throwsA(isA<AiModelNotReadyException>()),
    );
    await servingEmbedder.embedOne('question', taskType: EmbedTaskType.query);

    expect(log, ['open serving', 'embed serving']);
    await servingEmbedder.release();
  });
}
