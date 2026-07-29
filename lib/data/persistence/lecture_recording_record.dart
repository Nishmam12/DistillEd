// Isar persistence for [LectureRecording]. The audio itself lives on disk under
// the app documents directory (same arrangement as imported images); this row
// holds only the pointer and the timeline metadata.

import 'package:isar/isar.dart';

import '../../features/audio/domain/lecture_recording.dart';

part 'lecture_recording_record.g.dart';

@collection
class LectureRecordingRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late int notebookId;

  @Index()
  late int pageId;

  /// Path relative to the app documents dir.
  late String relativePath;

  late DateTime startedAt;

  /// 0 while recording is still in progress; stamped when it stops.
  late int durationMs;

  LectureRecording toDomain() => LectureRecording(
        id: id,
        notebookId: notebookId,
        pageId: pageId,
        relativePath: relativePath,
        startedAt: startedAt,
        durationMs: durationMs,
      );

  static LectureRecordingRecord fromDomain(LectureRecording r) =>
      LectureRecordingRecord()
        ..notebookId = r.notebookId
        ..pageId = r.pageId
        ..relativePath = r.relativePath
        ..startedAt = r.startedAt
        ..durationMs = r.durationMs;
}
