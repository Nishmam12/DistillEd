// Owns the record button's state for one notebook: starting a recording (file
// path, row insert, session begin) and stopping it (duration stamped, row
// updated), plus seeking playback from a stroke.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/persistence/lecture_recording_store.dart';
import '../data/transcript_store.dart';
import '../../../editor/state/scene_controller.dart';
import '../domain/audio_ports.dart';
import '../domain/lecture_recording.dart';
import '../domain/recording_session.dart';
import '../domain/lecture_language.dart';
import '../../../core/providers/settings_provider.dart';
import 'audio_providers.dart';
import 'transcription_providers.dart';

class RecordingUiState {
  final bool isRecording;

  /// Recording is under way but paused ([isRecording] stays true).
  final bool isPaused;
  final LectureRecording? active;

  /// The lecture loaded in the player; null when the player is closed.
  final LectureRecording? nowPlaying;

  /// Playback speed (0.5–2), kept for the session.
  final double speed;

  /// Recordings already captured on the current page.
  final List<LectureRecording> onPage;

  /// Set when the last action failed, for a one-shot message.
  final String? error;

  const RecordingUiState({
    this.isRecording = false,
    this.isPaused = false,
    this.active,
    this.nowPlaying,
    this.speed = 1,
    this.onPage = const [],
    this.error,
  });

  RecordingUiState copyWith({
    bool? isRecording,
    bool? isPaused,
    LectureRecording? active,
    LectureRecording? nowPlaying,
    double? speed,
    List<LectureRecording>? onPage,
    String? error,
    bool clearActive = false,
    bool clearNowPlaying = false,
    bool clearError = false,
  }) =>
      RecordingUiState(
        isRecording: isRecording ?? this.isRecording,
        isPaused: isPaused ?? this.isPaused,
        active: clearActive ? null : (active ?? this.active),
        nowPlaying: clearNowPlaying ? null : (nowPlaying ?? this.nowPlaying),
        speed: speed ?? this.speed,
        onPage: onPage ?? this.onPage,
        error: clearError ? null : (error ?? this.error),
      );
}

class RecordingNotifier extends StateNotifier<RecordingUiState> {
  final RecordingSession _session;
  final LectureRecordingStore _store;
  final AudioPlaybackPort _playback;
  final String _appDocsPath;
  final int _notebookId;

  /// Whether new recordings are made for transcription (WAV) rather than
  /// compressed (AAC). Read when a recording STARTS, so changing the setting
  /// never alters one already under way.
  final bool Function() _transcribeLectures;

  /// Where lecture transcripts are kept. Null can only play a lecture from a
  /// stroke, never from a passage of text.
  final TranscriptStore? _transcripts;

  /// Told when a recording that CAN be transcribed has finished — the hand-off to
  /// the transcription queue.
  final void Function(LectureRecording)? _onFinished;

  RecordingNotifier({
    required this._session,
    required this._store,
    required this._playback,
    required this._appDocsPath,
    required this._notebookId,
    bool Function()? transcribeLectures,
    this._onFinished,
    this._transcripts,
  })  : _transcribeLectures = transcribeLectures ?? (() => false),
        super(const RecordingUiState());

  /// Absolute path for a recording's audio file, mirroring how images are
  /// stored: a relative path in the row, resolved against app documents.
  String _absolute(String relativePath) => '$_appDocsPath/$relativePath';

  Future<void> loadForPage(int pageId) async {
    state = state.copyWith(onPage: await _store.forPage(pageId));
  }

  bool _starting = false;

  Future<void> start(int pageId, {String? language}) async {
    if (_session.isRecording || _starting) return;
    _starting = true;
    try {
      await _start(pageId, language);
    } finally {
      _starting = false;
    }
  }

  Future<void> _start(int pageId, String? language) async {
    state = state.copyWith(clearError: true);

    final startedAt = DateTime.now();
    final forSpeech = _transcribeLectures();
    final name = 'audio/n${_notebookId}_p${pageId}_'
        '${startedAt.millisecondsSinceEpoch}.${forSpeech ? 'wav' : 'm4a'}';
    // The language the student chose is part of the name; see withLectureLanguage.
    final relativePath =
        language == null ? name : withLectureLanguage(name, language);
    final absolute = _absolute(relativePath);

    LectureRecording? inserted;
    try {
      await Directory(File(absolute).parent.path).create(recursive: true);
      // Inserted BEFORE capture begins so the row has an id to stamp strokes
      // with from the very first stroke.
      final row = inserted = await _store.insert(LectureRecording(
        notebookId: _notebookId,
        pageId: pageId,
        relativePath: relativePath,
        startedAt: startedAt,
      ));
      await _session.begin(
        recording: row,
        absolutePath: absolute,
        format: forSpeech ? AudioFormat.speechWav : AudioFormat.aac,
      );
      if (!mounted) return;
      state = state.copyWith(isRecording: true, active: row);
    } on AudioUnavailableException catch (e) {
      await _dropUnstarted(inserted);
      if (!mounted) return;
      state = state.copyWith(error: e.message);
    } catch (e) {
      if (kDebugMode) debugPrint('[audio] start failed: $e');
      await _dropUnstarted(inserted);
      if (!mounted) return;
      state = state.copyWith(error: 'Could not start recording.');
    }
  }

