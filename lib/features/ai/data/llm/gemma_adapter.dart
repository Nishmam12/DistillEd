// Thin seams over flutter_edge_ai's static API so ModelDownloadManager and
// LocalLlmService stay unit-testable (the plugin itself needs a device).
//
// FlutterEdgeAi.initialize is performed lazily on first use (single-flight)
// instead of at app startup: nothing AI-related loads unless the user actually
// touches the Summarize feature, and app boot stays fast.

import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_embeddings/flutter_edge_ai_embeddings.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_edge_ai_speech/flutter_edge_ai_speech.dart';

import '../../domain/compute_backend.dart';
import 'llm_exceptions.dart';
import 'llm_model_spec.dart';

class GemmaBootstrap {
  static Future<void>? _init;

  /// Registers the runtimes the app uses. Safe to call repeatedly.
  ///
  /// BOTH engines are registered in this ONE call by necessity, even though
  /// summarization may be the only feature a session ever touches: the
  /// registration lists are opt-in ("core registers NONE by default") and this
  /// future is memoized, so whichever feature initializes first would otherwise
  /// decide what the other can do for the rest of the process. Registration is
  /// just a factory list — neither model is loaded or downloaded here, so the
  /// lazy-init rationale above is preserved.
  ///
  /// • [LiteRtLmEngine] runs `.litertlm` models (the Gemma 4 LLM).
  /// • [LiteRtEmbeddingBackend] runs `.tflite` embedding models (Loop 2.2 RAG).
  /// • [GemmaEmbeddingTokenizers] turns text into the ids that backend consumes.
  ///   Since flutter_gemma 1.9 the engine no longer bundles one, and leaving them
  ///   out makes the first embedding throw.
  /// • [LiteRtSttBackend] runs Whisper / Moonshine for lecture transcripts.
  ///
  /// `initialize` also accepts a global `huggingFaceToken`, deliberately unused:
  /// it would be captured here, on first use, whereas the token is a per-user
  /// setting the user may paste at any time. Tokens are passed per-download
  /// instead (see [EdgeAiEmbedderInstaller]).
  static Future<void> ensureInitialized() => _init ??= FlutterEdgeAi.initialize(
        inferenceEngines: registrations.inferenceEngines,
        embeddingBackends: registrations.embeddingBackends,
        embeddingTokenizers: registrations.embeddingTokenizers,
        sttBackends: registrations.sttBackends,
      );

  /// What is registered, as a value so a test can check nothing was forgotten
  /// (the plugin needs a device; see `gemma_bootstrap_test.dart`).
  static const registrations = (
    inferenceEngines: [LiteRtLmEngine()],
    embeddingBackends: [LiteRtEmbeddingBackend()],
    embeddingTokenizers: [GemmaEmbeddingTokenizers()],
    sttBackends: [LiteRtSttBackend()],
  );
}

/// Installation seam — implemented by [EdgeAiInstaller] in production.
abstract class ModelInstaller {
  Future<bool> isInstalled(String modelId);

  /// Downloads and installs [spec], reporting whole percents via [onProgress].
  ///
  /// [authToken] overrides [LlmModelSpec.authToken] when non-null — the caller
  /// resolves the effective token so the user's live Settings value wins over
  /// whatever the const spec pins.
  Future<void> install({
    required LlmModelSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  });

  Future<void> uninstall(String modelId);
}

class EdgeAiInstaller implements ModelInstaller {
  /// The seams are over the plugin, which needs a device. Each default asks the
  /// plugin; a test answers instead.
  EdgeAiInstaller({
    Future<bool> Function(String filename)? isFileInstalled,
    Future<bool> Function(String filename)? isFileOnDisk,
    Future<void> Function(String filename)? forgetFile,
  })  : _isFileInstalled = isFileInstalled ?? _pluginHas,
        _isFileOnDisk = isFileOnDisk ?? _pluginOnDisk,
        _forgetFile = forgetFile ?? _pluginForget;

  /// The plugin's record for the model, and the disk.
  final Future<bool> Function(String filename) _isFileInstalled;
  final Future<bool> Function(String filename) _isFileOnDisk;

