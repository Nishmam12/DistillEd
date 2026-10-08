// What the app registers with flutter_edge_ai at startup. The plugin opts every
// engine and tokenizer in explicitly, and forgetting one is silent until a device
// uses it: leave out the embedding tokenizers and the first embedding throws a
// StateError — which is what upgrading 1.3 → 1.11 would have done, since
// tokenizers used to ship inside the engine. FlutterEdgeAi.initialize itself needs
// a device, so the list is a value that can be checked.

import 'package:flutter_edge_ai_embeddings/flutter_edge_ai_embeddings.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_edge_ai_speech/flutter_edge_ai_speech.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';

void main() {
  const registrations = GemmaBootstrap.registrations;

  test('the on-device LLM engine is registered', () {
    expect(registrations.inferenceEngines.whereType<LiteRtLmEngine>(),
        isNotEmpty);
  });

  test('the embedding engine is registered', () {
    expect(registrations.embeddingBackends.whereType<LiteRtEmbeddingBackend>(),
        isNotEmpty);
  });

  test('the embedding tokenizers are registered — or the first embedding throws',
      () {
    expect(
        registrations.embeddingTokenizers.whereType<GemmaEmbeddingTokenizers>(),
        isNotEmpty);
  });

  test('speech-to-text is registered, for lecture transcripts', () {
    expect(registrations.sttBackends.whereType<LiteRtSttBackend>(), isNotEmpty);
  });
}
