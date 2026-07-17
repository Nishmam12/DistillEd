// EmbeddingGemma behind the domain's [TextEmbedder] seam.
//
// Mirrors [LocalGemmaProvider]'s memory discipline: every call loads the model,
// embeds ONE batch, and unloads it in a finally block, serialized by a mutex.
//
// The mutex is this embedder's OWN, not shared with the LLM's — a deliberate
// refinement of the "at most one model resident" invariant to "at most one of
// each". Sharing one lock across both would strictly cap residency, but it
// would also park a user-waiting Summarize behind a background re-index, which
// is the worse failure: the embedder is ~170 MB next to the LLM's ~2.4 GB, so
// the concurrency costs ~7% peak memory on an 8 GB target and buys a UI that
// never stalls on background work.

import 'dart:async';

import '../../domain/ai_provider.dart';
import '../../domain/rag/text_embedder.dart';
import '../llm/llm_exceptions.dart';
import 'embedder_adapter.dart';
import 'embedder_spec.dart';

class LocalTextEmbedder implements TextEmbedder {
  final EmbedderSpec spec;
  final EmbeddingRuntime _runtime;

  LocalTextEmbedder({
    this.spec = EmbedderSpec.active,
    EmbeddingRuntime? runtime,
  }) : _runtime = runtime ?? FlutterGemmaEmbeddingRuntime();

  /// Mutex: chain of futures; each call awaits the previous one.
  Future<void> _lock = Future.value();

  @override
  String get modelId => spec.modelId;

  @override
  int get dimensions => spec.dimensions;

  @override
  Future<List<double>> embedOne(
    String text, {
    required EmbedTaskType taskType,
  }) async {
    final vectors = await embedAll([text], taskType: taskType);
    return vectors.first;
  }

  @override
  Future<List<List<double>>> embedAll(
    List<String> texts, {
    required EmbedTaskType taskType,
  }) async {
    // Before the mutex: nothing to embed must not queue behind a 175 MB load,
    // and must not perform one either.
    if (texts.isEmpty) return const [];

    final previous = _lock;
    final gate = Completer<void>();
    _lock = gate.future;
    await previous;
    try {
      return await _embedAll(texts, taskType);
    } finally {
      gate.complete();
    }
  }

  Future<List<List<double>>> _embedAll(
    List<String> texts,
    EmbedTaskType taskType,
  ) async {
    final EmbeddingSession session;
    try {
      session = await _runtime.open(spec);
    } on LlmNotReadyException catch (e) {
      throw AiModelNotReadyException(
        '${spec.displayName} is not downloaded yet.',
        cause: e,
      );
    } on LlmException catch (e) {
      throw AiGenerationException(
        '${spec.displayName} failed to start.',
        cause: e,
      );
    }

    try {
      final vectors = await session.embedAll(texts, taskType: taskType);
      _verifyShape(vectors, texts.length);
      return vectors;
    } on AiException {
      rethrow;
    } catch (e) {
      throw AiGenerationException('Embedding failed.', cause: e);
    } finally {
      // Unload no matter what — nothing stays resident after a call.
      await session.close();
    }
  }

  /// Checks the native layer returned what was asked for.
  ///
  /// Worth the cycles because the failure is otherwise INVISIBLE: a wrong
  /// dimension makes [cosineSimilarity] return 0.0 for every comparison (it
  /// treats mismatched lengths as "unrelated" rather than throwing), so a
  /// corrupt batch would present as "search quietly finds nothing" — with the
  /// bad vectors already persisted.
  void _verifyShape(List<List<double>> vectors, int expectedCount) {
    if (vectors.length != expectedCount) {
      throw AiGenerationException(
        '${spec.displayName} returned ${vectors.length} vectors for '
        '$expectedCount inputs.',
      );
    }
    for (final vector in vectors) {
      if (vector.length != spec.dimensions) {
        throw AiGenerationException(
          '${spec.displayName} returned a ${vector.length}-dimension vector; '
          'expected ${spec.dimensions}.',
        );
      }
    }
  }
}
