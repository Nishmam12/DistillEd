// One recording session: start, stamp strokes as they are drawn, stop.
//
// Pure orchestration over [AudioCapturePort] and [LectureRecordingStore], with
// the engine clock injected — so the whole lifecycle is testable with no
// microphone and no real time passing.

import 'audio_ports.dart';
import 'lecture_recording.dart';

/// What the session is doing.
enum RecordingStatus { idle, recording, saving }

class RecordingSession {
  final AudioCapturePort _capture;

  /// Reads the same monotonic engine clock that stamps [StrokePoint.t], so
  /// stroke offsets and the recording start are measured against one clock.
  final int Function() _engineNowMs;

  RecordingSession({
    required AudioCapturePort capture,
    required int Function() engineNowMs,
  })  : _capture = capture,
        _engineNowMs = engineNowMs;

  RecordingStatus _status = RecordingStatus.idle;
  RecordingClock? _clock;
  LectureRecording? _active;

  RecordingStatus get status => _status;
  bool get isRecording => _status == RecordingStatus.recording;

  /// The recording being written to, or null when idle.
  LectureRecording? get active => _active;

  /// Marks the session live against [recording], which the caller has already
  /// persisted (so it has an id to stamp strokes with).
  ///
  /// The engine clock is read AFTER the capture port reports it has started, so
  /// the offset origin is when audio actually began rather than when the user
  /// tapped — the two can differ by the plugin's start-up latency, and the
  /// difference would show up as every stroke seeking slightly early.
  Future<void> begin({
    required LectureRecording recording,
    required String absolutePath,
  }) async {
    if (_status != RecordingStatus.idle) {
      throw StateError('A recording is already in progress');
    }
    if (!await _capture.ensurePermission()) {
      throw const AudioUnavailableException(
          'Microphone permission is needed to record a lecture.');
    }
    await _capture.start(absolutePath);
    _clock = RecordingClock(
      startedAtEngineMs: _engineNowMs(),
      recordingId: recording.id,
    );
    _active = recording;
    _status = RecordingStatus.recording;
  }

  /// How a stroke drawn now should be stamped, or null when nothing is being
  /// recorded — in which case the stroke carries no audio link at all.
  ({int recordingId, int audioOffsetMs})? stampFor(int strokeEngineMs) {
    final clock = _clock;
    if (clock == null || _status != RecordingStatus.recording) return null;
    return (
      recordingId: clock.recordingId,
      audioOffsetMs: clock.offsetFor(strokeEngineMs),
    );
  }

  /// Stops and returns the finished recording with its duration filled in.
  Future<LectureRecording> stop() async {
    final recording = _active;
    if (_status != RecordingStatus.recording || recording == null) {
      throw StateError('Not recording');
    }
    _status = RecordingStatus.saving;
    try {
      final durationMs = await _capture.stop();
      return recording.copyWith(durationMs: durationMs);
    } finally {
      _clock = null;
      _active = null;
      _status = RecordingStatus.idle;
    }
  }

  /// Abandons the session. Strokes already stamped keep their link, which is
  /// harmless: [seekTargetFor] returns null once the recording row is gone.
  Future<void> cancel() async {
    if (_status == RecordingStatus.idle) return;
    try {
      await _capture.cancel();
    } finally {
      _clock = null;
      _active = null;
      _status = RecordingStatus.idle;
    }
  }
}
