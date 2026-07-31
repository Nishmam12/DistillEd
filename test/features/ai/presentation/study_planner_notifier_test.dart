import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/memory/learning_memory_repository.dart';
import 'package:inkflow/features/ai/data/study_planner/study_plan_store.dart';
import 'package:inkflow/features/ai/domain/knowledge_graph/concept_relation.dart';
import 'package:inkflow/features/ai/domain/memory/concept_mastery.dart';
import 'package:inkflow/features/ai/domain/memory/learning_preferences.dart';
import 'package:inkflow/features/ai/domain/memory/quiz_attempt.dart';
import 'package:inkflow/features/ai/domain/memory/study_session.dart';
import 'package:inkflow/features/ai/domain/study_planner/study_plan.dart';
import 'package:inkflow/features/ai/presentation/study_planner_notifier.dart';

ConceptMastery _c(String name, MasteryLevel level) => ConceptMastery(
      conceptName: name,
      conceptKey: normalizeConceptKey(name),
      notebookId: 1,
      level: level,
      lastSeenAt: DateTime(2026, 7, 17),
    );

/// Canned signals; only the read methods the planner uses are meaningful.
class _FakeMemory implements LearningMemoryRepository {
  _FakeMemory({
    this.weak = const [],
    this.due = const [],
    this.concepts = const [],
    this.relations = const [],
  });

  final List<ConceptMastery> weak;
  final List<ConceptMastery> due;
  final List<ConceptMastery> concepts;
  final List<ConceptRelation> relations;

  @override
  Future<List<ConceptMastery>> weakConcepts(int notebookId) async => weak;
  @override
  Future<List<ConceptMastery>> dueForReview({int? notebookId, DateTime? now}) async =>
      due;
  @override
  Future<List<ConceptMastery>> allConcepts(int notebookId) async => concepts;
  @override
  Future<List<ConceptRelation>> relationsForNotebook(int notebookId) async =>
      relations;

  @override
  Future<List<ConceptMastery>> conceptsForPages(
          int notebookId, Set<int> pageIds) async =>
      const [];

  @override
  Future<List<ConceptRelation>> relationsForPages(
          int notebookId, Set<int> pageIds) async =>
      const [];

  @override
  Future<List<ConceptMastery>> masteredConcepts(int notebookId) async => const [];
  @override
  Future<void> observePageContext({
    required int notebookId,
    required Iterable<String> keyConcepts,
    Iterable<String> knowledgeGaps = const [],
    Iterable<ConceptRelation> relations = const [],
    int? pageId,
    DateTime? at,
  }) async {}
  @override
  Future<void> recordQuizAttempt(QuizAttempt attempt) async {}
  @override
  Future<List<QuizAttempt>> quizHistory(int notebookId) async => const [];
  @override
  Future<LearningPreferences> loadPreferences() async =>
      LearningPreferences.empty;
  @override
  Future<void> savePreferences(LearningPreferences prefs) async {}
  @override
  Future<void> recordStudySession(StudySession session) async {}
  @override
  Future<List<StudySession>> studyHistory(int notebookId) async => const [];
}

class _FakeStore implements StudyPlanStore {
  StudyPlan? saved;
  var deletes = 0;

  @override
  Future<void> save(StudyPlan plan) async => saved = plan;
  @override
  Future<StudyPlan?> loadForNotebook(int notebookId) async => saved;
  @override
  Future<void> deleteForNotebook(int notebookId) async {
    deletes++;
    saved = null;
  }
}

StudyPlannerNotifier _notifier(_FakeMemory memory, _FakeStore store) =>
    StudyPlannerNotifier(memory: memory, store: store, notebookId: 1);

StudyHorizon _week() =>
    StudyHorizon(kind: StudyHorizonKind.week, startDate: DateTime(2026, 7, 20));

/// The notifier loads asynchronously in its constructor; give it a turn.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('with no saved plan the initial state is data(null)', () async {
    final n = _notifier(_FakeMemory(), _FakeStore());
    await settle();
    expect(n.state.hasValue, isTrue);
    expect(n.state.valueOrNull, isNull);
  });

  test('a saved plan is loaded on open', () async {
    final store = _FakeStore()
      ..saved = buildPlanStub();
    final n = _notifier(_FakeMemory(), store);
    await settle();
    expect(n.state.valueOrNull, isNotNull);
  });

  test('generate builds a plan from weak/due signals and persists it', () async {
    final memory = _FakeMemory(
      weak: [_c('Osmosis', MasteryLevel.learning)],
      due: [_c('Diffusion', MasteryLevel.practiced)],
    );
    final store = _FakeStore();
    final n = _notifier(memory, store);
    await settle();

    await n.generate(_week());

    final plan = n.state.valueOrNull!;
    final names = [for (final d in plan.days) for (final t in d.tasks) t.conceptName];
    expect(names, containsAll(['Osmosis', 'Diffusion']));
    expect(store.saved, isNotNull, reason: 'the plan must be persisted');
  });

  test('gaps come from referenced-only graph nodes', () async {
    // "Regression" is only referenced by an edge, never studied → a gap task.
    final memory = _FakeMemory(
      concepts: [_c('Machine Learning', MasteryLevel.practiced)],
      relations: const [
        ConceptRelation(
            fromName: 'Machine Learning', toName: 'Regression', relation: 'includes'),
      ],
    );
    final n = _notifier(memory, _FakeStore());
    await settle();
    await n.generate(_week());

    final tasks = [for (final d in n.state.valueOrNull!.days) ...d.tasks];
    final regression =
        tasks.where((t) => t.conceptName == 'Regression').toList();
    expect(regression, hasLength(1));
    expect(regression.single.kind, StudyTaskKind.learnNew);
  });

  test('setDayCompleted persists and updates progress', () async {
    final memory = _FakeMemory(weak: [_c('A', MasteryLevel.learning)]);
    final store = _FakeStore();
    final n = _notifier(memory, store);
    await settle();
    await n.generate(_week());

    final workIndex = n.state.valueOrNull!.days.indexWhere((d) => !d.isRest);
    await n.setDayCompleted(workIndex, true);

    expect(n.state.valueOrNull!.days[workIndex].completed, isTrue);
    expect(store.saved!.days[workIndex].completed, isTrue);
  });

  test('clear discards the plan and deletes it from the store', () async {
    final store = _FakeStore()..saved = buildPlanStub();
    final n = _notifier(_FakeMemory(), store);
    await settle();

    await n.clear();
    expect(n.state.valueOrNull, isNull);
    expect(store.deletes, 1);
  });
}

StudyPlan buildPlanStub() => StudyPlan(
      notebookId: 1,
      horizonKind: StudyHorizonKind.week,
      createdAt: DateTime(2026, 7, 20),
      days: [
        StudyDay(date: DateTime(2026, 7, 20), tasks: const [
          StudyTask(conceptName: 'A', kind: StudyTaskKind.review),
        ]),
      ],
    );
