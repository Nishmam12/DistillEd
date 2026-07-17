// The Learning Memory store: durable concept mastery + quiz history.
//
// A seam over Isar (like FlashcardStore) so the rest of Phase 2 — and its tests
// — never touch IsarService directly. Deliberately rule-free: every transition
// is computed by the pure domain (`domain/memory/`), and this class only
// persists the result. The queries the rest of Phase 2 needs (weak / mastered /
// due) filter in Dart rather than in Isar, so the definition of "weak" lives in
// exactly one place — the domain — and notebook-scale data makes that free.

import 'package:isar/isar.dart';

import '../../../../shared/isar/isar_service.dart';
import '../../domain/knowledge_graph/concept_relation.dart';
import '../../domain/memory/concept_mastery.dart';
import '../../domain/memory/learning_preferences.dart';
import '../../domain/memory/quiz_attempt.dart';
import '../../domain/memory/study_session.dart';
import 'concept_mastery_record.dart';
import 'concept_relation_record.dart';
import 'learning_preferences_record.dart';
import 'quiz_attempt_record.dart';
import 'study_session_record.dart';

abstract class LearningMemoryRepository {
  /// The Context Engine feed for one analyzed page.
  ///
  /// [keyConcepts] are concept names: blank ones are ignored, unseen ones are
  /// created at `learning`, known ones only refresh their last-seen breadcrumb
  /// (reading never promotes). [knowledgeGaps] are prose, so they're matched
  /// back onto the page's concepts and counted as weakness signals rather than
  /// being stored as concepts themselves.
  Future<void> observePageContext({
    required int notebookId,
    required Iterable<String> keyConcepts,
    Iterable<String> knowledgeGaps = const [],
    Iterable<ConceptRelation> relations = const [],
    int? pageId,
    DateTime? at,
  });

  /// Persists [attempt] and applies its per-concept verdicts to mastery.
  Future<void> recordQuizAttempt(QuizAttempt attempt);

  /// Every tracked concept in a notebook.
  Future<List<ConceptMastery>> allConcepts(int notebookId);

  /// Every stored concept relationship in a notebook — the Knowledge Graph's
  /// edges.
  Future<List<ConceptRelation>> relationsForNotebook(int notebookId);

  /// Concepts the learner is measurably struggling with, weakest first.
  Future<List<ConceptMastery>> weakConcepts(int notebookId);

  /// Concepts at [MasteryLevel.mastered].
  Future<List<ConceptMastery>> masteredConcepts(int notebookId);

  /// Concepts whose review interval has elapsed, most overdue first. Omit
  /// [notebookId] to sweep every notebook.
  Future<List<ConceptMastery>> dueForReview({int? notebookId, DateTime? now});

  /// Quiz attempts for a notebook, newest first.
  Future<List<QuizAttempt>> quizHistory(int notebookId);

  /// The learner's preferences, with the derived pace signal recomputed from
  /// current mastery data. Returns [LearningPreferences.empty] when nothing has
  /// been learned about them yet.
  Future<LearningPreferences> loadPreferences();

  /// Persists the *stored* half of [prefs] (the derived pace signal is ignored).
  Future<void> savePreferences(LearningPreferences prefs);

  /// Appends a coarse session log entry.
  Future<void> recordStudySession(StudySession session);

  /// Session log for a notebook, newest first.
  Future<List<StudySession>> studyHistory(int notebookId);
}

class IsarLearningMemoryRepository implements LearningMemoryRepository {
  IsarCollection<ConceptMasteryRecord> get _concepts =>
      IsarService.instance.conceptMasteryRecords;

  IsarCollection<QuizAttemptRecord> get _attempts =>
      IsarService.instance.quizAttemptRecords;

  IsarCollection<ConceptRelationRecord> get _relations =>
      IsarService.instance.conceptRelationRecords;

  @override
  Future<void> observePageContext({
    required int notebookId,
    required Iterable<String> keyConcepts,
    Iterable<String> knowledgeGaps = const [],
    Iterable<ConceptRelation> relations = const [],
    int? pageId,
    DateTime? at,
  }) {
    final seenAt = at ?? DateTime.now();
    return IsarService.instance.writeTxn(() async {
      // Exposure first, so a gap can match a concept this same pass introduced.
      for (final name in keyConcepts) {
        final key = normalizeConceptKey(name);
        if (key.isEmpty) continue;

        final existing = await _findConcept(notebookId, key);
        final updated = existing == null
            ? ConceptMastery.firstSeen(
                conceptName: name,
                notebookId: notebookId,
                at: seenAt,
                pageId: pageId,
              )
            : existing.toDomain().observed(at: seenAt, pageId: pageId);
        await _putConcept(updated, existingId: existing?.id);
      }

      // Relationships: upsert by the natural key so re-analysis refreshes an
      // edge rather than duplicating it. Concept NODES are not minted here — a
      // referenced-but-unstudied concept becomes a node at graph-build time
      // (KnowledgeGraph.referencedOnly); Learning Memory only tracks concepts
      // the page actually taught (keyConcepts above).
      for (final r in relations) {
        if (!r.isValid) continue;
        final existing = await _findRelation(notebookId, r.fromKey, r.toKey);
        final record = ConceptRelationRecord.fromDomain(
          r,
          notebookId: notebookId,
          at: seenAt,
        );
        if (existing != null) record.id = existing.id;
        await _relations.put(record);
      }

      final gaps = knowledgeGaps.where((g) => g.trim().isNotEmpty).toList();
      if (gaps.isEmpty) return;

      // Match each gap onto the notebook's real concepts and flag those.
      final concepts = await allConcepts(notebookId);
      final flagged = <String>{};
      for (final gap in gaps) {
        for (final c in conceptsMentionedIn(gap, concepts)) {
          // One flag per concept per pass, however many gaps name it.
          if (!flagged.add(c.conceptKey)) continue;
          final existing = await _findConcept(notebookId, c.conceptKey);
          if (existing == null) continue;
          await _putConcept(
            existing.toDomain().flaggedAsGap(at: seenAt, pageId: pageId),
            existingId: existing.id,
          );
        }
      }
    });
  }

