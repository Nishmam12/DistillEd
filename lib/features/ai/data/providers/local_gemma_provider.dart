// On-device Gemma as an [AiProvider] (Tier 1 of the multi-tier plan).
//
// Bridges the two halves of the AI stack: the provider-agnostic platform
// contract (`features/ai/domain/ai_provider.dart`, Loop 0.1) and the proven
// local runtime seams (`gemma_adapter.dart`, ported from main), while adding
// the streaming shape the platform requires (`session.respondStream` →
// incremental token chunks).
//
// MEMORY: at most one model is ever resident, serialized by a mutex so two
// loads can never overlap. Residency is now scoped to a burst of work rather
// than a single call: every call opens and closes its OWN session, but the
// model stays loaded and is released [idleUnloadDelay] after the last one
// finishes. The per-call unload it replaces was correct but pathological for
// the page-analysis path, which makes 12+ calls back to back and paid a full
// multi-second model rebuild for each (measured 3.6s–17.2s per rebuild on a
// Xiaomi Pad 7). Nothing stays resident once the app goes quiet.
//
// Failures surface as typed [AiException]s so the router/UI can branch on the
// kind (offer the model download, route elsewhere) without string-matching.

import 'dart:async';
import 'dart:typed_data';

import '../../domain/ai_provider.dart';
import '../../domain/image_transcriber.dart';
import '../../domain/rag/text_embedder.dart';
import '../llm/gemma_adapter.dart';
import '../llm/llm_exceptions.dart';
import '../llm/llm_model_spec.dart';

class LocalGemmaProvider implements AiProvider, ImageTranscriber {
  /// Generation must produce a first/next chunk within this long, or the call
  /// fails — guards against a wedged native decode holding the mutex forever.
  static const Duration interChunkTimeout = Duration(minutes: 2);

  /// A single image transcription (model load + vision inference) must finish
  /// within this long. Generous — a tablet loading the 2.4 GB model then reading
  /// a page can take a while — but bounded, so a wedged read can't hold the mutex
  /// forever and silently block every later re-read.
  static const Duration transcribeTimeout = Duration(minutes: 3);

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
  /// whole stream so the load→generate lifecycle never overlaps.
  Future<void> _lock = Future.value();

  /// How long the model stays loaded after the last call finishes.
  ///
  /// Long enough to cover the gaps inside one page analysis (its calls run
  /// back to back), short enough that an idle app is not sitting on gigabytes.
  static const Duration idleUnloadDelay = Duration(seconds: 30);

  Timer? _idleUnload;

  /// Cancels a pending unload — a new call is about to use the model.
  void _cancelIdleUnload() {
    _idleUnload?.cancel();
    _idleUnload = null;
  }

  /// Arms the unload. Called after a session closes, while the mutex is still
  /// held, so it can never race a call that is already running.
  void _armIdleUnload() {
    _idleUnload?.cancel();
    _idleUnload = Timer(idleUnloadDelay, () {
      _idleUnload = null;
      // Fire-and-forget: an unload failure is not something a caller can act
      // on, and the next open() rebuilds regardless.
      unawaited(_runtime.releaseModel().catchError((Object _) {}));
    });
  }

  /// Unloads the model now, without waiting for the idle timer.
  ///
  /// For callers that know no further generation is coming (app backgrounded,
  /// AI surfaces disposed) and want the memory back immediately.
  Future<void> releaseModel() async {
    _cancelIdleUnload();
    await _runtime.releaseModel();
  }

  @override
  AiCapabilities get capabilities => AiCapabilities(
        modelId: spec.filename,
        displayName: spec.displayName,
        contextWindowTokens: spec.maxTokens,
        supportsStreaming: true,
        // Gemma 4 E2B ships a vision encoder; [transcribeImage] loads it on
        // demand. Text generation ([generate]) still runs the model text-only.
        supportsVision: true,
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
    _cancelIdleUnload();
    try {
      yield* _generate(
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: history ?? const [],
        opts: opts,
      );
    } finally {
      _armIdleUnload();
      gate.complete();
    }
  }

  @override
  Future<String> transcribeImage(
    Uint8List imageBytes, {
    required String prompt,
    double temperature = 0.0,
    int maxOutputTokens = 1024,
    int? randomSeed,
  }) async {
    // Same mutex as [generate]: transcription and generation both load THIS
    // model, so they must never overlap (two 2.4 GB loads would OOM). A
    // transcription in flight makes a concurrent Summarize wait, and vice
    // versa — serialized, never parallel.
    final previous = _lock;
    final gate = Completer<void>();
    _lock = gate.future;
    await previous;
    _cancelIdleUnload();
    try {
      return await _transcribe(
          imageBytes, prompt, temperature, maxOutputTokens, randomSeed);
    } finally {
      _armIdleUnload();
      gate.complete();
    }
  }

  Future<String> _transcribe(
    Uint8List imageBytes,
    String prompt,
    double temperature,
    int maxOutputTokens,
    int? randomSeed,
  ) async {
    final LlmSession session;
    try {
      session = await _runtime.open(
        spec: spec,
        temperature: temperature,
        // Greedy at temperature 0 (deterministic transcription); otherwise
        // Gemma's conventional top-k so a retry can escape a bad greedy path.
        topK: temperature == 0.0 ? 1 : 40,
        topP: 0.95,
        maxOutputTokens: maxOutputTokens,
        // Carries the caller's seed so a re-read samples differently; null lets
        // the runtime use its fixed default (fine for the deterministic pass).
        randomSeed: randomSeed,
        supportImage: true,
      );
    } on LlmNotReadyException catch (e) {
      throw AiModelNotReadyException(
        'The on-device model is not downloaded yet.',
        cause: e,
      );
    } on LlmException catch (e) {
      throw AiGenerationException('Local vision model failed to start.',
          cause: e);
    }

    try {
      final text = await session
          .respondWithImage(prompt, imageBytes)
          .timeout(transcribeTimeout);
      return text.trim();
    } on AiException {
      rethrow;
    } catch (e) {
      // getResponse() surfaces plugin errors that aren't LlmException, and a
      // TimeoutException lands here too; either way a failed/hung read is a
      // generation failure, not a missing model.
      throw AiGenerationException('Local vision model failed to read the image.',
          cause: e);
    } finally {
      // Close the conversation no matter what. The MODEL stays loaded for
      // [idleUnloadDelay] so a burst of calls does not rebuild it each time.
      await session.close();
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
      // Close the conversation no matter what. The MODEL stays loaded for
      // [idleUnloadDelay] so a burst of calls does not rebuild it each time.
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