  /// Removes a model's record, and the file if it is still there.
  final Future<void> Function(String filename) _forgetFile;

  static Future<void> _pluginForget(String filename) async {
    await GemmaBootstrap.ensureInitialized();
    await FlutterEdgeAi.uninstallModel(filename);
  }

  static Future<bool> _pluginHas(String filename) async {
    await GemmaBootstrap.ensureInitialized();
    return FlutterEdgeAi.isModelInstalled(filename);
  }

  static Future<bool> _pluginOnDisk(String filename) async {
    await GemmaBootstrap.ensureInitialized();
    return File(await FlutterEdgeAi.getModelPath(filename)).exists();
  }

  /// The record and the file together. A backup restored without the model
  /// file keeps the record, and the download would then be skipped as done.
  @override
  Future<bool> isInstalled(String modelId) async =>
      await _isFileInstalled(modelId) && await _isFileOnDisk(modelId);

  /// The plugin's install skips a model whose record exists, file or no file, so
  /// a record that outlived its file is forgotten first and the download runs.
  /// A file that is on disk is never touched.
  Future<void> forgetStaleRecords(String modelId) async {
    if (await _isFileInstalled(modelId) && !await _isFileOnDisk(modelId)) {
      await _forgetFile(modelId);
    }
  }

  @override
  Future<void> install({
    required LlmModelSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await GemmaBootstrap.ensureInitialized();
    await forgetStaleRecords(spec.filename);
    var builder = FlutterEdgeAi.installModel(
      modelType: spec.modelType,
      fileType: spec.fileType,
    ).fromNetwork(
      spec.downloadUrl,
      token: authToken ?? spec.authToken,
      // EXPLICIT true, not the `null` auto-detect, and the difference is the
      // whole reason a backgrounded download used to die.
      //
      // The plugin gates its notification setup on `foreground == true`
      // (shouldConfigureForegroundNotification), and on Android
      // background_downloader only calls WorkManager.setForeground() once a
      // `running` notification is configured. So on the auto path the
      // `runInForegroundIfFileLargerThan: 500` it sets is a no-op — no
      // notification, no foreground service, no Doze exemption — and this
      // ~2.4 GB transfer ran as an ordinary WorkManager task, which Android
      // kills when the app is backgrounded and hard-fails at the documented
      // 9-minute background limit either way.
      //
      // A kill is not a pause: flutter_edge_ai disables resume for HuggingFace
      // URLs (weak ETags — see ModelDownloadManager's `_authToken` doc), so
      // every interruption costs the entire file and restarts from zero.
      //
      // Costs a persistent "Downloading model" notification for the duration
      // and a runtime POST_NOTIFICATIONS request on first download (the plugin
      // makes it, best-effort behind a 10s timeout; a denial degrades to the
      // old behaviour rather than blocking). Android-only — resolves to a
      // granted no-op on Windows.
      foreground: true,
    );
    if (onProgress != null) builder = builder.withProgress(onProgress);
    if (cancelToken != null) builder = builder.withCancelToken(cancelToken);
    await builder.install();
  }

  @override
  Future<void> uninstall(String modelId) async {
    await GemmaBootstrap.ensureInitialized();
    await FlutterEdgeAi.uninstallModel(modelId);
  }
}

/// A loaded model with one open session. [close] releases BOTH the session
/// and the model weights — after it completes nothing is left in memory.
abstract class LlmSession {
  /// Adds a prior conversation turn WITHOUT triggering generation — used to
  /// replay multi-turn history before [respond]/[respondStream].
  Future<void> addTurn(String text, {required bool isUser});

  Future<String> respond(String prompt);

  /// Streaming variant of [respond]: yields incremental token chunks.
  Stream<String> respondStream(String prompt);

  /// Sends one multimodal turn — [prompt] alongside [imageBytes] (a PNG/JPEG) —
  /// and returns the whole reply. Only sessions opened with `supportImage: true`
  /// can serve this; the default throws so text-only sessions (and test fakes)
  /// need not implement it.
  Future<String> respondWithImage(String prompt, Uint8List imageBytes) =>
      throw UnsupportedError(
          'This session was not opened with image support (supportImage: true).');

