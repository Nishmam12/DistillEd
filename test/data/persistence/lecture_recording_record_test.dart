import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/data/persistence/lecture_recording_record.dart';
import 'package:distill_ed/features/audio/domain/lecture_recording.dart';

void main() {
  test('a recording survives the trip to its stored row and back', () {
    final recording = LectureRecording(
      id: 0,
      notebookId: 3,
      pageId: 12,
      relativePath: 'audio/n3_p12_1.wav',
      startedAt: DateTime(2026, 10, 9, 8, 30),
      durationMs: 61000,
    );

    final back = LectureRecordingRecord.fromDomain(recording).toDomain();

    expect(back.notebookId, 3);
    expect(back.pageId, 12);
    expect(back.relativePath, 'audio/n3_p12_1.wav');
    expect(back.startedAt, DateTime(2026, 10, 9, 8, 30));
    expect(back.durationMs, 61000);
  });
}
