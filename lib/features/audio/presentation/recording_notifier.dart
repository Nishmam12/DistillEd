// Owns the record button's state for one notebook: starting a recording (file
// path, row insert, session begin) and stopping it (duration stamped, row
// updated), plus seeking playback from a stroke.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/persistence/lecture_recording_store.dart';
import '../data/transcript_store.dart';
import '../../../editor/state/scene_controller.dart';
import '../domain/audio_ports.dart';
import '../domain/lecture_recording.dart';
import '../domain/recording_session.dart';
import '../../../core/providers/settings_provider.dart';
import 'audio_providers.dart';
import 'transcription_providers.dart';

class RecordingUiState {
  final bool isRecording;
  final LectureRecording? active;

  /// Recordings already captured on the current page.
  final List<LectureRecording> onPage;

  /// Set when the last action failed, for a one-shot message.
  final String? error;

  const RecordingUiState({
    this.isRecording = false,
    this.active,
    this.onPage = const [],
    this.error,
  });

  RecordingUiState copyWith({
    bool? isRecording,
    LectureRecording? active,
    List<LectureRecording>? onPage,
    String? error,
    bool clearActive = false,
    bool clearError = false,
  }) =>
      RecordingUiState(
        isRecording: isRecording ?? this.isRecording,
        active: clearActive ? null : (active ?? this.active),
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
    required RecordingSession session,
    required LectureRecordingStore store,
    required AudioPlaybackPort playback,
    required String appDocsPath,
    required int notebookId,
    bool Function()? transcribeLectures,
    void Function(LectureRecording)? onFinished,
    TranscriptStore? transcripts,
  })  : _session = session,
        _store = store,
        _playback = playback,
        _appDocsPath = appDocsPath,
        _notebookId = notebookId,
        _transcribeLectures = transcribeLectures ?? (() => false),
        _onFinished = onFinished,
        _transcripts = transcripts,
        super(const RecordingUiState());

  /// Absolute path for a recording's audio file, mirroring how images are
  /// stored: a relative path in the row, resolved against app documents.
  String _absolute(String relativePath) => '$_appDocsPath/$relativePath';

  Future<void> loadForPage(int pageId) async {
    state = state.copyWith(onPage: await _store.forPage(pageId));
  }

  Future<void> start(int pageId) async {
    if (_session.isRecording) return;
    state = state.copyWith(clearError: true);

    final startedAt = DateTime.now();
    final forSpeech = _transcribeLectures();
    final relativePath = 'audio/n${_notebookId}_p${pageId}_'
        '${startedAt.millisecondsSinceEpoch}.${forSpeech ? 'wav' : 'm4a'}';
    final absolute = _absolute(relativePath);

    try {
      await Directory(File(absolute).parent.path).create(recursive: true);
      // Inserted BEFORE capture begins so the row has an id to stamp strokes
      // with from the very first stroke.
      final row = await _store.insert(LectureRecording(
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
      if (!mounted) return;
      state = state.copyWith(error: e.message);
    } catch (e) {
      if (kDebugMode) debugPrint('[audio] start failed: $e');
      if (!mounted) return;
      state = state.copyWith(error: 'Could not start recording.');
    }
  }

  Future<void> stop(int pageId) async {
    if (!_session.isRecording) return;
    try {
      final finished = await _session.stop();
      await _store.setDuration(finished.id, finished.durationMs);
      // Hand a lecture that can be transcribed to the queue. The recording is
      // already saved, so a hand-off that fails costs only the transcript.
      if (finished.isSpeechAudio) _onFinished?.call(finished);
    } catch (e) {
      if (kDebugMode) debugPrint('[audio] stop failed: $e');
    }
    if (!mounted) return;
    state = state.copyWith(
      isRecording: false,
      clearActive: true,
      onPage: await _store.forPage(pageId),
    );
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
      await _playback.seek(Duration(milliseconds: offsetMs));
      await _playback.play();
    } on AudioUnavailableException catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> pause() => _playback.pause();

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
