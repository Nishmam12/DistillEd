// Wiring for lecture recording. The ports are provider-injected so tests and
// the dev playground can substitute fakes without a microphone.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/persistence/lecture_recording_store.dart';
import '../data/just_audio_playback.dart';
import '../data/record_audio_capture.dart';
import '../domain/audio_ports.dart';
import '../domain/recording_session.dart';

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

/// Reads the same monotonic clock that stamps `StrokePoint.t`, so a stroke's
/// timestamp and the recording's origin are measured against one clock.
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
