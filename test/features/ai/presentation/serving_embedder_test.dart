// The model that answers questions is the one the rollout says is serving
// (docs/TECH_MIGRATION_PLAN.md, phase 4.5): the active model until a switch, then
// the model the switch made serving.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/ai/data/embeddings/embedder_spec.dart';
import 'package:margo/features/ai/domain/rag/embedder_rollout.dart';
import 'package:margo/features/ai/presentation/ai_providers.dart';

ProviderContainer _containerWith(EmbedderRollout rollout) {
  final container = ProviderContainer(overrides: [
    embedderRolloutStatusProvider.overrideWith((ref) => Stream.value(rollout)),
  ]);
  // A stream provider pauses its stream while nothing listens, so a read alone
  // never sees the value. The app keeps a listener through the providers that
  // watch the rollout; the test keeps one here.
  container.listen(embedderRolloutStatusProvider, (_, _) {});
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('with no switch made, questions use the active model', () async {
    final container = _containerWith(
        EmbedderRollout(servingModelId: EmbedderSpec.active.modelId));
    await container.read(embedderRolloutStatusProvider.future);

    expect(container.read(textEmbedderProvider).modelId,
        EmbedderSpec.active.modelId);
  });

  test('until a switch completes, questions use the model still serving',
      () async {
    final serving = EmbedderSpec.embeddingGemma300m.modelId;
    final container = _containerWith(EmbedderRollout(servingModelId: serving));
    await container.read(embedderRolloutStatusProvider.future);

    expect(container.read(textEmbedderProvider).modelId, serving);
  });

  test(
      'a serving model no spec has is an error, not a fallback to the active model',
      () async {
    final container =
        _containerWith(const EmbedderRollout(servingModelId: 'no-such-model'));
    await container.read(embedderRolloutStatusProvider.future);

    expect(() => container.read(textEmbedderProvider), throwsA(anything));
  });
}
