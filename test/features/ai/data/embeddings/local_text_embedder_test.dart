import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/embeddings/embedder_adapter.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_spec.dart';
import 'package:inkflow/features/ai/data/embeddings/local_text_embedder.dart';
import 'package:inkflow/features/ai/data/llm/llm_exceptions.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

const _spec = EmbedderSpec(
  displayName: 'Fake Embedder',
  modelId: 'fake-v1',
  modelUrl: 'https://example.com/model.tflite',
  tokenizerUrl: 'https://example.com/sentencepiece.model',
  approxSizeBytes: 1024,
  dimensions: 3,
  needsAuth: true,
);

class _FakeSession implements EmbeddingSession {
  _FakeSession({this.vectorsFor, this.throws});

  final List<List<double>> Function(List<String> texts)? vectorsFor;
  final Object? throws;

  var closed = false;
  final calls = <({List<String> texts, EmbedTaskType taskType})>[];

  @override
  Future<List<List<double>>> embedAll(
    List<String> texts, {
    required EmbedTaskType taskType,
  }) async {
    calls.add((texts: texts, taskType: taskType));
    if (throws != null) throw throws!;
    return vectorsFor?.call(texts) ??
        [
          for (final _ in texts) const [1.0, 0.0, 0.0]
        ];
  }

  @override
  Future<void> close() async => closed = true;
}

class _FakeRuntime implements EmbeddingRuntime {
  _FakeRuntime({this.session, this.openThrows});

  final _FakeSession? session;
  final Object? openThrows;

  var openCount = 0;

  /// Set to observe how many sessions are open at once (mutex proof).
  Completer<void>? gate;

  @override
  Future<EmbeddingSession> open(EmbedderSpec spec) async {
    if (openThrows != null) throw openThrows!;
    openCount++;
    if (gate != null) await gate!.future;
    return session ?? _FakeSession();
  }
}

void main() {
  test('an empty batch returns nothing without loading the model', () async {
    final runtime = _FakeRuntime();
    final embedder = LocalTextEmbedder(spec: _spec, runtime: runtime);

    expect(await embedder.embedAll([], taskType: EmbedTaskType.document),
        isEmpty);
    expect(runtime.openCount, 0, reason: 'loading 175 MB to embed nothing');
  });

  test('the model is unloaded after a successful batch', () async {
    final session = _FakeSession();
    final embedder =
        LocalTextEmbedder(spec: _spec, runtime: _FakeRuntime(session: session));

    await embedder.embedAll(['a', 'b'], taskType: EmbedTaskType.document);

    expect(session.closed, isTrue);
  });

  test('the model is unloaded even when embedding fails', () async {
    final session = _FakeSession(throws: StateError('native boom'));
    final embedder =
        LocalTextEmbedder(spec: _spec, runtime: _FakeRuntime(session: session));

    await expectLater(
      embedder.embedAll(['a'], taskType: EmbedTaskType.document),
      throwsA(isA<AiGenerationException>()),
    );
    // Nothing may stay resident after a call, least of all after a crash.
    expect(session.closed, isTrue);
  });

  test('the task type reaches the runtime unchanged', () async {
    final session = _FakeSession();
    final embedder =
        LocalTextEmbedder(spec: _spec, runtime: _FakeRuntime(session: session));

    await embedder.embedAll(['a'], taskType: EmbedTaskType.document);
    expect(session.calls.single.taskType, EmbedTaskType.document);
  });

  test('embedOne returns the single vector', () async {
    final embedder = LocalTextEmbedder(
      spec: _spec,
      runtime: _FakeRuntime(
        session: _FakeSession(vectorsFor: (_) => [
              const [0.0, 1.0, 0.0]
            ]),
      ),
    );

    expect(await embedder.embedOne('a', taskType: EmbedTaskType.query),
        [0.0, 1.0, 0.0]);
  });

  test('a missing model surfaces as AiModelNotReadyException', () async {
    final embedder = LocalTextEmbedder(
      spec: _spec,
      runtime: _FakeRuntime(openThrows: LlmNotReadyException()),
    );

    await expectLater(
      embedder.embedAll(['a'], taskType: EmbedTaskType.query),
      throwsA(isA<AiModelNotReadyException>()),
    );
  });

  test('a wrong-sized vector is rejected instead of stored', () async {
    final embedder = LocalTextEmbedder(
      spec: _spec,
      runtime: _FakeRuntime(
        session: _FakeSession(vectorsFor: (_) => [
              const [1.0, 0.0] // 2 dims, spec says 3
            ]),
      ),
    );

    // cosineSimilarity treats a length mismatch as "unrelated" (0.0) rather
    // than throwing, so without this check a corrupt batch would persist and
    // present as "search silently finds nothing".
    await expectLater(
      embedder.embedAll(['a'], taskType: EmbedTaskType.document),
      throwsA(isA<AiGenerationException>()),
    );
  });

  test('a short batch is rejected instead of misaligned', () async {
    final embedder = LocalTextEmbedder(
      spec: _spec,
      runtime: _FakeRuntime(
        session: _FakeSession(vectorsFor: (_) => [
              const [1.0, 0.0, 0.0]
            ]),
      ),
    );

    // Two texts in, one vector out: silently pairing them would attach chunk
    // 0's vector to chunk 1.
    await expectLater(
      embedder.embedAll(['a', 'b'], taskType: EmbedTaskType.document),
      throwsA(isA<AiGenerationException>()),
    );
  });

  test('concurrent calls never load two models at once', () async {
    final runtime = _FakeRuntime()..gate = Completer<void>();
    final embedder = LocalTextEmbedder(spec: _spec, runtime: runtime);

    final first = embedder.embedAll(['a'], taskType: EmbedTaskType.document);
    final second = embedder.embedAll(['b'], taskType: EmbedTaskType.document);
    await Future<void>.delayed(Duration.zero);

    expect(runtime.openCount, 1,
        reason: 'the second call must wait for the first to unload');

    runtime.gate!.complete();
    await Future.wait([first, second]);
    expect(runtime.openCount, 2);
  });

  test('modelId and dimensions come from the spec', () {
    final embedder = LocalTextEmbedder(spec: _spec, runtime: _FakeRuntime());
    expect(embedder.modelId, 'fake-v1');
    expect(embedder.dimensions, 3);
  });
}
