// Isar persistence for [StudyPlan] (Phase 2, Loop 2.5).
//
// One plan per notebook — regenerating replaces it (the store deletes by
// notebook then inserts). Days and tasks are `@embedded` value objects, mirror
// of the domain; the rules live in `domain/study_planner/`, this only converts.

import 'package:isar/isar.dart';

import '../../domain/study_planner/study_plan.dart';

part 'study_plan_record.g.dart';

@collection
class StudyPlanRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late int notebookId;

  /// [StudyHorizonKind.storageKey] — text so an unknown value degrades rather
  /// than throwing on read.
  late String horizonKind;

  late DateTime createdAt;
  late String strategyNote;

  List<StudyDayRecord> days = [];

  StudyPlan toDomain() => StudyPlan(
        notebookId: notebookId,
        horizonKind: StudyHorizonKindLabel.fromStorageKey(horizonKind),
        createdAt: createdAt,
        strategyNote: strategyNote,
        days: [for (final d in days) d.toDomain()],
      );

  static StudyPlanRecord fromDomain(StudyPlan plan) => StudyPlanRecord()
    ..notebookId = plan.notebookId
    ..horizonKind = plan.horizonKind.storageKey
    ..createdAt = plan.createdAt
    ..strategyNote = plan.strategyNote
    ..days = [for (final d in plan.days) StudyDayRecord.fromDomain(d)];
}

@embedded
class StudyDayRecord {
  DateTime? date;
  bool completed = false;
  List<StudyTaskRecord> tasks = [];

  StudyDay toDomain() => StudyDay(
        date: date ?? DateTime.fromMillisecondsSinceEpoch(0),
        completed: completed,
        tasks: [for (final t in tasks) t.toDomain()],
      );

  static StudyDayRecord fromDomain(StudyDay day) => StudyDayRecord()
    ..date = day.date
    ..completed = day.completed
    ..tasks = [for (final t in day.tasks) StudyTaskRecord.fromDomain(t)];
}

@embedded
class StudyTaskRecord {
  String conceptName = '';

  /// [StudyTaskKind.storageKey].
  String kind = StudyTaskKind.review.storageKey;

  StudyTask toDomain() => StudyTask(
        conceptName: conceptName,
        kind: StudyTaskKindLabel.fromStorageKey(kind),
      );

  static StudyTaskRecord fromDomain(StudyTask task) => StudyTaskRecord()
    ..conceptName = task.conceptName
    ..kind = task.kind.storageKey;
}
