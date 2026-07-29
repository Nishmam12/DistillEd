// [AudioCapturePort] backed by `package:record`.
//
// The only file in the feature that knows which recording plugin is in use.

import 'package:record/record.dart';

import '../domain/audio_ports.dart';

class RecordAudioCapture implements AudioCapturePort {
  final AudioRecorder _recorder;

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

  @override
  Future<void> start(String absolutePath) async {
    try {
      await _recorder.start(
        // AAC in an m4a container: small, and playable by just_audio on every
        // target without a codec dependency.
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: absolutePath,
      );
    } on Exception catch (e) {
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
    return _elapsed.elapsedMilliseconds;
  }

  @override
  Future<void> cancel() async {
    if (!_recording) return;
    _elapsed.stop();
    _recording = false;
    // Deletes the partial file as well as stopping the encoder.
    await _recorder.cancel();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
