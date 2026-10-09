// Thin seams over flutter_edge_ai's embedding API, mirroring `gemma_adapter.dart`
// so the embedder is unit-testable without a device (the plugin needs one).
//
// The install/inference split is deliberate and matches the LLM stack:
// downloading ~175 MB is an explicit, user-triggered act, while opening the
// model is a background nicety that must FAIL rather than quietly start a
// download over mobile data. [EdgeAiEmbeddingRuntime.open] therefore
// refuses to install anything.

import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../../domain/rag/prompt_contract.dart';
import '../../domain/rag/text_embedder.dart';
import '../llm/file_checksum.dart';
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

/// The model's files form a single bundle, and this build has no runtime for one
/// (phase 5 writes it). The UI never offers such a spec, so this is reached only
/// by a spec wired in by hand.
class EmbedderRuntimeUnsupportedException extends LlmException {
  EmbedderRuntimeUnsupportedException(EmbedderSpec spec)
      : super('${spec.displayName} cannot run in this version of the app yet.');
}

/// Installation seam — [EdgeAiEmbedderInstaller] in production.
abstract class EmbedderInstaller {
  /// True only when BOTH the model and its tokenizer are present.
  Future<bool> isInstalled(EmbedderSpec spec);

  /// True when EXACTLY ONE of the two files is present — a half-finished
  /// install.
  ///
  /// This state is reachable and is not self-clearing. flutter_edge_ai installs
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

class EdgeAiEmbedderInstaller implements EmbedderInstaller {
  /// The seams are over the plugin, which needs a device. Each default asks the
  /// plugin; a test answers instead.
  EdgeAiEmbedderInstaller({
    Future<bool> Function(String filename)? isFileInstalled,
    Future<bool> Function(String filename)? isFileOnDisk,
    Future<void> Function(String filename)? forgetFile,
    Future<String> Function(String filename)? pathOf,
  })  : _pathOf = pathOf ?? _pluginPath,
        _isFileInstalled = isFileInstalled ?? _pluginHas,
        _isFileOnDisk = isFileOnDisk ?? _pluginOnDisk,
        _forgetFile = forgetFile ?? _uninstallIfPresent;

  /// The plugin's records: what it says it installed.
  final Future<bool> Function(String filename) _isFileInstalled;

  /// The disk: whether the file is where the plugin reads it from.
  final Future<bool> Function(String filename) _isFileOnDisk;

  /// Removes a file's record, and the file if it is still there.
  final Future<void> Function(String filename) _forgetFile;

  final Future<String> Function(String filename) _pathOf;

  static Future<String> _pluginPath(String filename) async {
    await GemmaBootstrap.ensureInitialized();
    return FlutterEdgeAi.getModelPath(filename);
  }

  static Future<bool> _pluginHas(String filename) async {
    await GemmaBootstrap.ensureInitialized();
    return FlutterEdgeAi.isModelInstalled(filename);
  }

  static Future<bool> _pluginOnDisk(String filename) async {
    await GemmaBootstrap.ensureInitialized();
    return File(await FlutterEdgeAi.getModelPath(filename)).exists();
  }

  /// The model dominates the download (~171 MB vs ~4.5 MB), so its progress
  /// owns almost the whole bar. Files install in this order, so a single
  /// monotonic 0–100 is honest.
  static const int _modelShare = 97;

  /// Both files, each in the plugin's records and on disk. A backup restored
  /// without the model files keeps the records; counting them as installed made
  /// the download a no-op, so the Download button did nothing.
  @override
  Future<bool> isInstalled(EmbedderSpec spec) async {
    for (final name in spec.files) {
      if (!await _isFileInstalled(name) || !await _isFileOnDisk(name)) {
        return false;
      }
    }
    return true;
  }

  /// The plugin's install skips a file whose record exists, file or no file, so
  /// a record that outlived its file is forgotten first and the download runs.
  /// A file that is on disk is never touched.
  Future<void> forgetStaleRecords(EmbedderSpec spec) async {
    for (final name in spec.files) {
      if (await _isFileInstalled(name) && !await _isFileOnDisk(name)) {
        await _forgetFile(name);
      }
    }
  }

