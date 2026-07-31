// Thin seams over flutter_gemma's static API so ModelDownloadManager and
// LocalLlmService stay unit-testable (the plugin itself needs a device).
//
// FlutterGemma.initialize is performed lazily on first use (single-flight)
// instead of at app startup: nothing AI-related loads unless the user actually
// touches the Summarize feature, and app boot stays fast.

import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

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
  ///
  /// `initialize` also accepts a global `huggingFaceToken`, deliberately unused:
  /// it would be captured here, on first use, whereas the token is a per-user
  /// setting the user may paste at any time. Tokens are passed per-download
  /// instead (see [FlutterGemmaEmbedderInstaller]).
  static Future<void> ensureInitialized() =>
      _init ??= FlutterGemma.initialize(
        inferenceEngines: const [LiteRtLmEngine()],
        embeddingBackends: const [LiteRtEmbeddingBackend()],
      );
}

/// Installation seam — implemented by [FlutterGemmaInstaller] in production.
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

class FlutterGemmaInstaller implements ModelInstaller {
  @override
  Future<bool> isInstalled(String modelId) async {
    await GemmaBootstrap.ensureInitialized();
    return FlutterGemma.isModelInstalled(modelId);
  }

  @override
  Future<void> install({
    required LlmModelSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await GemmaBootstrap.ensureInitialized();
    var builder = FlutterGemma.installModel(
      modelType: spec.modelType,
      fileType: spec.fileType,
    ).fromNetwork(
      spec.downloadUrl,
      token: authToken ?? spec.authToken,
      // EXPLICIT true, not the `null` auto-detect, and the difference is the
      // whole reason a backgrounded download used to die.
      //
      // The plugin gates its notification setup on `foreground == true`
      // (SmartDownloader.shouldConfigureForegroundNotification), and on Android
      // background_downloader only calls WorkManager.setForeground() once a
      // `running` notification is configured. So on the auto path the
      // `runInForegroundIfFileLargerThan: 500` it sets is a no-op — no
      // notification, no foreground service, no Doze exemption — and this
      // ~2.4 GB transfer ran as an ordinary WorkManager task, which Android
      // kills when the app is backgrounded and hard-fails at the documented
      // 9-minute background limit either way.
      //
      // A kill is not a pause: flutter_gemma disables resume for HuggingFace
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
    await FlutterGemma.uninstallModel(modelId);
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

/// Inference seam — implemented by [FlutterGemmaRuntime] in production.
abstract class LlmRuntime {
  /// Opens a loaded model with one session. Set [supportImage] to load the
  /// model's vision encoder and enable [LlmSession.respondWithImage];
  /// [maxNumImages] caps images per turn (ignored when text-only).
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
}

class FlutterGemmaRuntime implements LlmRuntime {
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
    await GemmaBootstrap.ensureInitialized();

    if (!FlutterGemma.hasActiveModel() ||
        !await FlutterGemma.isModelInstalled(spec.filename)) {
      throw LlmNotReadyException();
    }

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
      model = await FlutterGemma.getActiveModel(
        maxTokens: spec.maxTokens,
        preferredBackend: PreferredBackend.gpu, // falls back internally
        // Loads the vision encoder too (Gemma 4 E2B ships one); no effect on
        // the text path, which passes false.
        supportImage: supportImage,
        maxNumImages: supportImage ? maxNumImages : null,
      );
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
      await model.close();
      throw LlmGenerationException('Could not start the model session.', e);
    }
  }

  @override
  Future<void> releaseModel() async {
    // The plugin owns a single cached instance; closing it fires the internal
    // close-listener that clears the cache, so the next open() rebuilds.
    _loadedWith = null;
    await FlutterGemmaPlugin.instance.initializedModel?.close();
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
