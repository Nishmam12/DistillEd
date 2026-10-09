// [AudioCapturePort] backed by `package:record`.
//
// The only file in the feature that knows which recording plugin is in use.

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../domain/audio_ports.dart';

/// Asks MainActivity.kt to hold a foreground service while recording, so Android
/// 14+ keeps the microphone live with the app backgrounded. Anywhere the channel
/// is not registered (tests, other platforms) it does nothing.
class RecordingServiceChannel {
  static const _channel = MethodChannel('com.inkflow.inkflow/recording');

  Future<void> start() => _call('start');
  Future<void> stop() => _call('stop');

  Future<void> _call(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // No service to start here.
    } on PlatformException catch (e) {
      // Recording still works with the app in front; only background capture is
      // at risk, so this is logged rather than failing the recording.
      debugPrint('[audio] recording service $method failed: ${e.message}');
    }
  }
}

class RecordAudioCapture implements AudioCapturePort {
  final AudioRecorder _recorder;
  final RecordingServiceChannel _service = RecordingServiceChannel();

  /// Measures the recording's length locally.
  ///
  /// `record`'s stop() hands back the file path, not a duration, and decoding
  /// the container just to read its length would be a lot of work for a number
  /// we already have. A stopwatch started when capture begins is accurate to
  /// well within the seek precision anyone can perceive.
  final Stopwatch _elapsed = Stopwatch();

  bool _recording = false;

  RecordAudioCapture({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  @override
  bool get isRecording => _recording;

  @override
  Future<bool> ensurePermission() => _recorder.hasPermission();

  /// What to ask the plugin for to record in [format].
  @visibleForTesting
  static RecordConfig configFor(AudioFormat format) => switch (format) {
        // AAC in an m4a container: small, and playable by just_audio on every
        // target without a codec dependency.
        AudioFormat.aac => const RecordConfig(encoder: AudioEncoder.aacLc),
        // What the speech models take as they are — 16 kHz mono 16-bit — so
        // nothing has to decode or resample it later. just_audio plays WAV too.
        AudioFormat.speechWav => const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
      };

  @override
  Future<void> start(String absolutePath,
      {AudioFormat format = AudioFormat.aac}) async {
    await _service.start();
    try {
      await _recorder.start(configFor(format), path: absolutePath);
    } on Exception catch (e) {
      await _service.stop();
      throw AudioUnavailableException('Could not start recording: $e');
    }
    _elapsed
      ..reset()
      ..start();
    _recording = true;
  }

  @override
  Future<int> stop() async {
    if (!_recording) return 0;
    _elapsed.stop();
    _recording = false;
    await _recorder.stop();
    await _service.stop();
    return _elapsed.elapsedMilliseconds;
  }

  @override
  Future<void> cancel() async {
    if (!_recording) return;
    _elapsed.stop();
    _recording = false;
    // Deletes the partial file as well as stopping the encoder.
    await _recorder.cancel();
    await _service.stop();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