  @override
  Future<bool> isPartiallyInstalled(EmbedderSpec spec) async {
    await GemmaBootstrap.ensureInitialized();
    var recorded = 0;
    for (final name in spec.files) {
      if (await _isFileInstalled(name)) recorded++;
    }
    return recorded > 0 && recorded < spec.files.length;
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
    // restart. In that case flutter_edge_ai's install() skips the network
    // entirely, so demanding a token there would wrongly kill embedding on a
    // model already sitting on disk. Guard only when a real download impends.
    final token = authToken?.trim();
    if (!await isInstalled(spec) &&
        spec.needsAuth &&
        (token == null || token.isEmpty)) {
      throw EmbedderTokenRequiredException(spec);
    }

    final tokenizerUrl = spec.tokenizerUrl;
    if (tokenizerUrl == null) {
      throw StateError('${spec.displayName} is not a model with a tokenizer');
    }
    final alreadyThere = await isInstalled(spec);
    await forgetStaleRecords(spec);
    var builder = FlutterEdgeAi.installEmbedder()
        .modelFromNetwork(spec.modelUrl, token: token)
        .tokenizerFromNetwork(tokenizerUrl, token: token);
    if (onProgress != null) {
      builder = builder
          .withModelProgress((p) => onProgress(p * _modelShare ~/ 100))
          .withTokenizerProgress(
              (p) => onProgress(_modelShare + p * (100 - _modelShare) ~/ 100));
    }
    if (cancelToken != null) builder = builder.withCancelToken(cancelToken);
    await builder.install();
    if (alreadyThere) return;
    try {
      for (final (name, expected) in [
        (spec.modelFilename, spec.modelSha256),
        (spec.tokenizerFilename, spec.tokenizerSha256),
      ]) {
        if (expected == null) continue;
        await verifySha256(
            path: await _pathOf(name), expected: expected, name: spec.displayName);
      }
    } on ModelDownloadException {
      await uninstall(spec);
      rethrow;
    }
  }

  @override
  Future<void> uninstall(EmbedderSpec spec) async {
    await GemmaBootstrap.ensureInitialized();
    // Two files, one model: leaving the tokenizer behind would strand ~4.5 MB
    // and leave [isInstalled] reporting a half-present model.
    for (final name in spec.files) {
      await _uninstallIfPresent(name);
    }
  }

