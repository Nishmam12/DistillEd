// Thin seams over flutter_edge_ai's embedding API, mirroring `gemma_adapter.dart`
// so the embedder is unit-testable without a device (the plugin needs one).
//
// The install/inference split is deliberate and matches the LLM stack:
// downloading ~165 MB is an explicit, user-triggered act, while opening the
// model is a background nicety that must FAIL rather than quietly start a
// download over mobile data. [EdgeAiEmbeddingRuntime.open] therefore
// refuses a model that is not on the disk.

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

/// Installation seam — [EdgeAiEmbedderInstaller] in production.
abstract class EmbedderInstaller {
  /// True only when every file of [spec] is present: the model, and its
  /// tokenizer when it has one.
  Future<bool> isInstalled(EmbedderSpec spec);

  /// True when some but not all of [spec]'s files are present — a
  /// half-finished install. Never true for a single-file bundle.
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

  /// Removes every file of [spec].
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

  /// The model dominates a two-file download (~171 MB vs ~4.5 MB), so its
  /// progress owns almost the whole bar. Files install in this order, so a
  /// single monotonic 0–100 is honest. A bundle's one file owns all of it.
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
    // A checksum check cut short (app killed) leaves the files untrusted.
    return !await isVerifyPending(spec.modelFilename);
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
    // only way to (re)set the active embedding spec — [EdgeAiEmbeddingRuntime.open]
    // calls it with a null token purely to make an already-downloaded model the
    // active one. In that case flutter_edge_ai's install() skips the network
    // entirely, so demanding a token there would wrongly kill embedding on a
    // model already sitting on disk. Guard only when a real download impends.
    final token = authToken?.trim();
    if (!await isInstalled(spec) &&
        spec.needsAuth &&
        (token == null || token.isEmpty)) {
      throw EmbedderTokenRequiredException(spec);
    }

    final tokenizerUrl = spec.tokenizerUrl;
    final alreadyThere = await isInstalled(spec);
    if (!alreadyThere) await setVerifyPending(spec.modelFilename, true);
    await forgetStaleRecords(spec);
    var builder = FlutterEdgeAi.installEmbedder()
        .modelFromNetwork(spec.modelUrl, token: token);
    if (tokenizerUrl != null) {
      builder = builder.tokenizerFromNetwork(tokenizerUrl, token: token);
    }
    if (onProgress != null) {
      final modelShare = tokenizerUrl == null ? 100 : _modelShare;
      builder = builder
          .withModelProgress((p) => onProgress(p * modelShare ~/ 100))
          .withTokenizerProgress(
              (p) => onProgress(modelShare + p * (100 - modelShare) ~/ 100));
    }
    if (cancelToken != null) builder = builder.withCancelToken(cancelToken);
    await builder.install();
    Future<List<(String, String?)>> files() async => [
          (await _pathOf(spec.modelFilename), spec.modelSha256),
          if (tokenizerUrl != null)
            (await _pathOf(spec.tokenizerFilename), spec.tokenizerSha256),
        ];
    if (alreadyThere) {
      // [EdgeAiEmbeddingRuntime.open] comes through here before every load, so
      // a model installed before checksums were recorded is hashed once now.
      await ensureVerifiedOnce(
        name: spec.modelFilename,
        files: files,
        onMismatch: () => uninstall(spec),
      );
      return;
    }
    try {
      for (final (path, expected) in await files()) {
        if (expected == null) continue;
        await verifySha256(
            path: path, expected: expected, name: spec.displayName);
      }
      await markVerified(spec.modelFilename);
      await setVerifyPending(spec.modelFilename, false);
    } on ModelDownloadException {
      await setVerifyPending(spec.modelFilename, false);
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

  /// Seam over the plugin, which needs a device: loads the active embedder.
  final Future<EmbeddingModel> Function() _loadActive;

  EdgeAiEmbeddingRuntime({
    EmbedderInstaller? installer,
    Future<EmbeddingModel> Function()? loadActive,
  })  : _installer = installer ?? EdgeAiEmbedderInstaller(),
        _loadActive = loadActive ?? _pluginLoadActive;

  static Future<EmbeddingModel> _pluginLoadActive() async {
    await GemmaBootstrap.ensureInitialized();
    // CPU, stated outright. The LiteRT embedding backend runs on the CPU by
    // decision, because its GPU delegate compiles and then returns all-zero
    // vectors for EmbeddingGemma's int4 weights. That suits us — it keeps the
    // GPU free for Gemma — and naming the CPU keeps it the CPU if a later
    // plugin version starts honouring a GPU request.
    return FlutterEdgeAi.getActiveEmbedder(
      preferredBackend: PreferredBackend.cpu,
    );
  }

  @override
  Future<EmbeddingSession> open(EmbedderSpec spec) async {
    // Opening never downloads: a download is always an explicit act.
    if (!await _installer.isInstalled(spec)) throw LlmNotReadyException();

    // Since flutter_edge_ai 2.3.0 the plugin loads only its active embedder
    // (loading by path was removed), so [spec] is made the active one first.
    // install() does that without touching the network for a model already on
    // disk. The embedder slot holds one embedder at a time, so the serving
    // model and a rollout's target still load in turn.
    await _installer.install(spec: spec);

    final EmbeddingModel model;
    try {
      model = await _loadActive();
    } on StateError {
      throw LlmNotReadyException();
    }
    return _GemmaEmbeddingSession(model, spec.promptContract);
  }
}

/// The runtime for [spec]. Both formats run on the same LiteRT backend.
EmbeddingRuntime embeddingRuntimeFor(EmbedderSpec spec) =>
    EdgeAiEmbeddingRuntime();

/// The installer for [spec], chosen the same way as [embeddingRuntimeFor].
EmbedderInstaller embedderInstallerFor(EmbedderSpec spec) =>
    EdgeAiEmbedderInstaller();

class _GemmaEmbeddingSession implements EmbeddingSession {
  final EmbeddingModel _model;
  final PromptContract _contract;
  _GemmaEmbeddingSession(this._model, this._contract);

