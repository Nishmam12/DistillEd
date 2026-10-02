// The speech model behind lecture transcripts (docs/AI_PIPELINE_PLAN.md, item
// 14): which model, how it is installed, and a [SpeechToText] over
// flutter_gemma_speech.
//
// One multilingual model rather than a fast English one beside a Bangla one:
// Whisper does both, a second download and a model switch would be a lot of
// machinery for the speed difference, and the plan's own "Whisper for Bangla or
// mixed-language lectures" is the case that matters here.
//
// ponytail: Whisper base, int8. Tiny is smaller but, as its own docs say, weak
// outside English; the larger checkpoints are a different order of download.
// Moonshine (English only, 5 s windows) is the follow-up if English speed matters.

import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';

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

/// Installation seam — [FlutterGemmaSpeechInstaller] in production.
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

class FlutterGemmaSpeechInstaller implements SpeechModelInstaller {
  /// [isFileInstalled] is a seam over the plugin, which needs a device.
  FlutterGemmaSpeechInstaller(
      {Future<bool> Function(String filename)? isFileInstalled})
      : _isFileInstalled = isFileInstalled ?? _pluginHas;

  final Future<bool> Function(String filename) _isFileInstalled;

  static Future<bool> _pluginHas(String filename) async {
    await GemmaBootstrap.ensureInitialized();
    return FlutterGemma.isModelInstalled(filename);
  }

  /// The model is ~97% of the download (the tokenizer is a couple of MB), so its
  /// progress owns almost the whole bar.
  static const int _modelShare = 97;

  /// Both files: the plugin installs them one after the other, so a download
  /// that fails between them leaves a model that cannot run, and calling that
  /// "ready" would never be put right.
  @override
  Future<bool> isInstalled(SpeechModelSpec spec) async =>
      await _isFileInstalled(spec.modelFilename) &&
      await _isFileInstalled(spec.tokenizerFilename);

  @override
  Future<void> install(
    SpeechModelSpec spec, {
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await GemmaBootstrap.ensureInitialized();
    var builder = FlutterGemma.installStt()
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

  @override
  Future<void> uninstall(SpeechModelSpec spec) async {
    await GemmaBootstrap.ensureInitialized();
    await FlutterGemma.uninstallStt();
  }
}

/// [SpeechToText] over the installed Whisper model.
///
/// Keeps one recogniser open between windows — opening it is the slow part — and
/// frees it on [close], which the caller does when a lecture is done.
class FlutterGemmaSpeechToText implements SpeechToText {
  /// [open] is a seam over the plugin, which needs a device.
  FlutterGemmaSpeechToText({Future<SpeechRecognizer> Function()? open})
      : _open = open ?? _pluginOpen;

  final Future<SpeechRecognizer> Function() _open;
  Future<SpeechRecognizer>? _recognizer;

  static Future<SpeechRecognizer> _pluginOpen() async {
    await GemmaBootstrap.ensureInitialized();
    return FlutterGemma.getActiveStt();
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
