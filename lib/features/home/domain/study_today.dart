// What a day of study holds: flashcards due and the study plan's tasks, across
// every notebook that is not hidden. Feeds the Today strip on Home, the study
// reminders and the "cards due" home-screen widget. Plain functions over plain
// data, so they are tested without a database.

import '../../ai/domain/study_planner/study_plan.dart';

/// One notebook's study material: when each of its cards is next due (null:
/// never reviewed, so due now) and its study plan, if it has one.
typedef StudyNotebook = ({
  int id,
  String title,
  List<DateTime?> cardDue,
  StudyPlan? plan,
});

/// Cards of [cardDue] due by [by].
int dueBy(List<DateTime?> cardDue, DateTime by) =>
    cardDue.where((d) => d == null || !d.isAfter(by)).length;

/// The plan's unfinished tasks for [day]'s date; empty on a rest day, a done
/// day, or a day outside the plan.
List<String> planTasksOn(StudyPlan? plan, DateTime day) {
  if (plan == null) return const [];
  for (final d in plan.days) {
    if (d.date.year == day.year &&
        d.date.month == day.month &&
        d.date.day == day.day) {
      return d.completed ? const [] : [for (final t in d.tasks) t.label];
    }
  }
  return const [];
}

/// A notification to show at [at]. [notebookId] is opened when it is tapped
/// (null: Home).
class StudyReminder {
  final DateTime at;
  final String title;
  final String body;
  final int? notebookId;

  const StudyReminder({
    required this.at,
    required this.title,
    required this.body,
    this.notebookId,
  });

  Map<String, Object?> toMap() => {
        'at': at.millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'notebookId': notebookId,
      };
}

/// The reminders for the next [days] days, one a day at [hour]:00, on days
/// with cards due or plan tasks. Planned from what is known now; the app plans
/// again whenever it is left, so reviewing cards updates them.
List<StudyReminder> planReminders(
  List<StudyNotebook> notebooks,
  DateTime now, {
  int days = 7,
  int hour = 17,
}) {
  final out = <StudyReminder>[];
  for (var i = 0; i < days; i++) {
    final at = DateTime(now.year, now.month, now.day + i, hour);
    if (!at.isAfter(now)) continue;
    final endOfDay = DateTime(at.year, at.month, at.day, 23, 59, 59);
    var cards = 0;
    final planned = <String>[];
    int? mostDue, mostDueCount;
    int? plannedIn;
    for (final n in notebooks) {
      final due = dueBy(n.cardDue, endOfDay);
      cards += due;
      if (due > 0 && due > (mostDueCount ?? 0)) {
        mostDue = n.id;
        mostDueCount = due;
      }
      final tasks = planTasksOn(n.plan, at);
      if (tasks.isNotEmpty) {
        planned.add('${n.title}: ${tasks.first}');
        plannedIn ??= n.id;
      }
    }
    if (cards == 0 && planned.isEmpty) continue;
    out.add(StudyReminder(
      at: at,
      title: cards > 0
          ? '$cards ${cards == 1 ? 'card' : 'cards'} to review'
          : 'Today\'s study plan',
      body: [
        if (planned.isNotEmpty) planned.first,
        if (planned.length > 1) 'and ${planned.length - 1} more planned',
        if (planned.isEmpty) 'A few minutes keeps them fresh.',
      ].join(' · '),
      notebookId: plannedIn ?? mostDue,
    ));
  }
  return out;
}
