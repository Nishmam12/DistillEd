// Drives the Study Planner screen: load an existing plan, generate one for a
// chosen horizon, mark days done, or clear it.
//
// Orchestration only — it reads the real Learning-Memory signals (weak / due /
// Knowledge-Graph gaps) and hands them to the PURE scheduler
// (`buildStudyPlan`), then persists the result. No model runs: the plan is
// deterministic, instant, and works with nothing downloaded. Keeping the glue
// here (not in the pure domain) lets `domain/study_planner/` stay model- and
// storage-free.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/memory/learning_memory_repository.dart';
import '../data/study_planner/study_plan_store.dart';
import '../domain/knowledge_graph/knowledge_graph.dart';
import '../domain/study_planner/study_plan.dart';
import '../domain/study_planner/study_scheduler.dart';

class StudyPlannerNotifier extends StateNotifier<AsyncValue<StudyPlan?>> {
  final LearningMemoryRepository _memory;
  final StudyPlanStore _store;
  final int _notebookId;

  StudyPlannerNotifier({
    required LearningMemoryRepository memory,
    required StudyPlanStore store,
    required int notebookId,
  })  : _memory = memory,
        _store = store,
        _notebookId = notebookId,
        super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final plan = await _store.loadForNotebook(_notebookId);
      if (mounted) state = AsyncValue.data(plan);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Builds a fresh plan for [horizon] from current signals and persists it,
  /// replacing any existing plan.
  Future<void> generate(StudyHorizon horizon) async {
    state = const AsyncValue.loading();
    try {
      final weak = await _memory.weakConcepts(_notebookId);
      final due = await _memory.dueForReview(notebookId: _notebookId);
      final concepts = await _memory.allConcepts(_notebookId);
      final relations = await _memory.relationsForNotebook(_notebookId);

      // Gaps = concepts an edge references but that were never studied — the
      // Knowledge Graph's referenced-only nodes (shared with Loop 2.4, one
      // definition of "gap").
      final graph =
          KnowledgeGraph.build(concepts: concepts, relations: relations);
      final gaps = [
        for (final node in graph.nodes)
          if (node.referencedOnly) node.name,
      ];

      final plan = buildStudyPlan(
        notebookId: _notebookId,
        horizon: horizon,
        weakConcepts: [for (final c in weak) c.conceptName],
        dueConcepts: [for (final c in due) c.conceptName],
        gapConcepts: gaps,
      );

      await _store.save(plan);
      if (mounted) state = AsyncValue.data(plan);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Marks the day at [index] done (or not) and persists the change.
  Future<void> setDayCompleted(int index, bool completed) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.toggleDay(index, completed);
    state = AsyncValue.data(updated); // optimistic — the toggle should feel instant
    try {
      await _store.save(updated);
    } catch (_) {
      // Roll back the toggle if the write failed, so the UI never lies about
      // what's saved.
      if (mounted) state = AsyncValue.data(current);
    }
  }

  /// Discards the plan (back to the generate screen).
  Future<void> clear() async {
    state = const AsyncValue.data(null);
    try {
      await _store.deleteForNotebook(_notebookId);
    } catch (_) {
      // A failed delete is harmless — the next generate replaces it anyway.
    }
  }
}
