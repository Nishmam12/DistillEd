// Persistence boundary for lecture recordings, with an in-memory twin so the
// recording flow is testable without Isar or a microphone.

import 'package:isar/isar.dart';

import '../../features/audio/domain/lecture_recording.dart';
import '../../shared/isar/isar_service.dart';
import 'lecture_recording_record.dart';

abstract class LectureRecordingStore {
  /// Inserts a recording and returns it with its assigned id.
  Future<LectureRecording> insert(LectureRecording recording);

  /// Stamps a finished recording's length.
  Future<void> setDuration(int id, int durationMs);

  Future<List<LectureRecording>> forPage(int pageId);

  Future<List<LectureRecording>> forNotebook(int notebookId);

  /// Deletes the row. The caller removes the audio file — this layer does not
  /// touch the filesystem.
  Future<void> delete(int id);
}

class IsarLectureRecordingStore implements LectureRecordingStore {
  Isar get _isar => IsarService.instance;

  @override
  Future<LectureRecording> insert(LectureRecording recording) async {
    final row = LectureRecordingRecord.fromDomain(recording);
    await _isar.writeTxn(() async {
      await _isar.lectureRecordingRecords.put(row);
    });
    return recording.copyWith(id: row.id);
  }

  @override
  Future<void> setDuration(int id, int durationMs) async {
    await _isar.writeTxn(() async {
      final row = await _isar.lectureRecordingRecords.get(id);
      if (row == null) return;
      row.durationMs = durationMs;
      await _isar.lectureRecordingRecords.put(row);
    });
  }

  @override
  Future<List<LectureRecording>> forPage(int pageId) async {
    final rows = await _isar.lectureRecordingRecords
        .filter()
        .pageIdEqualTo(pageId)
        .findAll();
    rows.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return [for (final r in rows) r.toDomain()];
  }

  @override
  Future<List<LectureRecording>> forNotebook(int notebookId) async {
    final rows = await _isar.lectureRecordingRecords
        .filter()
        .notebookIdEqualTo(notebookId)
        .findAll();
    rows.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return [for (final r in rows) r.toDomain()];
  }

  @override
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.lectureRecordingRecords.delete(id);
    });
  }
}

class InMemoryLectureRecordingStore implements LectureRecordingStore {
  final List<LectureRecording> recordings = [];
  int _nextId = 1;

  @override
  Future<LectureRecording> insert(LectureRecording recording) async {
    final stored = recording.copyWith(id: _nextId++);
    recordings.add(stored);
    return stored;
  }

  @override
  Future<void> setDuration(int id, int durationMs) async {
    final i = recordings.indexWhere((r) => r.id == id);
    if (i >= 0) recordings[i] = recordings[i].copyWith(durationMs: durationMs);
  }

  @override
  Future<List<LectureRecording>> forPage(int pageId) async =>
      [for (final r in recordings) if (r.pageId == pageId) r];

  @override
  Future<List<LectureRecording>> forNotebook(int notebookId) async =>
      [for (final r in recordings) if (r.notebookId == notebookId) r];

  @override
  Future<void> delete(int id) async =>
      recordings.removeWhere((r) => r.id == id);
}
