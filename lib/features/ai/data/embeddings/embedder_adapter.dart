// Thin seams over flutter_gemma's embedding API, mirroring `gemma_adapter.dart`
// so the embedder is unit-testable without a device (the plugin needs one).
//
// The install/inference split is deliberate and matches the LLM stack:
// downloading ~175 MB is an explicit, user-triggered act, while opening the
// model is a background nicety that must FAIL rather than quietly start a
// download over mobile data. [FlutterGemmaEmbeddingRuntime.open] therefore
// refuses to install anything.

import 'package:flutter_gemma/flutter_gemma.dart';

import '../../domain/rag/text_embedder.dart';
import '../llm/gemma_adapter.dart';
import '../llm/llm_exceptions.dart';
import 'embedder_spec.dart';

/// The embedding model lives in a gated HuggingFace repo and no token is set.
///
/// Distinct from a generic download failure because the fix is a specific user
/// action — accept the licence, paste a token into Settings — and a bare 401
/// would never communicate that.
class EmbedderTokenRequiredException extends LlmException {
  EmbedderTokenRequiredException(EmbedderSpec spec)
      : super('${spec.displayName} needs a HuggingFace token. Accept the '
            'licence for the model, create a read token, and add it in '
            'Settings → AI.');
}

/// Installation seam — [FlutterGemmaEmbedderInstaller] in production.
abstract class EmbedderInstaller {
  /// True only when BOTH the model and its tokenizer are present.
  Future<bool> isInstalled(EmbedderSpec spec);

  /// True when EXACTLY ONE of the two files is present — a half-finished
  /// install.
  ///
  /// This state is reachable and is not self-clearing. flutter_gemma installs
  /// the two files as separate, independently-recorded steps with no
  /// transaction around them (`EmbeddingInstallationBuilder.install` has no
  /// try/catch and never calls the plugin's own `cleanupFailedDownload` —
  /// that runs only on the inference path, which this does not go through).
  /// So a failure on the tokenizer leg leaves the ~171 MB model file behind,
  /// [isInstalled] answers false, and without this the UI would offer only a
  /// Download button — no way to see or reclaim the space.
  Future<bool> isPartiallyInstalled(EmbedderSpec spec);

  /// Downloads and installs [spec], reporting whole percents via [onProgress].
  ///
  /// Throws [EmbedderTokenRequiredException] when [spec] is gated and
  /// [authToken] is blank — checked up front so the user gets the real reason
  /// instead of an HTTP 401 surfacing minutes into a download.
  Future<void> install({
    required EmbedderSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  });

  /// Removes both the model and tokenizer files for [spec].
  Future<void> uninstall(EmbedderSpec spec);
}

class FlutterGemmaEmbedderInstaller implements EmbedderInstaller {
  /// The model dominates the download (~171 MB vs ~4.5 MB), so its progress
  /// owns almost the whole bar. Files install in this order, so a single
  /// monotonic 0–100 is honest.
  static const int _modelShare = 97;

  @override
  Future<bool> isInstalled(EmbedderSpec spec) async {
    await GemmaBootstrap.ensureInitialized();
    return await FlutterGemma.isModelInstalled(spec.modelFilename) &&
        await FlutterGemma.isModelInstalled(spec.tokenizerFilename);
  }

  @override
  Future<bool> isPartiallyInstalled(EmbedderSpec spec) async {
    await GemmaBootstrap.ensureInitialized();
    final model = await FlutterGemma.isModelInstalled(spec.modelFilename);
    final tokenizer =
        await FlutterGemma.isModelInstalled(spec.tokenizerFilename);
    return model != tokenizer;
  }

