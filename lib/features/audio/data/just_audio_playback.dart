// [AudioPlaybackPort] backed by `package:just_audio`.
//
// The only file in the feature that knows which playback plugin is in use.

import 'dart:async';

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

  // just_audio keeps `playing` true after the file ends; that is not playing.
  @override
  Stream<bool> get playingStream => _player.playerStateStream
      .map((s) => s.playing && s.processingState != ProcessingState.completed)
      .distinct();

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

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

  /// From the start again when it has played to the end.
  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    // just_audio's play() completes when playback stops; don't hold callers.
    unawaited(_player.play());
  }

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
