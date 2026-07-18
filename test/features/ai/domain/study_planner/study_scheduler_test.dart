import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/study_planner/study_plan.dart';
import 'package:inkflow/features/ai/domain/study_planner/study_scheduler.dart';

StudyHorizon _week() => StudyHorizon(
      kind: StudyHorizonKind.week,
      startDate: DateTime(2026, 7, 20),
    );

List<StudyTask> _allTasks(StudyPlan plan) =>
    [for (final d in plan.days) ...d.tasks];

void main() {
  group('buildStudyPlan', () {
    test('spans the horizon, one dated day each', () {
      final plan = buildStudyPlan(
        notebookId: 1,
        horizon: _week(),
        weakConcepts: const ['Mitosis'],
        dueConcepts: const [],
        gapConcepts: const [],
      );

      expect(plan.days, hasLength(7));
      expect(plan.days.first.date, DateTime(2026, 7, 20));
      expect(plan.days.last.date, DateTime(2026, 7, 26));
    });

    test('weak → review, due → quiz, gap → learnNew', () {
      final plan = buildStudyPlan(
        notebookId: 1,
        horizon: _week(),
        weakConcepts: const ['Weak'],
        dueConcepts: const ['Due'],
        gapConcepts: const ['Gap'],
      );

      final byName = {for (final t in _allTasks(plan)) t.conceptName: t.kind};
      expect(byName['Weak'], StudyTaskKind.review);
      expect(byName['Due'], StudyTaskKind.quiz);
      expect(byName['Gap'], StudyTaskKind.learnNew);
    });

    test('a concept that is both weak and due is scheduled once, as review',
        () {
      final plan = buildStudyPlan(
        notebookId: 1,
        horizon: _week(),
        weakConcepts: const ['Osmosis'],
        dueConcepts: const ['osmosis'], // same concept, normalized
        gapConcepts: const [],
      );

      final tasks = _allTasks(plan);
      expect(tasks, hasLength(1));
      expect(tasks.single.kind, StudyTaskKind.review); // weak outranks due
    });

    test('preserves priority order: weakest first', () {
      final plan = buildStudyPlan(
        notebookId: 1,
        horizon: _week(),
        weakConcepts: const ['Weakest', 'LessWeak'],
        dueConcepts: const [],
        gapConcepts: const [],
      );

      // Even spread flows priority front-to-back, so the weakest is on the
      // earliest day that has a task.
      final firstTaskDay = plan.days.firstWhere((d) => d.tasks.isNotEmpty);
      expect(firstTaskDay.tasks.first.conceptName, 'Weakest');
    });

    test('caps at dayCount × maxTasksPerDay, keeping the highest priority', () {
      final plan = buildStudyPlan(
        notebookId: 1,
        horizon: _week(), // 7 days
        weakConcepts: [for (var i = 0; i < 30; i++) 'W$i'],
        dueConcepts: const [],
        gapConcepts: const [],
        maxTasksPerDay: 2, // capacity 14
      );

      final tasks = _allTasks(plan);
      expect(tasks, hasLength(14));
      // The first 14 weakest are kept; W29 (lowest priority) is dropped.
      expect(tasks.map((t) => t.conceptName), contains('W0'));
      expect(tasks.map((t) => t.conceptName), isNot(contains('W29')));
    });

    test('spreads evenly — no day exceeds the per-day cap', () {
      final plan = buildStudyPlan(
        notebookId: 1,
        horizon: _week(),
        weakConcepts: [for (var i = 0; i < 14; i++) 'W$i'],
        dueConcepts: const [],
        gapConcepts: const [],
        maxTasksPerDay: 2,
      );

      for (final day in plan.days) {
        expect(day.tasks.length, lessThanOrEqualTo(2));
      }
      expect(_allTasks(plan), hasLength(14));
    });

    test('blank concept names are ignored', () {
      final plan = buildStudyPlan(
        notebookId: 1,
        horizon: _week(),
        weakConcepts: const ['   ', ''],
        dueConcepts: const [],
        gapConcepts: const [],
      );
      expect(plan.isEmpty, isTrue);
    });

    test('a notebook with no signals yields an all-rest plan, not a crash', () {
      final plan = buildStudyPlan(
        notebookId: 1,
        horizon: _week(),
        weakConcepts: const [],
        dueConcepts: const [],
        gapConcepts: const [],
      );
      expect(plan.days, hasLength(7));
      expect(plan.isEmpty, isTrue);
      expect(plan.days.every((d) => d.isRest), isTrue);
    });

    test('is deterministic', () {
      StudyPlan make() => buildStudyPlan(
            notebookId: 1,
            horizon: _week(),
            weakConcepts: const ['A', 'B', 'C'],
            dueConcepts: const ['D'],
            gapConcepts: const ['E'],
            createdAt: DateTime(2026, 7, 20),
          );
      final a = make();
      final b = make();
      for (var i = 0; i < a.days.length; i++) {
        expect(a.days[i].tasks.map((t) => t.conceptName),
            b.days[i].tasks.map((t) => t.conceptName));
      }
    });
  });

  group('StudyHorizon.dayCount', () {
    test('fixed horizons', () {
      final start = DateTime(2026, 7, 20);
      expect(StudyHorizon(kind: StudyHorizonKind.week, startDate: start).dayCount,
          7);
      expect(
          StudyHorizon(kind: StudyHorizonKind.twoWeeks, startDate: start)
              .dayCount,
          14);
      expect(
          StudyHorizon(kind: StudyHorizonKind.month, startDate: start).dayCount,
          30);
    });

    test('exam countdown counts inclusive days to the exam', () {
      final h = StudyHorizon(
        kind: StudyHorizonKind.exam,
        startDate: DateTime(2026, 7, 20),
        examDate: DateTime(2026, 7, 24),
      );
      expect(h.dayCount, 5); // 20,21,22,23,24
    });

    test('a past or missing exam date still yields a sane one-day plan', () {
      expect(
        StudyHorizon(kind: StudyHorizonKind.exam, startDate: DateTime(2026, 7, 20))
            .dayCount,
        1,
      );
      expect(
        StudyHorizon(
          kind: StudyHorizonKind.exam,
          startDate: DateTime(2026, 7, 20),
          examDate: DateTime(2026, 7, 1), // in the past
        ).dayCount,
        1,
      );
    });

    test('an absurdly distant exam is capped', () {
      final h = StudyHorizon(
        kind: StudyHorizonKind.exam,
        startDate: DateTime(2026, 1, 1),
        examDate: DateTime(2030, 1, 1),
      );
      expect(h.dayCount, StudyHorizon.examDayCap);
    });
  });

  group('StudyPlan', () {
    StudyPlan planWith2Work1Rest() => buildStudyPlan(
          notebookId: 1,
          horizon: StudyHorizon(
              kind: StudyHorizonKind.exam,
              startDate: DateTime(2026, 7, 20),
              examDate: DateTime(2026, 7, 22)), // 3 days
          weakConcepts: const ['A', 'B'],
          dueConcepts: const [],
          gapConcepts: const [],
          maxTasksPerDay: 1,
        );

    test('progress counts only work days, and toggling a day updates it', () {
      var plan = planWith2Work1Rest();
      final workDayIndexes = [
        for (var i = 0; i < plan.days.length; i++)
          if (!plan.days[i].isRest) i
      ];
      expect(workDayIndexes, hasLength(2));
      expect(plan.progress, 0.0);

      plan = plan.toggleDay(workDayIndexes.first, true);
      expect(plan.progress, closeTo(0.5, 1e-9));
    });

    test('an all-rest plan is 100% (nothing to do), not stuck at 0', () {
      final plan = buildStudyPlan(
        notebookId: 1,
        horizon: _week(),
        weakConcepts: const [],
        dueConcepts: const [],
        gapConcepts: const [],
      );
      expect(plan.progress, 1.0);
    });

    test('conceptCount is distinct concepts across all days', () {
      final plan = buildStudyPlan(
        notebookId: 1,
        horizon: _week(),
        weakConcepts: const ['A', 'B'],
        dueConcepts: const [],
        gapConcepts: const ['C'],
      );
      expect(plan.conceptCount, 3);
    });
  });
}
