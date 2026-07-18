// The deterministic core of the Study Planner (Phase 2, Loop 2.5).
//
// Pure and model-free: given the real Learning-Memory signals (weak concepts,
// concepts due for review, Knowledge-Graph gaps) and a horizon, it decides the
// whole schedule. The local model never runs here — this is exactly the "don't
// let the LLM invent the schedule" boundary the phase spec draws. So the plan is
// instant, offline, and can only ever contain concepts that came from the
// learner's own notes.

import '../memory/concept_mastery.dart' show normalizeConceptKey;
import 'study_plan.dart';

/// Builds a [StudyPlan] for [horizon] from prioritized concept signals.
///
/// Priority, highest first: [weakConcepts] (actively struggling) → [dueConcepts]
/// (spaced review elapsed) → [gapConcepts] (referenced but never studied). A
/// concept is scheduled once, under its highest-priority reason — being weak
/// outranks being due. Order within each list is preserved (callers pass them
/// weakest-/most-overdue-first), so the most important work sits earliest.
///
/// Tasks are capped to `dayCount × [maxTasksPerDay]` and then spread evenly
/// across the days, so no day is overloaded and a long horizon with few concepts
/// yields light days rather than everything piled on day one. Excess concepts
/// beyond capacity are dropped (the highest-priority ones are kept) rather than
/// cramming — an honest plan the learner can actually follow.
StudyPlan buildStudyPlan({
  required int notebookId,
  required StudyHorizon horizon,
  required List<String> weakConcepts,
  required List<String> dueConcepts,
  required List<String> gapConcepts,
  int maxTasksPerDay = 3,
  DateTime? createdAt,
}) {
  final tasks = <StudyTask>[];
  final seen = <String>{};
  void addAll(Iterable<String> names, StudyTaskKind kind) {
    for (final name in names) {
      final key = normalizeConceptKey(name);
      if (key.isEmpty || !seen.add(key)) continue;
      tasks.add(StudyTask(conceptName: name.trim(), kind: kind));
    }
  }

  addAll(weakConcepts, StudyTaskKind.review);
  addAll(dueConcepts, StudyTaskKind.quiz);
  addAll(gapConcepts, StudyTaskKind.learnNew);

  final numDays = horizon.dayCount;
  final capacity = numDays * (maxTasksPerDay < 1 ? 1 : maxTasksPerDay);
  final scheduled =
      tasks.length <= capacity ? tasks : tasks.sublist(0, capacity);

  final buckets = List.generate(numDays, (_) => <StudyTask>[]);
  final total = scheduled.length;
  for (var i = 0; i < total; i++) {
    // Even spread: task i lands on day ⌊i·numDays / total⌋, so the priority
    // order flows front-to-back across the horizon and every day is balanced.
    final day = total <= 1 ? 0 : (i * numDays) ~/ total;
    buckets[day.clamp(0, numDays - 1)].add(scheduled[i]);
  }

  return StudyPlan(
    notebookId: notebookId,
    horizonKind: horizon.kind,
    createdAt: createdAt ?? DateTime.now(),
    days: [
      for (var i = 0; i < numDays; i++)
        StudyDay(
          date: horizon.startDate.add(Duration(days: i)),
          tasks: buckets[i],
        ),
    ],
  );
}