  @override
  Future<void> install({
    required EmbedderSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await GemmaBootstrap.ensureInitialized();

    // The token guard gates DOWNLOADS, not activations. install() is also the
    // only way to (re)set the active embedding spec — [open] calls it with a
    // null token purely to re-activate an already-downloaded model after a
    // restart. In that case flutter_gemma's install() skips the network
    // entirely, so demanding a token there would wrongly kill embedding on a
    // model already sitting on disk. Guard only when a real download impends.
    final token = authToken?.trim();
    if (!await isInstalled(spec) &&
        spec.needsAuth &&
        (token == null || token.isEmpty)) {
      throw EmbedderTokenRequiredException(spec);
    }

    var builder = FlutterGemma.installEmbedder()
        .modelFromNetwork(spec.modelUrl, token: token)
        .tokenizerFromNetwork(spec.tokenizerUrl, token: token);
    if (onProgress != null) {
      builder = builder
          .withModelProgress((p) => onProgress(p * _modelShare ~/ 100))
          .withTokenizerProgress(
              (p) => onProgress(_modelShare + p * (100 - _modelShare) ~/ 100));
    }
    if (cancelToken != null) builder = builder.withCancelToken(cancelToken);
    await builder.install();
  }

  @override
  Future<void> uninstall(EmbedderSpec spec) async {
    await GemmaBootstrap.ensureInitialized();
    // Two files, one model: leaving the tokenizer behind would strand ~4.5 MB
    // and leave [isInstalled] reporting a half-present model.
    await _uninstallIfPresent(spec.modelFilename);
    await _uninstallIfPresent(spec.tokenizerFilename);
  }

  /// Removes one file, tolerating its absence.
  ///
  /// `FlutterGemma.uninstallModel` THROWS a bare `Exception('Model not found')`
  /// when the file has no metadata rather than treating a delete of something
  /// absent as a no-op. Calling it blind for both files means that cleaning up
  /// a half-installed model — the exact case cleanup exists for — deletes the
  /// first file and then throws on the second, so the caller sees a failure
  /// after a partial success. Each file is therefore isolated.
  static Future<void> _uninstallIfPresent(String filename) async {
    if (!await FlutterGemma.isModelInstalled(filename)) return;
    try {
      await FlutterGemma.uninstallModel(filename);
    } catch (_) {
      // Lost a race with another delete, or the metadata vanished underneath
      // us. Either way the file is gone or unreachable; nothing to report.
    }
  }
}

/// A loaded embedding model. [close] releases the weights — after it completes
/// nothing is resident.
abstract class EmbeddingSession {
  Future<List<List<double>>> embedAll(
    List<String> texts, {
    required EmbedTaskType taskType,
  });

  Future<void> close();
}

/// Inference seam — [FlutterGemmaEmbeddingRuntime] in production.
abstract class EmbeddingRuntime {
  /// Throws [LlmNotReadyException] if [spec] isn't installed.
  Future<EmbeddingSession> open(EmbedderSpec spec);
}

class FlutterGemmaEmbeddingRuntime implements EmbeddingRuntime {
  final EmbedderInstaller _installer;

  FlutterGemmaEmbeddingRuntime({EmbedderInstaller? installer})
      : _installer = installer ?? FlutterGemmaEmbedderInstaller();

  @override
  Future<EmbeddingSession> open(EmbedderSpec spec) async {
    await GemmaBootstrap.ensureInitialized();

    // Guard BEFORE the install() below, which would otherwise download 175 MB
    // behind the user's back — install() is idempotent and, when the files are
    // already on disk, does nothing but re-mark the model active. That
    // re-activation is why it's called at all: `installEmbedder().install()` is
    // the only public way to set the active embedding spec, and the active spec
    // is what `getActiveEmbedder()` resolves paths from after a restart.
    if (!await _installer.isInstalled(spec)) throw LlmNotReadyException();
    await _installer.install(spec: spec, authToken: null);

    final EmbeddingModel model;
    try {
      model = await FlutterGemma.getActiveEmbedder(
        preferredBackend: PreferredBackend.gpu, // falls back internally
      );
    } on StateError {
      throw LlmNotReadyException();
    }
    return _GemmaEmbeddingSession(model);
  }
}

class _GemmaEmbeddingSession implements EmbeddingSession {
  final EmbeddingModel _model;
  _GemmaEmbeddingSession(this._model);

  @override
  Future<List<List<double>>> embedAll(
    List<String> texts, {
    required EmbedTaskType taskType,
  }) =>
      _model.generateEmbeddings(texts, taskType: _pluginTaskType(taskType));

  @override
  Future<void> close() => _model.close();

  /// Our domain enum → the plugin's. The plugin prepends the matching prefix
  /// (`'title: none | text: '` vs `'task: search result | query: '`) before
  /// tokenizing; see [EmbedTaskType] for why this must never be guessed.
  static TaskType _pluginTaskType(EmbedTaskType type) => switch (type) {
        EmbedTaskType.document => TaskType.retrievalDocument,
        EmbedTaskType.query => TaskType.retrievalQuery,
      };
}
