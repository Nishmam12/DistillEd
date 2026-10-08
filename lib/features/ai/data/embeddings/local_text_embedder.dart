// EmbeddingGemma behind the domain's [TextEmbedder] seam.
//
// Mirrors [LocalGemmaProvider]'s memory discipline: calls are serialized by the
// embedder slot ([EmbedderSlot]), and the model stays loaded for [idleUnloadDelay] after the last one
// rather than being rebuilt per call. It used to load and unload around every
// batch, which put a model load in front of every "Ask your notes" question and
// every page of a bulk index; at ~175 MB it is cheap enough to hold through a
// burst of work. Nothing stays resident once the app goes quiet.
//
// The slot is shared by the app's embedders but NOT with the LLM's — a deliberate
// refinement of the "at most one model resident" invariant to "at most one of
// each". Sharing one lock across both would strictly cap residency, but it
// would also park a user-waiting Summarize behind a background re-index, which
// is the worse failure: the embedder is ~170 MB next to the LLM's ~2.4 GB, so
// the concurrency costs ~7% peak memory on an 8 GB target and buys a UI that
// never stalls on background work.

import 'dart:async';

import '../../domain/ai_provider.dart';
import '../../domain/rag/prompt_contract.dart';
import '../../domain/rag/text_embedder.dart';
import '../llm/llm_exceptions.dart';
import 'embedder_adapter.dart';
import 'embedder_slot.dart';
import 'embedder_spec.dart';

class LocalTextEmbedder implements TextEmbedder, EmbedderSlotOwner {
  /// How long the model stays loaded after the last call finishes.
  static const Duration defaultIdleUnloadDelay = Duration(seconds: 60);

  final EmbedderSpec spec;
  final EmbeddingRuntime _runtime;
  final Duration idleUnloadDelay;
  final EmbedderSlot _slot;

  LocalTextEmbedder({
    this.spec = EmbedderSpec.active,
    EmbeddingRuntime? runtime,
    this.idleUnloadDelay = defaultIdleUnloadDelay,
    EmbedderSlot? slot,
  })  : _runtime = runtime ?? embeddingRuntimeFor(spec),
        _slot = slot ?? EmbedderSlot.shared;

  /// The loaded model, or null when nothing is resident.
  EmbeddingSession? _session;
  Timer? _idleUnload;

  void _armIdleUnload() {
    _idleUnload?.cancel();
    _idleUnload = Timer(idleUnloadDelay, () {
      _idleUnload = null;
      unawaited(_slot.run(() async {
        // A call that ran between the timer firing and this getting the lock
        // re-armed it; that call's own window applies.
        if (_idleUnload == null) await _unload();
      }));
    });
  }

  Future<void> _unload() async {
    final session = _session;
    _session = null;
    _slot.released(this);
    await session?.close();
  }

  /// Unloads the model now, without waiting for the idle timer. Safe to call
  /// when nothing is loaded.
  Future<void> release() {
    _idleUnload?.cancel();
    _idleUnload = null;
    return _slot.run(_unload);
  }

  /// Another embedder is about to load, so this one gives its model up. It is
  /// already inside the slot, so this does not take the slot again.
  @override
  Future<void> releaseFromSlot() async {
    _idleUnload?.cancel();
    _idleUnload = null;
    await _unload();
  }

  @override
  String get modelId => spec.modelId;

  @override
  int get dimensions => spec.dimensions;

  @override
  PromptContract get promptContract => spec.promptContract;

  @override
  int get chunkWords => spec.chunkWords;

  @override
  int get chunkOverlapWords => spec.chunkOverlapWords;

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
    // Before the slot: nothing to embed must not queue behind a 175 MB load,
    // and must not perform one either.
    if (texts.isEmpty) return const [];
    return _slot.run(() => _embedAll(texts, taskType));
  }

  /// Loads the model once the slot has released whichever embedder held it. A
  /// failed load gives the slot back at once.
  Future<EmbeddingSession> _openSession() async {
    await _slot.claim(this);
    try {
      return await _runtime.open(spec);
    } catch (_) {
      _slot.released(this);
      rethrow;
    }
  }

  Future<List<List<double>>> _embedAll(
    List<String> texts,
    EmbedTaskType taskType,
  ) async {
    _idleUnload?.cancel();
    _idleUnload = null;

    final EmbeddingSession session;
    try {
      session = _session ??= await _openSession();
    } on LlmNotReadyException catch (e) {
      throw AiModelNotReadyException(
        '${spec.displayName} is not downloaded yet.',
        cause: e,
      );
    } on EmbedderRuntimeUnsupportedException catch (e) {
      throw AiModelNotReadyException(e.message, cause: e);
    } on LlmException catch (e) {
      throw AiGenerationException(
        '${spec.displayName} failed to start.',
        cause: e,
      );
    }

    try {
      final vectors = await session.embedAll(texts, taskType: taskType);
      _verifyShape(vectors, texts.length);
      _armIdleUnload();
      return vectors;
    } on AiException {
      await _unload();
      rethrow;
    } catch (e) {
      await _unload();
      throw AiGenerationException('Embedding failed.', cause: e);
    }
    // Success keeps the model for the next call; a failure drops it, so a
    // session that just misbehaved is never kept warm for the next caller.
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
