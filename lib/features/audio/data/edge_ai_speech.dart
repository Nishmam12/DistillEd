// The speech model behind lecture transcripts (docs/AI_PIPELINE_PLAN.md, item
// 14): which model, how it is installed, and a [SpeechToText] over
// flutter_edge_ai_speech.
//
// One multilingual model rather than a fast English one beside a Bangla one:
// Whisper does both, a second download and a model switch would be a lot of
// machinery for the speed difference, and the plan's own "Whisper for Bangla or
// mixed-language lectures" is the case that matters here.
//
// ponytail: Whisper base, int8. Tiny is smaller but, as its own docs say, weak
// outside English; the larger checkpoints are a different order of download.
// Moonshine (English only, 5 s windows) is the follow-up if English speed matters.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../../ai/data/llm/gemma_adapter.dart' show GemmaBootstrap;
import '../domain/lecture_transcriber.dart';

/// A speech model and the two files it is made of.
class SpeechModelSpec {
  final String displayName;

  /// What a transcript records as the model that wrote it.
  final String modelId;
  final String modelFilename;
  final String modelUrl;
  final String tokenizerUrl;
  final int approxSizeBytes;

  const SpeechModelSpec({
    required this.displayName,
    required this.modelId,
    required this.modelFilename,
    required this.modelUrl,
    required this.tokenizerUrl,
    required this.approxSizeBytes,
  });

  /// Whisper base, int8: ~77 MB, multilingual (English and Bangla among 99), a
  /// 30 s window. Both repos are public; no token.
  static const SpeechModelSpec whisperBase = SpeechModelSpec(
    displayName: 'Whisper base (lecture transcripts)',
    modelId: 'whisper-base-i8',
    modelFilename: 'whisper_base_30s_i8.tflite',
    modelUrl:
        'https://huggingface.co/litert-community/whisper-base/resolve/main/whisper_base_30s_i8.tflite',
    tokenizerUrl:
        'https://huggingface.co/openai/whisper-base/resolve/main/tokenizer.json',
    approxSizeBytes: 80 * 1024 * 1024,
  );

  static const SpeechModelSpec active = whisperBase;

  /// The tokenizer's id in the plugin, which carries its model's
  /// (`<model>__tokenizer.json`) — asked of the plugin's own spec, the one its
  /// installer records from, so it cannot drift from what is actually stored.
  String get tokenizerFilename => SttModelSpec(
        name: modelFilename,
        modelSource: ModelSource.network(modelUrl),
        tokenizerSource: ModelSource.network(tokenizerUrl),
        sttModelType: SttModelType.whisper,
      ).files[1].filename;
}

/// Installation seam — [EdgeAiSpeechInstaller] in production.
abstract class SpeechModelInstaller {
  Future<bool> isInstalled(SpeechModelSpec spec);

  /// Downloads and installs [spec], reporting whole percents via [onProgress].
  Future<void> install(
    SpeechModelSpec spec, {
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  });

  Future<void> uninstall(SpeechModelSpec spec);
}

class EdgeAiSpeechInstaller implements SpeechModelInstaller {
  /// The seams are over the plugin, which needs a device. Each default asks the
  /// plugin; a test answers instead.
  EdgeAiSpeechInstaller({
    Future<bool> Function(String filename)? isFileInstalled,
    Future<bool> Function(String filename)? isFileOnDisk,
    Future<void> Function(String filename)? forgetFile,
    Future<void> Function()? uninstallActive,
  })  : _isFileInstalled = isFileInstalled ?? _pluginHas,
        _isFileOnDisk = isFileOnDisk ?? _pluginOnDisk,
        _forgetFile = forgetFile ?? _pluginForget,
        _uninstallActive = uninstallActive ?? _pluginUninstallActive;

  /// The plugin's records: what it says it installed.
  final Future<bool> Function(String filename) _isFileInstalled;

  /// The disk: whether the file is where the plugin reads it from.
  final Future<bool> Function(String filename) _isFileOnDisk;

  /// Removes a file's record, and the file if it is still there.
  final Future<void> Function(String filename) _forgetFile;

  final Future<void> Function() _uninstallActive;

  static Future<bool> _pluginHas(String filename) async {
    await GemmaBootstrap.ensureInitialized();
    return FlutterEdgeAi.isModelInstalled(filename);
  }

