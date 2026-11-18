import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/ai/domain/study_planner/study_plan.dart';
import 'package:margo/features/home/domain/study_today.dart';

StudyPlan _plan(DateTime day, {bool done = false}) => StudyPlan(
      notebookId: 2,
      horizonKind: StudyHorizonKind.week,
      createdAt: DateTime(2026, 11, 1),
      days: [
        StudyDay(
          date: day,
          completed: done,
          tasks: const [
            StudyTask(conceptName: 'mitosis', kind: StudyTaskKind.review),
          ],
        ),
      ],
    );

void main() {
  final now = DateTime(2026, 11, 18, 10);

  test('never-reviewed cards are due; future ones only once their day comes',
      () {
    final due = [null, DateTime(2026, 11, 18, 9), DateTime(2026, 11, 20)];
    expect(dueBy(due, now), 2);
    expect(dueBy(due, DateTime(2026, 11, 20, 23)), 3);
  });

  test('plan tasks for a day, none once it is done', () {
    expect(planTasksOn(_plan(DateTime(2026, 11, 18)), now), hasLength(1));
    expect(planTasksOn(_plan(DateTime(2026, 11, 18), done: true), now), isEmpty);
    expect(planTasksOn(_plan(DateTime(2026, 11, 19)), now), isEmpty);
  });

  test('a reminder a day at 5 pm, only on days with something to do', () {
    final r = planReminders([
      (id: 1, title: 'Bio', cardDue: [DateTime(2026, 11, 20, 8)], plan: null),
      (id: 2, title: 'Chem', cardDue: const [], plan: _plan(DateTime(2026, 11, 18))),
    ], now, days: 7);
    expect([for (final x in r) x.at], [
      DateTime(2026, 11, 18, 17), // the plan's day
      // 19th: nothing due yet
      DateTime(2026, 11, 20, 17), DateTime(2026, 11, 21, 17),
      DateTime(2026, 11, 22, 17), DateTime(2026, 11, 23, 17),
      DateTime(2026, 11, 24, 17),
    ]);
    expect(r.first.title, "Today's study plan");
    expect(r.first.notebookId, 2);
    expect(r[1].title, '1 card to review');
    expect(r[1].notebookId, 1);
  });

  test('no reminder for a time already past today', () {
    final late = DateTime(2026, 11, 18, 18);
    final r = planReminders(
        [(id: 1, title: 'Bio', cardDue: const [null], plan: null)], late,
        days: 1);
    expect(r, isEmpty);
  });
}
