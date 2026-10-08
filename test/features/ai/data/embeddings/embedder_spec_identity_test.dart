// What the app calls its embedding files has to be what flutter_edge_ai records
// them as: "is the model installed?" is answered by those names. From
// flutter_gemma 1.5 the tokenizer is filed under a name that carries its model's
// id (`<model>__sentencepiece.model`), so a hand-derived `sentencepiece.model`
// reads "not installed" for a model that is sitting on the disk.
//
// The registry rules below are the phase 4.2 contract: a model's id names its
// vector space, so two different vector spaces never share one, and an index
// built under one id is never read as another.

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_spec.dart';
import 'package:inkflow/features/ai/domain/rag/prompt_contract.dart';

void main() {
  test('the filenames the app looks for are the ones the plugin installs under',
      () {
    const spec = EmbedderSpec.active;
    final installed = EmbeddingModelSpec(
      name: spec.modelFilename,
      modelSource: ModelSource.network(spec.modelUrl),
      tokenizerSource: ModelSource.network(spec.tokenizerUrl!),
    ).files;

    expect(spec.modelFilename, installed[0].filename);
    expect(spec.tokenizerFilename, installed[1].filename);
  });

  test('the tokenizer is named for its model, as the plugin files it', () {
    // Pinned to the literal as well, so a plugin that changes the scheme again
    // is noticed here rather than as an embedder that stops being recognised.
    expect(
      EmbedderSpec.active.tokenizerFilename,
      'embeddinggemma-300M_seq512_mixed-precision__sentencepiece.model',
    );
  });

  group('the registry', () {
    test('the 300M model keeps its id, so no existing index is invalidated',
        () {
      expect(EmbedderSpec.active.modelId, 'embeddinggemma-300m-seq512-titled');
    });

    test('the active spec is in the registry and this build can run it', () {
      expect(EmbedderSpec.all, contains(EmbedderSpec.active));
      expect(EmbedderSpec.active.runtimeSupported, isTrue);
    });

    test('every modelId names its prompt contract', () {
      for (final spec in EmbedderSpec.all) {
        expect(spec.modelId, contains(spec.promptContract.id),
            reason: spec.displayName);
      }
    });

    test('specs with different vector-space values never share a modelId', () {
      for (final a in EmbedderSpec.all) {
        for (final b in EmbedderSpec.all) {
          if (a.identityKey != b.identityKey) {
            expect(a.modelId, isNot(b.modelId),
                reason: '${a.displayName} and ${b.displayName}');
          }
        }
      }
    });

    test('no two specs install the same file', () {
      final owner = <String, String>{};
      for (final spec in EmbedderSpec.all) {
        for (final file in spec.files) {
          expect(owner.containsKey(file), isFalse,
              reason: '$file: ${spec.displayName} and ${owner[file]}');
          owner[file] = spec.displayName;
        }
      }
    });

    test('a tflite spec installs a model and its tokenizer; a bundle one file',
        () {
      for (final spec in EmbedderSpec.all) {
        final expected =
            spec.format == EmbedderFormat.tfliteWithTokenizer ? 2 : 1;
        expect(spec.files, hasLength(expected), reason: spec.displayName);
      }
    });

    test('the EmbeddingGemma 2 spec is not runnable, and has no contract yet',
        () {
      expect(EmbedderSpec.embeddingGemma2.runtimeSupported, isFalse);
      expect(EmbedderSpec.embeddingGemma2.promptContract.appliedBy,
          PromptAppliedBy.undecided);
    });
  });
}
