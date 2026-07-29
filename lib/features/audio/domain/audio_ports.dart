// The two platform capabilities lecture recording needs, as narrow interfaces.
//
// Everything above these ports — session state, stroke stamping, seek
// resolution — is pure Dart and unit-tested with the fakes in
// `audio_ports_fake.dart`. Only the implementations behind these two abstracts
// touch a plugin, so swapping the audio package (or running with none at all)
// changes nothing else.

/// Captures microphone audio to a file.
abstract class AudioCapturePort {
  /// Whether the app may record. Implementations prompt if they must.
  Future<bool> ensurePermission();

  /// Begins writing to [absolutePath]. Throws [AudioUnavailableException] when
  /// the device or permission will not allow it.
  Future<void> start(String absolutePath);

  /// Stops and returns the finished length in milliseconds.
  Future<int> stop();

  /// Discards an in-progress capture without keeping the file.
  Future<void> cancel();

  bool get isRecording;
}

/// Plays a recorded file and seeks within it.
abstract class AudioPlaybackPort {
  Future<void> load(String absolutePath);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();

  /// Current position, for the scrubber.
  Stream<Duration> get position;

  bool get isPlaying;
}

/// Recording or playback could not be started — no permission, no microphone,
/// or no audio backend compiled in.
class AudioUnavailableException implements Exception {
  final String message;

  const AudioUnavailableException(this.message);

  @override
  String toString() => message;
}
