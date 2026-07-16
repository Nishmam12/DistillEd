// Thin seams over flutter_gemma's static API so ModelDownloadManager and
// LocalLlmService stay unit-testable (the plugin itself needs a device).
//
// FlutterGemma.initialize is performed lazily on first use (single-flight)
// instead of at app startup: nothing AI-related loads unless the user actually
// touches the Summarize feature, and app boot stays fast.

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import 'llm_exceptions.dart';
import 'llm_model_spec.dart';

class GemmaBootstrap {
  static Future<void>? _init;

  /// Registers the LiteRT-LM engine (runs .litertlm models — the runtime the
  /// Gemma 4 family ships on). Safe to call repeatedly.
  static Future<void> ensureInitialized() =>
      _init ??= FlutterGemma.initialize(
        inferenceEngines: const [LiteRtLmEngine()],
      );
}

/// Installation seam — implemented by [FlutterGemmaInstaller] in production.
abstract class ModelInstaller {
  Future<bool> isInstalled(String modelId);

  /// Downloads and installs [spec], reporting whole percents via [onProgress].
  Future<void> install({
    required LlmModelSpec spec,
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
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await GemmaBootstrap.ensureInitialized();
    var builder = FlutterGemma.installModel(
      modelType: spec.modelType,
      fileType: spec.fileType,
    ).fromNetwork(spec.downloadUrl, token: spec.authToken);
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
  Future<String> respond(String prompt);
  Future<void> close();
}

/// Inference seam — implemented by [FlutterGemmaRuntime] in production.
abstract class LlmRuntime {
  Future<LlmSession> open({
    required LlmModelSpec spec,
    required double temperature,
    required int topK,
    required double topP,
    int? maxOutputTokens,
  });
}

class FlutterGemmaRuntime implements LlmRuntime {
  @override
  Future<LlmSession> open({
    required LlmModelSpec spec,
    required double temperature,
    required int topK,
    required double topP,
    int? maxOutputTokens,
  }) async {
    await GemmaBootstrap.ensureInitialized();

    if (!FlutterGemma.hasActiveModel() ||
        !await FlutterGemma.isModelInstalled(spec.filename)) {
      throw LlmNotReadyException();
    }

    final InferenceModel model;
    try {
      model = await FlutterGemma.getActiveModel(
        maxTokens: spec.maxTokens,
        preferredBackend: PreferredBackend.gpu, // falls back internally
      );
    } on StateError {
      throw LlmNotReadyException();
    }

    try {
      final session = await model.createSession(
        temperature: temperature,
        topK: topK,
        topP: topP,
        maxOutputTokens: maxOutputTokens,
      );
      return _GemmaSession(model, session);
    } catch (e) {
      // Session creation failed — don't leak the loaded model.
      await model.close();
      throw LlmGenerationException('Could not start the model session.', e);
    }
  }
}

class _GemmaSession implements LlmSession {
  final InferenceModel _model;
  final InferenceModelSession _session;
  _GemmaSession(this._model, this._session);

  @override
  Future<String> respond(String prompt) async {
    await _session.addQueryChunk(Message.text(text: prompt, isUser: true));
    return _session.getResponse();
  }

  @override
  Future<void> close() async {
    try {
      await _session.close();
    } finally {
      await _model.close();
    }
  }
}
