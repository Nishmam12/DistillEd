// Isar persistence for [StudySession]. Identity is the generated [sessionId]
// (an event, like a quiz attempt); Isar's `id` stays a local detail.
//
// Duration is stored as whole seconds — this log is coarse by design and
// integers keep it trivially portable to any future sync target.

import 'package:isar/isar.dart';

import '../../domain/memory/study_session.dart';

part 'study_session_record.g.dart';

@collection
class StudySessionRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late String sessionId;

  @Index()
  late int notebookId;

  late DateTime startedAt;
  late int durationSeconds;
  late List<String> featuresUsed;

  StudySession toDomain() => StudySession(
        sessionId: sessionId,
        notebookId: notebookId,
        startedAt: startedAt,
        duration: Duration(seconds: durationSeconds),
        featuresUsed: featuresUsed,
      );

  static StudySessionRecord fromDomain(StudySession session) =>
      StudySessionRecord()
        ..sessionId = session.sessionId
        ..notebookId = session.notebookId
        ..startedAt = session.startedAt
        ..durationSeconds = session.duration.inSeconds
        ..featuresUsed = session.featuresUsed;
}