  /// Capture never began (permission denied, no microphone), so the row inserted
  /// for it would be a recording with no audio.
  Future<void> _dropUnstarted(LectureRecording? row) async {
    if (row == null || _session.isRecording) return;
    try {
      await _store.delete(row.id);
    } catch (_) {}
  }

  Future<void> stop(int pageId) async {
    if (!_session.isRecording) return;
    String? stopError;
    try {
      final finished = await _session.stop();
      await _store.setDuration(finished.id, finished.durationMs);
      // Hand a lecture that can be transcribed to the queue. The recording is
      // already saved, so a hand-off that fails costs only the transcript.
      if (finished.isSpeechAudio) _onFinished?.call(finished);
    } catch (e) {
      if (kDebugMode) debugPrint('[audio] stop failed: $e');
      stopError = 'Could not save the recording cleanly.';
    }
    if (!mounted) return;
    // Flip the flag before the lookup: if the read throws, the button must
    // still leave "recording" (the session is already stopped).
    state = state.copyWith(
      error: stopError,
      isRecording: false,
      isPaused: false,
      clearActive: true,
    );
    try {
      final onPage = await _store.forPage(pageId);
      if (mounted) state = state.copyWith(onPage: onPage);
    } catch (e) {
      if (kDebugMode) debugPrint('[audio] reload after stop failed: $e');
    }
  }

  /// Pauses a recording under way, or carries on with a paused one.
  Future<void> togglePause() async {
    if (!_session.isRecording) return;
    try {
      _session.isPaused ? await _session.resume() : await _session.pause();
    } catch (e) {
      if (kDebugMode) debugPrint('[audio] pause/resume failed: $e');
      if (mounted) state = state.copyWith(error: 'Could not pause the recording.');
    }
    if (mounted) state = state.copyWith(isPaused: _session.isPaused);
  }

  /// Plays the recording a stroke was drawn during, from that exact moment.
  ///
  /// Does nothing for a stroke that carries no audio link — tapping ordinary
  /// ink must not start playing something unrelated.
  Future<void> playFromStroke({
    required int? recordingId,
    required int? audioOffsetMs,
  }) async {
    final target = seekTargetFor(
      recordingId: recordingId,
      audioOffsetMs: audioOffsetMs,
      recordings: state.onPage,
    );
    if (target == null) return;

    final recording =
        state.onPage.firstWhere((r) => r.id == target.recordingId);
    await _playFrom(recording, target.offsetMs);
  }

  /// Plays the lecture [passage] — a piece of page text, as an answer's source
  /// card quotes it — was said in, from that moment. Does nothing for a passage
  /// that is not from a lecture on [pageId].
  Future<void> playPassage({
    required int pageId,
    required String passage,
  }) async {
    final transcripts = _transcripts;
    if (transcripts == null) return;
    final found = await locateInLectures(
        passage, await _store.forPage(pageId), transcripts);
    if (found == null) return;
    await _playFrom(found.recording, found.offsetMs);
  }

  Future<void> _playFrom(LectureRecording recording, int offsetMs) async {
    try {
      await _playback.load(_absolute(recording.relativePath));
      await _playback.setSpeed(state.speed);
      await _playback.seek(Duration(milliseconds: offsetMs));
      await _playback.play();
      if (mounted) state = state.copyWith(nowPlaying: recording);
    } on Exception catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        error: e is AudioUnavailableException
            ? e.message
            : 'Could not play the recording.',
      );
    }
  }

  Future<void> pause() => _playback.pause();

  /// The player's play/pause button.
  Future<void> togglePlayback() =>
      _playback.isPlaying ? _playback.pause() : _playback.play();

  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(speed: speed);
    await _playback.setSpeed(speed);
  }

  /// Stops playback and closes the player.
  Future<void> closePlayer() async {
    await _playback.pause();
    if (mounted) state = state.copyWith(clearNowPlaying: true);
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final recordingNotifierProvider = StateNotifierProvider.family<
    RecordingNotifier, RecordingUiState, int>((ref, notebookId) {
  return RecordingNotifier(
    session: ref.watch(recordingSessionProvider(notebookId)),
    store: ref.watch(lectureRecordingStoreProvider),
    playback: ref.watch(audioPlaybackProvider),
    appDocsPath: ref.watch(appDocsPathProvider),
    notebookId: notebookId,
    // Read when a recording starts: on, it is made for transcription (WAV).
    transcribeLectures: () => ref.read(settingsProvider).transcribeLectures,
    // A finished WAV lecture goes straight to the transcription queue.
    onFinished: (recording) =>
        ref.read(lectureTranscriptionProvider.notifier).enqueue(recording),
    transcripts: ref.watch(transcriptStoreProvider),
  );
});

/// Note replay: the playhead of the lecture in this notebook's player, so ink
/// drawn after it can be shown faintly. Null when the player is closed.
///
/// Rounded to a quarter second: the canvas repaints a few times a second
/// rather than on every position tick.
final inkReplayProvider =
    Provider.family<({int recordingId, int atMs})?, int>((ref, notebookId) {
  final playing = ref.watch(
      recordingNotifierProvider(notebookId).select((s) => s.nowPlaying));
  if (playing == null) return null;
  final quarter = ref.watch(lecturePositionProvider
      .select((p) => (p.value?.inMilliseconds ?? 0) ~/ 250));
  return (recordingId: playing.id, atMs: quarter * 250);
});
