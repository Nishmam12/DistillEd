import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/embeddings/embedder_adapter.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_spec.dart';
import 'package:inkflow/features/ai/data/embeddings/local_text_embedder.dart';
import 'package:inkflow/features/ai/data/llm/llm_exceptions.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/rag/prompt_contract.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

const _spec = EmbedderSpec(
  displayName: 'Fake Embedder',
  modelId: 'fake-v1-titled',
  modelUrl: 'https://example.com/model.tflite',
  tokenizerUrl: 'https://example.com/sentencepiece.model',
  format: EmbedderFormat.tfliteWithTokenizer,
  maxInputTokens: 512,
  chunkWords: 250,
  chunkOverlapWords: 30,
  promptContract: PromptContract.pluginGemma300m,
  runtimeSupported: true,
  approxSizeBytes: 1024,
  dimensions: 3,
  needsAuth: true,
);

/// Long enough that a test never sees an unload it didn't ask for.
const _longIdle = Duration(minutes: 5);

class _FakeSession implements EmbeddingSession {
  _FakeSession({this.vectorsFor, this.throws});

  final List<List<double>> Function(List<String> texts)? vectorsFor;
  final Object? throws;

  /// When set, [close] begins (flipping [closed]) but does not finish until
  /// this completes — a model that takes a while to tear down.
  Completer<void>? closeGate;

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
  Future<void> close() async {
    closed = true;
    await closeGate?.future;
  }
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

  group('residency', () {
    test('the model stays loaded after a batch and the next call reuses it',
        () async {
      final session = _FakeSession();
      final runtime = _FakeRuntime(session: session);
      final embedder = LocalTextEmbedder(
          spec: _spec, runtime: runtime, idleUnloadDelay: _longIdle);

      await embedder.embedAll(['a', 'b'], taskType: EmbedTaskType.document);
      await embedder.embedOne('q', taskType: EmbedTaskType.query);

      // One load for the whole burst — the point of holding a ~175 MB model:
      // every question and every page of a bulk index used to pay its own.
      expect(runtime.openCount, 1);
      expect(session.closed, isFalse);
      expect(session.calls, hasLength(2));
      await embedder.release();
    });

    test('the model unloads once the embedder has been idle for the delay',
        () async {
      final session = _FakeSession();
      final embedder = LocalTextEmbedder(
          spec: _spec,
          runtime: _FakeRuntime(session: session),
          idleUnloadDelay: const Duration(milliseconds: 40));

      await embedder.embedAll(['a'], taskType: EmbedTaskType.document);
      expect(session.closed, isFalse, reason: 'still resident right after');

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(session.closed, isTrue);
    });

    test('a call inside the idle window postpones the unload', () async {
      final session = _FakeSession();
      final embedder = LocalTextEmbedder(
          spec: _spec,
          runtime: _FakeRuntime(session: session),
          idleUnloadDelay: const Duration(milliseconds: 120));

      await embedder.embedAll(['a'], taskType: EmbedTaskType.document);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await embedder.embedAll(['b'], taskType: EmbedTaskType.document);
      // 160 ms after the first call: its timer would have fired at 120 ms, but
      // the second call re-armed it, so the model must still be loaded.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(session.closed, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(session.closed, isTrue);
    });

    test('release() unloads now, and a later call loads again', () async {
      final session = _FakeSession();
      final runtime = _FakeRuntime(session: session);
      final embedder = LocalTextEmbedder(
          spec: _spec, runtime: runtime, idleUnloadDelay: _longIdle);

      await embedder.embedAll(['a'], taskType: EmbedTaskType.document);
      await embedder.release();
      expect(session.closed, isTrue);

      await embedder.embedAll(['b'], taskType: EmbedTaskType.document);
      expect(runtime.openCount, 2);
      await embedder.release();
    });

    test('a call that arrives while the idle unload is closing waits for it',
        () async {
      final closeGate = Completer<void>();
      final session = _FakeSession()..closeGate = closeGate;
      final runtime = _FakeRuntime(session: session);
      final embedder = LocalTextEmbedder(
          spec: _spec,
          runtime: runtime,
          idleUnloadDelay: const Duration(milliseconds: 30));

      await embedder.embedAll(['a'], taskType: EmbedTaskType.document);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(session.closed, isTrue, reason: 'the idle unload has begun');

      final second =
          embedder.embedAll(['b'], taskType: EmbedTaskType.document);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      // The plugin hands back its cached instance until the old one finishes
      // closing, so loading now would wrap a model that is mid-teardown.
      expect(runtime.openCount, 1);

      closeGate.complete();
      await second;
      expect(runtime.openCount, 2);
      await embedder.release();
    });

    test('a failed batch unloads at once and the next call opens afresh',
        () async {
      final bad = _FakeSession(throws: StateError('native boom'));
      final runtime = _FakeRuntime(session: bad);
      final embedder = LocalTextEmbedder(
          spec: _spec, runtime: runtime, idleUnloadDelay: _longIdle);

      await expectLater(
        embedder.embedAll(['a'], taskType: EmbedTaskType.document),
        throwsA(isA<AiGenerationException>()),
      );
      // A session that just crashed is not kept warm for the next caller.
      expect(bad.closed, isTrue);

      await expectLater(
        embedder.embedAll(['b'], taskType: EmbedTaskType.document),
        throwsA(isA<AiGenerationException>()),
      );
      expect(runtime.openCount, 2);
    });
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
    final embedder = LocalTextEmbedder(
        spec: _spec, runtime: runtime, idleUnloadDelay: _longIdle);

    final first = embedder.embedAll(['a'], taskType: EmbedTaskType.document);
    final second = embedder.embedAll(['b'], taskType: EmbedTaskType.document);
    await Future<void>.delayed(Duration.zero);

    expect(runtime.openCount, 1,
        reason: 'the second call must wait for the first, not open its own');

    runtime.gate!.complete();
    await Future.wait([first, second]);
    // ...and once it runs it reuses the model the first call loaded.
    expect(runtime.openCount, 1);
    await embedder.release();
  });

  test('modelId and dimensions come from the spec', () {
    final embedder = LocalTextEmbedder(spec: _spec, runtime: _FakeRuntime());
    expect(embedder.modelId, 'fake-v1-titled');
    expect(embedder.dimensions, 3);
  });
}