  Future<void> close();
}

/// Inference seam — implemented by [EdgeAiRuntime] in production.
abstract class LlmRuntime {
  /// Opens a loaded model with one session. Set [supportImage] to load the
  /// model's vision encoder and enable [LlmSession.respondWithImage];
  /// [maxNumImages] caps images per turn (ignored when text-only).
  ///
  /// The engine is rebuilt whenever [supportImage] / [maxNumImages] differ from
  /// what is loaded, so callers that alternate between the two (text, then
  /// image, then text) should all ask for the same configuration — see
  /// [LlmModelSpec.shareVisionEngine].
  Future<LlmSession> open({
    required LlmModelSpec spec,
    required double temperature,
    required int topK,
    required double topP,
    int? maxOutputTokens,
    String? systemInstruction,
    int? randomSeed,
    bool supportImage = false,
    int maxNumImages = 1,
  });

  /// Unloads the resident model, freeing its weights and accelerator context.
  ///
  /// [LlmSession.close] deliberately does NOT do this — the plugin keeps ONE
  /// model instance cached and hands it to every session, so closing it per
  /// call forced a full multi-second rebuild on the next one. The caller owns
  /// the residency window instead (see [LocalGemmaProvider]'s idle release).
  ///
  /// Safe to call when nothing is loaded.
  Future<void> releaseModel();

  /// Where the model last loaded actually ran, or null before the first load
  /// (or when the plugin does not say). Deliberately survives [releaseModel]:
  /// it is a fact about this device that decisions made while nothing is loaded
  /// — routing, whether to bother with an optional pass — still want.
  ComputeBackend? get activeBackend;
}

/// What [EdgeAiRuntime] asks the plugin for on one load.
typedef GemmaLoadRequest = ({
  int maxTokens,
  PreferredBackend preferredBackend,

  /// Where the vision encoder runs; null for a text-only load. Always stated:
  /// the plugin defaults it to the CPU, whatever the model runs on.
  PreferredBackend? preferredVisionBackend,
  bool supportImage,
  int? maxNumImages,
  bool enableSpeculativeDecoding,
  ActivationDataType? activationDataType,
});

typedef GemmaModelLoader = Future<InferenceModel> Function(
    GemmaLoadRequest request);

class EdgeAiRuntime implements LlmRuntime {
  /// The arguments are seams over the plugin's static API, which needs a
  /// device: production uses the defaults, tests inject fakes so the decisions
  /// below can be exercised without one.
  EdgeAiRuntime({
    Future<void> Function(LlmModelSpec spec)? ensureReady,
    GemmaModelLoader? loadModel,
    Future<void> Function()? closeCachedModel,
  })  : _ensureReady = ensureReady ?? _pluginEnsureReady,
        _loadModel = loadModel ?? _pluginLoadModel,
        _closeCachedModel = closeCachedModel ?? _pluginCloseCachedModel;

  final Future<void> Function(LlmModelSpec spec) _ensureReady;
  final GemmaModelLoader _loadModel;
  final Future<void> Function() _closeCachedModel;

  static Future<void> _pluginEnsureReady(LlmModelSpec spec) async {
    await GemmaBootstrap.ensureInitialized();
    if (!FlutterEdgeAi.hasActiveModel() ||
        !await FlutterEdgeAi.isModelInstalled(spec.filename)) {
      throw LlmNotReadyException();
    }
  }

  static Future<InferenceModel> _pluginLoadModel(GemmaLoadRequest r) =>
      FlutterEdgeAi.getActiveModel(
        maxTokens: r.maxTokens,
        preferredBackend: r.preferredBackend,
        // Loads the vision encoder too (Gemma 4 E2B ships one).
        preferredVisionBackend: r.preferredVisionBackend,
        supportImage: r.supportImage,
        maxNumImages: r.maxNumImages,
        enableSpeculativeDecoding: r.enableSpeculativeDecoding,
        activationDataType: r.activationDataType,
      );

  static Future<void> _pluginCloseCachedModel() async {
    // The plugin owns a single cached instance; closing it fires the internal
    // close-listener that clears the cache, so the next load rebuilds.
    await FlutterEdgeAiPlugin.instance.initializedModel?.close();
  }

