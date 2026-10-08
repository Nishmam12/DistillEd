// What the app calls its embedding files has to be what flutter_edge_ai records
// them as: "is the model installed?" is answered by those names. From
// flutter_gemma 1.5 the tokenizer is filed under a name that carries its model's
// id (`<model>__sentencepiece.model`), so a hand-derived `sentencepiece.model`
// reads "not installed" for a model that is sitting on the disk.

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_spec.dart';

void main() {
  test('the filenames the app looks for are the ones the plugin installs under',
      () {
    const spec = EmbedderSpec.active;
    final installed = EmbeddingModelSpec(
      name: spec.modelFilename,
      modelSource: ModelSource.network(spec.modelUrl),
      tokenizerSource: ModelSource.network(spec.tokenizerUrl),
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
}