  /// Removes one file, tolerating its absence.
  ///
  /// `FlutterEdgeAi.uninstallModel` THROWS a bare `Exception('Model not found')`
  /// when the file has no metadata rather than treating a delete of something
  /// absent as a no-op. Calling it blind for both files means that cleaning up
  /// a half-installed model — the exact case cleanup exists for — deletes the
  /// first file and then throws on the second, so the caller sees a failure
  /// after a partial success. Each file is therefore isolated.
  static Future<void> _uninstallIfPresent(String filename) async {
    if (!await FlutterEdgeAi.isModelInstalled(filename)) return;
    try {
      await FlutterEdgeAi.uninstallModel(filename);
    } catch (_) {
      // Lost a race with another delete, or the metadata vanished underneath
      // us. Either way the file is gone or unreachable; nothing to report.
    }
    // The plugin deletes a file it downloaded, but not one it was handed by path
    // (the dry-run copy). Its bytes would outlive its record, so they go here.
    final leftover = File(await FlutterEdgeAi.getModelPath(filename));
    if (await leftover.exists()) await leftover.delete();
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

/// Inference seam — [EdgeAiEmbeddingRuntime] in production.
abstract class EmbeddingRuntime {
  /// Throws [LlmNotReadyException] if [spec] isn't installed.
  Future<EmbeddingSession> open(EmbedderSpec spec);
}

class EdgeAiEmbeddingRuntime implements EmbeddingRuntime {
  final EmbedderInstaller _installer;

  /// Seams over the plugin, which needs a device. Each default asks the plugin.
  final Future<String> Function(String filename) _pathOf;
  final Future<EmbeddingModel> Function({
    required String modelPath,
    required String tokenizerPath,
  }) _createModel;

  EdgeAiEmbeddingRuntime({
    EmbedderInstaller? installer,
    Future<String> Function(String filename)? pathOf,
    Future<EmbeddingModel> Function({
      required String modelPath,
      required String tokenizerPath,
    })? createModel,
  })  : _installer = installer ?? EdgeAiEmbedderInstaller(),
        _pathOf = pathOf ?? _pluginPath,
        _createModel = createModel ?? _pluginCreateModel;

  static Future<String> _pluginPath(String filename) async {
    await GemmaBootstrap.ensureInitialized();
    return FlutterEdgeAi.getModelPath(filename);
  }

  static Future<EmbeddingModel> _pluginCreateModel({
    required String modelPath,
    required String tokenizerPath,
  }) async {
    await GemmaBootstrap.ensureInitialized();
    return FlutterEdgeAiPlugin.instance.createEmbeddingModel(
      modelPath: modelPath,
      tokenizerPath: tokenizerPath,
        // CPU, stated outright. The LiteRT embedding backend (flutter_gemma_
        // litertlm 1.8) runs on the CPU by decision, because its GPU delegate
        // compiles and then returns all-zero vectors for EmbeddingGemma's int4
        // weights. That suits us — it keeps the GPU free for Gemma — but an old
        // "gpu, falls back internally" here read as if GPU embedding were
        // happening. Naming the CPU keeps it the CPU if a later plugin version
        // starts honouring the request. (The 1.x → 2.x move changed where this
        // code lives, not the vectors: same tokenizer convention, prefixes and
        // padding, so an index built before it stays valid.)
        preferredBackend: PreferredBackend.cpu,
    );
  }

  @override
  Future<EmbeddingSession> open(EmbedderSpec spec) async {
    // flutter_edge_ai always prepends its own prefix for a TaskType, and has no
    // way to embed raw text, so an app-owned prompt would be doubled. Refused
    // before the plugin is touched. Phase 5 decides whether this is needed.
    if (spec.promptContract.appliedBy == PromptAppliedBy.app) {
      throw UnsupportedError(
        '${spec.displayName}: app-owned prompts are not supported',
      );
    }
    // Opening never installs: a download is always an explicit act, and install()
    // would also re-mark a model as the plugin's active one. The files are named
    // by the spec instead, so the serving model and a rollout's target can be
    // loaded in turn without either becoming the active model.
    if (!await _installer.isInstalled(spec)) throw LlmNotReadyException();

    final EmbeddingModel model;
    try {
      model = await _createModel(
        modelPath: await _pathOf(spec.modelFilename),
        tokenizerPath: await _pathOf(spec.tokenizerFilename),
      );
    } on StateError {
      throw LlmNotReadyException();
    }
    return _GemmaEmbeddingSession(model);
  }
}

/// The runtime for [spec]'s format. The format picks it, and nothing else about
/// the spec does.
EmbeddingRuntime embeddingRuntimeFor(EmbedderSpec spec) =>
    switch (spec.format) {
      EmbedderFormat.tfliteWithTokenizer => EdgeAiEmbeddingRuntime(),
      EmbedderFormat.litertlmBundle => const LiteRtLmBundleEmbeddingRuntime(),
    };

/// The installer for [spec]'s format, chosen the same way as [embeddingRuntimeFor].
EmbedderInstaller embedderInstallerFor(EmbedderSpec spec) =>
    switch (spec.format) {
      EmbedderFormat.tfliteWithTokenizer => EdgeAiEmbedderInstaller(),
      EmbedderFormat.litertlmBundle => const LiteRtLmBundleEmbedderInstaller(),
    };

/// Stands in for the bundle runtime until phase 5 writes it.
class LiteRtLmBundleEmbeddingRuntime implements EmbeddingRuntime {
  const LiteRtLmBundleEmbeddingRuntime();

  @override
  Future<EmbeddingSession> open(EmbedderSpec spec) async {
    throw EmbedderRuntimeUnsupportedException(spec);
  }
}

/// Stands in for the bundle installer until phase 5 writes it. It reports
/// nothing installed and refuses to install, so no download can start for it.
class LiteRtLmBundleEmbedderInstaller implements EmbedderInstaller {
  const LiteRtLmBundleEmbedderInstaller();

  @override
  Future<bool> isInstalled(EmbedderSpec spec) async => false;

  @override
  Future<bool> isPartiallyInstalled(EmbedderSpec spec) async => false;

  @override
  Future<void> install({
    required EmbedderSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    throw EmbedderRuntimeUnsupportedException(spec);
  }

  @override
  Future<void> uninstall(EmbedderSpec spec) async {}
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