  /// The construction parameters of the model instance the plugin currently
  /// has cached, or null when nothing is loaded.
  ///
  /// Tracked here because the ANDROID plugin's cache check compares only the
  /// model's name — unlike the desktop one, which also compares `supportImage`,
  /// `supportAudio` and `maxTokens`. So a request with different parameters
  /// silently receives the previously-built instance.
  ///
  /// That was harmless while every call closed the model afterwards. Once the
  /// model started surviving between calls, it became a correctness bug: a
  /// text-only first call (Summarize) would cache a model with NO vision
  /// encoder, and every page read after it would then be handed that model.
  /// Whoever called first would decide whether images worked for the rest of
  /// the process.
  ({bool supportImage, int? maxNumImages, int maxTokens})? _loadedWith;

  /// The instance last handed back, to tell a fresh load from a cache hit: the
  /// backend checks below belong to a load, not to every call that reuses it.
  InferenceModel? _model;

  ComputeBackend? _activeBackend;

  /// Set once a GPU request has come back running on the CPU.
  ///
  /// The plugin tries the GPU and falls back on its own, so a device whose GPU
  /// can't run the model pays a failed GPU attempt on EVERY load; after the
  /// first one there is no point asking again.
  ///
  /// ponytail: remembered for the whole process, so a one-off GPU failure (say,
  /// memory pressure from other apps) pins this session to the CPU until the app
  /// restarts. Add an expiry if that turns out to bite.
  bool _gpuUnavailable = false;

  @override
  ComputeBackend? get activeBackend => _activeBackend;

  @override
  Future<LlmSession> open({
    required LlmModelSpec spec,
    required double temperature,
    required int topK,
    required double topP,
    int? maxOutputTokens,
    String? systemInstruction,
    int? randomSeed,
    bool supportImage = false,
    int maxNumImages = 1,
  }) async {
    await _ensureReady(spec);

    final wanted = (
      supportImage: supportImage,
      maxNumImages: supportImage ? maxNumImages : null,
      maxTokens: spec.maxTokens,
    );
    // Drop the cached instance ourselves when the parameters differ, since the
    // plugin will not. Same-parameter calls — the overwhelmingly common case,
    // and the whole point of keeping it loaded — still reuse it.
    if (_loadedWith != null && _loadedWith != wanted) {
      await releaseModel();
    }

    final InferenceModel model;
    try {
      model = await _load(spec, wanted);
    } on StateError {
      throw LlmNotReadyException();
    }
    _loadedWith = wanted;

    try {
      final session = await model.createSession(
        temperature: temperature,
        topK: topK,
        topP: topP,
        maxOutputTokens: maxOutputTokens,
        systemInstruction: systemInstruction,
        randomSeed: randomSeed ?? 1, // plugin default
        // Only turn the modality on when asked — a vision session costs more to
        // build even if no image is ever sent.
        enableVisionModality: supportImage ? true : null,
      );
      return _GemmaSession(session);
    } catch (e) {
      // Session creation failed — don't leak the loaded model.
      _loadedWith = null;
      _model = null;
      await model.close();
      throw LlmGenerationException('Could not start the model session.', e);
    }
  }