  @override
  Future<List<List<double>>> embedAll(
    List<String> texts, {
    required EmbedTaskType taskType,
  }) async {
    final type = _pluginTaskType(taskType);
    try {
      return await _model.embedAll(
        [for (final text in texts) EmbeddingInput.text(text)],
        taskType: type,
      );
    } on EmbeddingInputTooLongException {
      // One input is over the window. One at a time, so only it is trimmed.
      return [for (final text in texts) await _embedFitted(text, type)];
    }
  }

  /// Embeds [text], trimmed from the end when it is over the model's window.
  ///
  /// Since flutter_edge_ai 2.3.0 an over-long input throws instead of being cut
  /// off; the 300M's fixed seq512 graph cut it off silently, so trimming keeps
  /// that behaviour. The prompt prefix is at the front, so it survives.
  Future<List<double>> _embedFitted(String text, TaskType type) async {
    try {
      return await _model.embed(EmbeddingInput.text(text), taskType: type);
    } on EmbeddingInputTooLongException catch (e) {
      // ponytail: characters stand in for tokens; one retry at 90% of the
      // ratio, so an input that is still too long fails the batch.
      final ratio = e.maxInputTokens / (e.actualTokens ?? 2 * e.maxInputTokens);
      final keep = (text.length * ratio * 0.9).floor();
      return _model.embed(
        EmbeddingInput.text(text.substring(0, keep)),
        taskType: type,
      );
    }
  }

  @override
  Future<void> close() => _model.close();

  /// Our domain enum → the plugin's. For a plugin contract the plugin prepends
  /// the matching prefix (`'title: none | text: '` vs `'task: search result |
  /// query: '`) before tokenizing; see [EmbedTaskType] for why this must never
  /// be guessed. An app contract has already written its prefixes, so the
  /// plugin is asked for none.
  TaskType _pluginTaskType(EmbedTaskType type) =>
      _contract.appliedBy == PromptAppliedBy.app
          ? TaskType.none
          : switch (type) {
              EmbedTaskType.document => TaskType.retrievalDocument,
              EmbedTaskType.query => TaskType.retrievalQuery,
            };
}
