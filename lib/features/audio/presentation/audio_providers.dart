// Wiring for lecture recording. The ports are provider-injected so tests and
// the dev playground can substitute fakes without a microphone.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/persistence/lecture_recording_store.dart';
import '../data/just_audio_playback.dart';
import '../data/record_audio_capture.dart';
import '../data/transcript_store.dart';
import '../domain/audio_ports.dart';
import '../domain/recording_session.dart';

import '../../../editor/state/scene_controller.dart' show appDocsPathProvider;

final lectureRecordingStoreProvider = Provider<LectureRecordingStore>(
  (ref) => IsarLectureRecordingStore(),
);

final audioCaptureProvider = Provider<AudioCapturePort>((ref) {
  final capture = RecordAudioCapture();
  ref.onDispose(capture.dispose);
  return capture;
});

final audioPlaybackProvider = Provider<AudioPlaybackPort>((ref) {
  final playback = JustAudioPlayback();
  ref.onDispose(playback.dispose);
  return playback;
});

/// The clock a recording's start, pauses and stroke stamps are all read on.
/// NOT the clock of `StrokePoint.t` (pointer event time, which only compares
/// with itself): a stroke is stamped at this clock's "now" less its age
/// (`strokeAgeMs`).
///
/// Overridable in tests, where time is supplied rather than observed.
final engineClockProvider = Provider<int Function()>(
  (ref) => () => DateTime.now().microsecondsSinceEpoch ~/ 1000,
);

/// One session per notebook — recording is scoped to the notebook being
/// written in, and two notebooks cannot record at once.
final recordingSessionProvider =
    Provider.family<RecordingSession, int>((ref, notebookId) {
  final session = RecordingSession(
    capture: ref.watch(audioCaptureProvider),
    engineNowMs: ref.watch(engineClockProvider),
  );
  ref.onDispose(session.cancel);
  return session;
});

/// Where lecture transcripts are kept: beside each recording's audio.
final transcriptStoreProvider = Provider<TranscriptStore>(
  (ref) => FileTranscriptStore(ref.watch(appDocsPathProvider)),
);

/// Where the lecture player is, and whether it is playing.
final lecturePositionProvider = StreamProvider<Duration>(
    (ref) => ref.watch(audioPlaybackProvider).position);
final lecturePlayingProvider = StreamProvider<bool>(
    (ref) => ref.watch(audioPlaybackProvider).playingStream);