  /// Gets the model from the plugin, choosing the backend and whether to run
  /// multi-token prediction.
  ///
  /// MTP decodes ~1.6x faster on the GPU but is pure overhead on the CPU, and
  /// which of the two we get is only known once the load has finished — the
  /// plugin falls back on its own. So the first load asks for both, and when the
  /// GPU turns out not to be there the engine is rebuilt on the CPU without the
  /// drafter. That costs a second load, but only on a device whose GPU can't run
  /// the model, and only once: [_gpuUnavailable] sends every later load
  /// straight to the CPU.
  Future<InferenceModel> _load(
    LlmModelSpec spec,
    ({bool supportImage, int? maxNumImages, int maxTokens}) wanted,
  ) async {
    GemmaLoadRequest request(PreferredBackend backend, bool drafter) => (
          maxTokens: wanted.maxTokens,
          preferredBackend: backend,
          // The vision encoder goes where the model does. flutter_gemma 1.3 did
          // that on its own; 1.11 runs it on the CPU unless told otherwise
          // (the Metal/WebGPU delegates cannot prepare it), which on Android
          // would make every image read — the heaviest thing the app does —
          // several times slower than it was measured.
          preferredVisionBackend: wanted.supportImage ? backend : null,
          supportImage: wanted.supportImage,
          maxNumImages: wanted.maxNumImages,
          enableSpeculativeDecoding: drafter,
          // Only the GPU has a lower-precision default to override.
          activationDataType:
              backend == PreferredBackend.gpu ? spec.activationDataType : null,
        );

    final tryGpu = !_gpuUnavailable;
    final drafter = tryGpu && spec.speculativeDecodingOnGpu;
    final watch = Stopwatch()..start();
    InferenceModel model;
    var drafterOn = drafter;
    var retriedOnCpu = false;
    try {
      model = await _loadModel(request(
          tryGpu ? PreferredBackend.gpu : PreferredBackend.cpu, drafter));
    } on StateError {
      rethrow; // no active model: the CPU would not help
    } catch (e) {
      if (!tryGpu) rethrow; // already on the CPU: nothing left to fall back to
      // A GPU delegate that cannot prepare part of the model (the vision
      // encoder, say) fails the whole load instead of quietly falling back. The
      // feature must degrade to the CPU, not die.
      if (kDebugMode) debugPrint('[AiPerf] GPU load failed ($e); retrying on CPU');
      _gpuUnavailable = true;
      model = await _loadModel(request(PreferredBackend.cpu, false));
      drafterOn = false;
      retriedOnCpu = true;
    }
    if (identical(model, _model)) return model; // a cache hit, nothing to learn

    var backend = _computeBackendOf(model.activeBackend) ??
        (retriedOnCpu ? ComputeBackend.cpu : null);
    if (tryGpu && backend == ComputeBackend.cpu) {
      _gpuUnavailable = true;
      if (drafterOn) {
        await _closeCachedModel();
        model = await _loadModel(request(PreferredBackend.cpu, false));
        backend = _computeBackendOf(model.activeBackend);
        drafterOn = false;
      }
    }

    _model = model;
    _activeBackend = backend;
    if (kDebugMode) {
      debugPrint('[AiPerf] model load ${watch.elapsedMilliseconds}ms '
          'backend=${backend?.name ?? 'unknown'} drafter=$drafterOn '
          'vision=${wanted.supportImage}');
    }
    return model;
  }

  static ComputeBackend? _computeBackendOf(PreferredBackend? backend) =>
      switch (backend) {
        null => null,
        PreferredBackend.gpu => ComputeBackend.gpu,
        PreferredBackend.npu => ComputeBackend.npu,
        PreferredBackend.cpu => ComputeBackend.cpu,
      };

  @override
  Future<void> releaseModel() async {
    _loadedWith = null;
    _model = null;
    await _closeCachedModel();
  }
}

class _GemmaSession implements LlmSession {
  final InferenceModelSession _session;
  _GemmaSession(this._session);

  @override
  Future<void> addTurn(String text, {required bool isUser}) =>
      _session.addQueryChunk(Message.text(text: text, isUser: isUser));

  @override
  Future<String> respond(String prompt) async {
    await _session.addQueryChunk(Message.text(text: prompt, isUser: true));
    return _session.getResponse();
  }

  @override
  Stream<String> respondStream(String prompt) async* {
    await _session.addQueryChunk(Message.text(text: prompt, isUser: true));
    yield* _session.getResponseAsync();
  }

  @override
  Future<String> respondWithImage(String prompt, Uint8List imageBytes) async {
    await _session.addQueryChunk(
        Message.withImage(text: prompt, imageBytes: imageBytes, isUser: true));
    return _session.getResponse();
  }

  /// Closes the conversation ONLY — the model stays loaded.
  ///
  /// Each call still gets a fresh session, so no prompt or reply ever leaks
  /// between calls; only the (stateless) weights and accelerator context are
  /// reused. Unloading the model belongs to [LlmRuntime.releaseModel], which
  /// [LocalGemmaProvider] drives off an idle timer — closing it here rebuilt
  /// the whole model on every call (seconds each, 12+ times per page read).
  @override
  Future<void> close() => _session.close();
}
