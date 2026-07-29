// Owns the record button's state for one notebook: starting a recording (file
// path, row insert, session begin) and stopping it (duration stamped, row
// updated), plus seeking playback from a stroke.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/persistence/lecture_recording_store.dart';
import '../../../editor/state/scene_controller.dart';
import '../domain/audio_ports.dart';
import '../domain/lecture_recording.dart';
import '../domain/recording_session.dart';
import 'audio_providers.dart';

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

  RecordingNotifier({
    required RecordingSession session,
    required LectureRecordingStore store,
    required AudioPlaybackPort playback,
    required String appDocsPath,
    required int notebookId,
  })  : _session = session,
        _store = store,
        _playback = playback,
        _appDocsPath = appDocsPath,
        _notebookId = notebookId,
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
    final relativePath =
        'audio/n${_notebookId}_p${pageId}_${startedAt.millisecondsSinceEpoch}.m4a';
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
      await _session.begin(recording: row, absolutePath: absolute);
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
    try {
      await _playback.load(_absolute(recording.relativePath));
      await _playback.seek(Duration(milliseconds: target.offsetMs));
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
  );
});