  static Future<bool> _pluginOnDisk(String filename) async {
    await GemmaBootstrap.ensureInitialized();
    return File(await FlutterEdgeAi.getModelPath(filename)).exists();
  }

  static Future<void> _pluginForget(String filename) async {
    await GemmaBootstrap.ensureInitialized();
    await FlutterEdgeAi.uninstallModel(filename);
  }

  static Future<void> _pluginUninstallActive() async {
    await GemmaBootstrap.ensureInitialized();
    await FlutterEdgeAi.uninstallStt();
  }

  /// The model is ~97% of the download (the tokenizer is a couple of MB), so its
  /// progress owns almost the whole bar.
  static const int _modelShare = 97;

  /// Both files: the plugin installs them one after the other, so a download
  /// that fails between them leaves a model that cannot run, and calling that
  /// "ready" would never be put right.
  ///
  /// Both records and files. A backup restored without the model files keeps
  /// the records, and the plugin would then report a model that is not there.
  @override
  Future<bool> isInstalled(SpeechModelSpec spec) async =>
      await _isFileInstalled(spec.modelFilename) &&
      await _isFileInstalled(spec.tokenizerFilename) &&
      await _isFileOnDisk(spec.modelFilename) &&
      await _isFileOnDisk(spec.tokenizerFilename);

  @override
  Future<void> install(
    SpeechModelSpec spec, {
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await GemmaBootstrap.ensureInitialized();
    var builder = FlutterEdgeAi.installStt()
        .modelFromNetwork(spec.modelUrl)
        .tokenizerFromNetwork(spec.tokenizerUrl)
        .ofType(SttModelType.whisper);
    if (onProgress != null) {
      builder = builder
          .withModelProgress((p) => onProgress(p * _modelShare ~/ 100))
          .withTokenizerProgress(
              (p) => onProgress(_modelShare + p * (100 - _modelShare) ~/ 100));
    }
    if (cancelToken != null) builder = builder.withCancelToken(cancelToken);
    await builder.install();
  }

  /// The plugin's own uninstall reaches only a model loaded as the active one,
  /// and a model whose files are gone never is, so it did nothing and Delete
  /// left the record behind. Each record is forgotten by name instead.
  @override
  Future<void> uninstall(SpeechModelSpec spec) async {
    await _uninstallActive();
    await _forget(spec.modelFilename);
    await _forget(spec.tokenizerFilename);
  }

  Future<void> _forget(String filename) async {
    if (await _isFileInstalled(filename)) await _forgetFile(filename);
  }
}

/// [SpeechToText] over the installed Whisper model.
///
/// Keeps one recogniser open between windows — opening it is the slow part — and
/// frees it on [close], which the caller does when a lecture is done.
class EdgeAiSpeechToText implements SpeechToText {
  /// [open] is a seam over the plugin, which needs a device.
  EdgeAiSpeechToText({Future<SpeechRecognizer> Function()? open})
      : _open = open ?? _pluginOpen;

  final Future<SpeechRecognizer> Function() _open;
  Future<SpeechRecognizer>? _recognizer;

  static Future<SpeechRecognizer> _pluginOpen() async {
    await GemmaBootstrap.ensureInitialized();
    return FlutterEdgeAi.getActiveStt();
  }

  /// One open, however many windows ask at once; a failed open is forgotten so
  /// the next lecture tries again.
  Future<SpeechRecognizer> _ready() => _recognizer ??= _openOrUnavailable();

  Future<SpeechRecognizer> _openOrUnavailable() async {
    try {
      return await _open();
    } catch (e) {
      // No model installed, or its native library did not load (the speech
      // runtime needs Android 11). Either way nothing can be transcribed.
      _recognizer = null;
      throw SpeechUnavailableException('$e');
    }
  }

  @override
  Future<String> transcribe(Uint8List pcm, {required String language}) async {
    final recognizer = await _ready();
    return recognizer.transcribe(pcm, language: language);
  }

  @override
  Future<void> close() async {
    final pending = _recognizer;
    _recognizer = null;
    if (pending == null) return;
    try {
      await (await pending).close();
    } catch (_) {
      // Nothing was open, or releasing it failed; either way it is gone.
    }
  }
}