  @override
  Future<List<ConceptRelation>> relationsForNotebook(int notebookId) async {
    final rows =
        await _relations.filter().notebookIdEqualTo(notebookId).findAll();
    return [for (final r in rows) r.toDomain()];
  }

  @override
  Future<void> recordQuizAttempt(QuizAttempt attempt) {
    return IsarService.instance.writeTxn(() async {
      await _attempts.put(QuizAttemptRecord.fromDomain(attempt));

      for (final entry in attempt.conceptOutcomes().entries) {
        final existing = await _findConcept(attempt.notebookId, entry.key);
        // A concept first met *in* a quiz still gets a record — the key is its
        // own best display name until the Context Engine supplies a nicer one.
        final base = existing?.toDomain() ??
            ConceptMastery.firstSeen(
              conceptName: entry.key,
              notebookId: attempt.notebookId,
              at: attempt.takenAt,
              pageId: attempt.pageId,
            );
        await _putConcept(
          base.afterQuiz(correct: entry.value, at: attempt.takenAt),
          existingId: existing?.id,
        );
      }
    });
  }

  @override
  Future<List<ConceptMastery>> allConcepts(int notebookId) async {
    final rows =
        await _concepts.filter().notebookIdEqualTo(notebookId).findAll();
    return [for (final r in rows) r.toDomain()];
  }

  @override
  Future<List<ConceptMastery>> weakConcepts(int notebookId) async =>
      selectWeak(await allConcepts(notebookId));

  @override
  Future<List<ConceptMastery>> masteredConcepts(int notebookId) async =>
      selectMastered(await allConcepts(notebookId));

  @override
  Future<List<ConceptMastery>> dueForReview({
    int? notebookId,
    DateTime? now,
  }) async {
    final rows = notebookId == null
        ? await _concepts.filter().idGreaterThan(-1).findAll()
        : await _concepts.filter().notebookIdEqualTo(notebookId).findAll();
    return selectDueForReview(
      [for (final r in rows) r.toDomain()],
      now ?? DateTime.now(),
    );
  }

  @override
  Future<List<QuizAttempt>> quizHistory(int notebookId) async {
    final rows =
        await _attempts.filter().notebookIdEqualTo(notebookId).findAll();
    rows.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return [for (final r in rows) r.toDomain()];
  }

  @override
  Future<LearningPreferences> loadPreferences() async {
    final stored = await IsarService.instance.learningPreferencesRecords
        .get(LearningPreferencesRecord.singletonId);
    final base = stored?.toDomain() ?? LearningPreferences.empty;

    // Pace is derived across every notebook — it describes the learner, not a
    // subject — and is recomputed here so it can never be stale.
    final all = await _concepts.filter().idGreaterThan(-1).findAll();
    return base.copyWith(
      averageReviewsToMastery:
          averageReviewsToMastery([for (final r in all) r.toDomain()]),
    );
  }

  @override
  Future<void> savePreferences(LearningPreferences prefs) {
    return IsarService.instance.writeTxn(() async {
      await IsarService.instance.learningPreferencesRecords
          .put(LearningPreferencesRecord.fromDomain(prefs));
    });
  }

  @override
  Future<void> recordStudySession(StudySession session) {
    return IsarService.instance.writeTxn(() async {
      await IsarService.instance.studySessionRecords
          .put(StudySessionRecord.fromDomain(session));
    });
  }

  @override
  Future<List<StudySession>> studyHistory(int notebookId) async {
    final rows = await IsarService.instance.studySessionRecords
        .filter()
        .notebookIdEqualTo(notebookId)
        .findAll();
    rows.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return [for (final r in rows) r.toDomain()];
  }

  Future<ConceptMasteryRecord?> _findConcept(int notebookId, String key) =>
      _concepts
          .filter()
          .notebookIdEqualTo(notebookId)
          .conceptKeyEqualTo(key)
          .findFirst();

  Future<ConceptRelationRecord?> _findRelation(
          int notebookId, String fromKey, String toKey) =>
      _relations
          .filter()
          .notebookIdEqualTo(notebookId)
          .fromKeyEqualTo(fromKey)
          .toKeyEqualTo(toKey)
          .findFirst();

  /// Writes [mastery], reusing [existingId] so a known concept is updated in
  /// place rather than duplicated (identity is the natural key, not `id`).
  Future<void> _putConcept(ConceptMastery mastery, {int? existingId}) {
    final record = ConceptMasteryRecord.fromDomain(mastery);
    if (existingId != null) record.id = existingId;
    return _concepts.put(record);
  }
}
