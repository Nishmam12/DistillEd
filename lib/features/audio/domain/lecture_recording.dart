// Audio recorded while writing, and the mapping between ink and the timeline.
//
// WHY STROKES CARRY AN OFFSET RATHER THAN A TIMESTAMP
//
// StrokePoint.t is Flutter's monotonic engine timestamp — its epoch is the
// process start, so it resets on every app launch and cannot be compared with
// anything persisted by an earlier run. Storing raw `t` alongside a recording
// would appear to work in the session that made it and silently mis-seek
// forever after.
//
// So a stroke drawn while recording is stamped, at draw time, with how far into
// THAT recording it began ([FreehandElement.audioOffsetMs]) plus which
// recording it belongs to. Both are durable, comparable across launches, and
// independent of any clock.

/// One audio recording captured alongside a page.
class LectureRecording {
  /// Storage id. 0 for a recording not yet persisted.
  final int id;

  final int notebookId;
  final int pageId;

  /// Path relative to the app documents directory, like image elements.
  final String relativePath;

  /// Wall-clock start, for display only — never for sync.
  final DateTime startedAt;

  /// Total length. 0 while a recording is still in progress.
  final int durationMs;

  const LectureRecording({
    this.id = 0,
    required this.notebookId,
    required this.pageId,
    required this.relativePath,
    required this.startedAt,
    this.durationMs = 0,
  });

  Duration get duration => Duration(milliseconds: durationMs);

  bool get isEmpty => durationMs <= 0;

  /// Whether [offsetMs] falls inside this recording.
  bool contains(int offsetMs) => offsetMs >= 0 && offsetMs <= durationMs;

  LectureRecording copyWith({int? id, int? durationMs}) => LectureRecording(
        id: id ?? this.id,
        notebookId: notebookId,
        pageId: pageId,
        relativePath: relativePath,
        startedAt: startedAt,
        durationMs: durationMs ?? this.durationMs,
      );

  /// `12:05` / `1:02:05` — the elapsed-time form a player shows.
  static String formatOffset(int offsetMs) {
    final total = offsetMs < 0 ? 0 : offsetMs ~/ 1000;
    final seconds = total % 60;
    final minutes = (total ~/ 60) % 60;
    final hours = total ~/ 3600;
    final mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }
}

/// Tracks the live recording so strokes can be stamped as they are drawn.
///
/// Holds the engine-clock reading taken when recording started; the difference
/// between a stroke's engine timestamp and that reading is the stroke's offset
/// into the recording. The reading never leaves this object and is never
/// persisted — only the derived offset is.
class RecordingClock {
  /// Engine timestamp (ms) at the moment recording began.
  final int startedAtEngineMs;

  /// The recording being written to.
  final int recordingId;

  const RecordingClock({
    required this.startedAtEngineMs,
    required this.recordingId,
  });

  /// How far into the recording an event at engine time [engineMs] falls.
  ///
  /// Clamped at zero: a stroke begun a hair before the recorder actually
  /// started should seek to the beginning, not to a negative position.
  int offsetFor(int engineMs) {
    final offset = engineMs - startedAtEngineMs;
    return offset < 0 ? 0 : offset;
  }
}

/// Where tapping a stroke should seek to.
class InkSeekTarget {
  final int recordingId;
  final int offsetMs;

  const InkSeekTarget({required this.recordingId, required this.offsetMs});
}

/// Resolves a tapped stroke to a seek position.
///
/// Returns null when the stroke was not drawn during a recording, or when its
/// recording is no longer around — tapping ordinary ink must do nothing rather
/// than seek somewhere arbitrary.
InkSeekTarget? seekTargetFor({
  required int? recordingId,
  required int? audioOffsetMs,
  required Iterable<LectureRecording> recordings,
}) {
  if (recordingId == null || audioOffsetMs == null) return null;
  final match =
      recordings.where((r) => r.id == recordingId).firstOrNull;
  if (match == null) return null;
  // A stroke drawn in the final moments can carry an offset a few ms past the
  // stored duration; clamp rather than refuse to seek.
  final clamped =
      audioOffsetMs > match.durationMs ? match.durationMs : audioOffsetMs;
  return InkSeekTarget(
    recordingId: recordingId,
    offsetMs: clamped < 0 ? 0 : clamped,
  );
}
