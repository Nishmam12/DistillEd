// On-device Gemma as an [AiProvider] (Tier 1 of the multi-tier plan).
//
// Bridges the two halves of the AI stack: the provider-agnostic platform
// contract (`features/ai/domain/ai_provider.dart`, Loop 0.1) and the proven
// local runtime seams (`gemma_adapter.dart`, ported from main). It preserves
// the runtime's memory invariant — every call loads the model, runs ONE
// generation, and unloads it in a finally block, serialized by a mutex so at
// most one model is ever resident — while adding the streaming shape the
// platform requires (`session.respondStream` → incremental token chunks).
//
// Failures surface as typed [AiException]s so the router/UI can branch on the
// kind (offer the model download, route elsewhere) without string-matching.

import 'dart:async';

import '../../domain/ai_provider.dart';
import '../../domain/rag/text_embedder.dart';
import '../llm/gemma_adapter.dart';
import '../llm/llm_exceptions.dart';
import '../llm/llm_model_spec.dart';

class LocalGemmaProvider implements AiProvider {
  /// Generation must produce a first/next chunk within this long, or the call
  /// fails — guards against a wedged native decode holding the mutex forever.
  static const Duration interChunkTimeout = Duration(minutes: 2);

  final LlmModelSpec spec;
  final LlmRuntime _runtime;

  /// Backs [embed]. Optional because embedding is a SEPARATE model (Phase 2's
  /// EmbeddingGemma) that a caller may not have wired: without it this provider
  /// honestly reports `supportsEmbeddings: false` rather than pretending.
  final TextEmbedder? _embedder;

  LocalGemmaProvider({
    this.spec = LlmModelSpec.active,
    LlmRuntime? runtime,
    TextEmbedder? embedder,
  })  : _runtime = runtime ?? FlutterGemmaRuntime(),
        _embedder = embedder;

  /// Mutex: chain of futures; each call awaits the previous one. Held for the
  /// whole stream so the load→generate→unload lifecycle never overlaps.
  Future<void> _lock = Future.value();

  @override
  AiCapabilities get capabilities => AiCapabilities(
        modelId: spec.filename,
        displayName: spec.displayName,
        contextWindowTokens: spec.maxTokens,
        supportsStreaming: true,
        supportsVision: false, // multimodal exists but is not enabled yet
        supportsEmbeddings: _embedder != null,
        isLocal: true,
        approxCostPerCallUsd: 0.0,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    final opts = options ?? const AiGenerationOptions();

    final previous = _lock;
    final gate = Completer<void>();
    _lock = gate.future;
    await previous;
    try {
      yield* _generate(
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: history ?? const [],
        opts: opts,
      );
    } finally {
      gate.complete();
    }
  }

  Stream<String> _generate({
    required String prompt,
    required String? systemPrompt,
    required List<AiMessage> history,
    required AiGenerationOptions opts,
  }) async* {
    final LlmSession session;
    try {
      session = await _runtime.open(
        spec: spec,
        temperature: opts.temperature,
        // Greedy decoding when temperature is 0 (the `precise` preset);
        // otherwise Gemma's conventional top-k unless the caller overrides.
        topK: opts.topK ?? (opts.temperature == 0.0 ? 1 : 40),
        topP: opts.topP ?? 0.95,
        maxOutputTokens: opts.maxTokens,
        systemInstruction: systemPrompt,
        randomSeed: opts.seed,
      );
    } on LlmNotReadyException catch (e) {
      throw AiModelNotReadyException(
        'The on-device model is not downloaded yet.',
        cause: e,
      );
    } on LlmException catch (e) {
      throw AiGenerationException('Local model failed to start.', cause: e);
    }

    try {
      // System context goes through systemInstruction; replay only the turns.
      for (final message in history) {
        if (message.role == AiRole.system) continue;
        await session.addTurn(message.content,
            isUser: message.role == AiRole.user);
      }

      final chunks = session
          .respondStream(prompt)
          .timeout(interChunkTimeout)
          .handleError(
        (Object e) {
          throw e is LlmException
              ? AiGenerationException('Local model inference failed.',
                  cause: e)
              : e is TimeoutException
                  ? AiGenerationException(
                      'The model produced no output within '
                      '${interChunkTimeout.inSeconds}s.',
                      cause: e)
                  : e;
        },
      );

      if (opts.stopSequences.isEmpty) {
        yield* chunks;
      } else {
        yield* _applyStopSequences(chunks, opts.stopSequences);
      }
    } finally {
      // Unload no matter what — nothing stays resident after a call.
      await session.close();
    }
  }

  /// Truncates the stream at the first stop-sequence match. A match can span
  /// chunk boundaries, so the last (longest stop − 1) characters are held
  /// back until proven safe, and the held-back tail is flushed when the
  /// stream ends without a match.
  static Stream<String> _applyStopSequences(
      Stream<String> chunks, List<String> stopSequences) async* {
    final holdBack =
        stopSequences.map((s) => s.length).reduce((a, b) => a > b ? a : b) - 1;
    final buffer = StringBuffer();
    var emitted = 0;
    var stopped = false;
    await for (final chunk in chunks) {
      buffer.write(chunk);
      final text = buffer.toString();
      final cut = _firstStopIndex(text, stopSequences);
      if (cut != null) {
        if (cut > emitted) yield text.substring(emitted, cut);
        stopped = true;
        break;
      }
      final safeEnd = text.length - holdBack;
      if (safeEnd > emitted) {
        yield text.substring(emitted, safeEnd);
        emitted = safeEnd;
      }
    }
    if (!stopped && buffer.length > emitted) {
      yield buffer.toString().substring(emitted);
    }
  }

  /// Index of the earliest stop-sequence match in [text], or null.
  static int? _firstStopIndex(String text, List<String> stopSequences) {
    int? earliest;
    for (final stop in stopSequences) {
      if (stop.isEmpty) continue;
      final i = text.indexOf(stop);
      if (i >= 0 && (earliest == null || i < earliest)) earliest = i;
    }
    return earliest;
  }

  /// The platform contract's single-vector entry point, delegated to the
  /// embedding model (a different model from [spec] — see `text_embedder.dart`).
  ///
  /// Embeds with QUERY semantics, because a one-off `embed(text)` on the
  /// router-facing contract is a search. INDEXING MUST NOT COME THROUGH HERE:
  /// EmbeddingGemma is asymmetric, and storing query-prefixed vectors would
  /// degrade retrieval without failing. Indexing goes through
  /// [TextEmbedder.embedAll] with [EmbedTaskType.document] — which is also the
  /// only way to amortize the model load across a page's chunks.
  @override
  Future<List<double>> embed(String text) async {
    final embedder = _embedder;
    if (embedder == null) {
      throw const AiUnsupportedOperationException(
        'This provider was built without an embedder. Construct it with '
        'LocalGemmaProvider(embedder: ...) to enable embeddings.',
      );
    }
    return embedder.embedOne(text, taskType: EmbedTaskType.query);
  }
}
