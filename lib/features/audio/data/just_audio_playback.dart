// [AudioPlaybackPort] backed by `package:just_audio`.
//
// The only file in the feature that knows which playback plugin is in use.

import 'package:just_audio/just_audio.dart';

import '../domain/audio_ports.dart';

class JustAudioPlayback implements AudioPlaybackPort {
  final AudioPlayer _player;

  /// The file currently loaded, so re-seeking within one recording does not
  /// reload and restart it.
  String? _loadedPath;

  JustAudioPlayback({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  @override
  bool get isPlaying => _player.playing;

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Future<void> load(String absolutePath) async {
    if (_loadedPath == absolutePath) return;
    try {
      await _player.setFilePath(absolutePath);
      _loadedPath = absolutePath;
    } on Exception catch (e) {
      _loadedPath = null;
      throw AudioUnavailableException('Could not open the recording: $e');
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() async {
    _loadedPath = null;
    await _player.dispose();
  }
}
