// The saved study plan on a real database: one plan per notebook, replaced
// whole when a new one is generated.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:distill_ed/features/ai/data/study_planner/study_plan_record.dart';
import 'package:distill_ed/features/ai/data/study_planner/study_plan_store.dart';
import 'package:distill_ed/features/ai/domain/study_planner/study_plan.dart';

import '../../../../support/isar_native_library.dart';

StudyPlan _plan(int notebookId, {String note = ''}) => StudyPlan(
      notebookId: notebookId,
      horizonKind: StudyHorizonKind.week,
      createdAt: DateTime(2026, 10, 9),
      days: [
        StudyDay(
          date: DateTime(2026, 10, 10),
          tasks: const [
            StudyTask(conceptName: 'Cells', kind: StudyTaskKind.learnNew),
          ],
        ),
        StudyDay(date: DateTime(2026, 10, 11), tasks: const []),
      ],
      strategyNote: note,
    );

Future<void> main() async {
  final library = await isarNativeLibrary();
  final skip = library == null ? 'Isar native library not found' : null;

  group('IsarStudyPlanStore', () {
    late Directory dir;
    late Isar isar;
    late IsarStudyPlanStore store;

    setUpAll(() async {
      if (library != null) await initIsarForTests(library);
    });

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('study_plan_store_test_');
      isar = await Isar.open(
        [StudyPlanRecordSchema],
        directory: dir.path,
        name: 'study_plans',
      );
      store = IsarStudyPlanStore(isar: () => isar);
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
      await dir.delete(recursive: true);
    });

    test('a saved plan comes back with its days and its note', () async {
      await store.save(_plan(1, note: 'start with cells'));

      final loaded = await store.loadForNotebook(1);
      expect(loaded, isNotNull);
      expect(loaded!.notebookId, 1);
      expect(loaded.days, hasLength(2));
      expect(loaded.days.first.tasks.single.conceptName, 'Cells');
      expect(loaded.strategyNote, 'start with cells');
    }, skip: skip);

    test('generating a new plan supersedes the old one', () async {
      await store.save(_plan(1, note: 'first'));
      await store.save(_plan(1, note: 'second'));

      expect((await store.loadForNotebook(1))!.strategyNote, 'second');
      expect(await isar.studyPlanRecords.count(), 1);
    }, skip: skip);

    test('plans are kept per notebook', () async {
      await store.save(_plan(1));
      await store.save(_plan(2));

      expect(await store.loadForNotebook(1), isNotNull);
      expect(await store.loadForNotebook(2), isNotNull);
      expect(await store.loadForNotebook(3), isNull);
    }, skip: skip);

    test('deleting a notebook\'s plan leaves the others alone', () async {
      await store.save(_plan(1));
      await store.save(_plan(2));

      await store.deleteForNotebook(1);

      expect(await store.loadForNotebook(1), isNull);
      expect(await store.loadForNotebook(2), isNotNull);
    }, skip: skip);
  });
}
