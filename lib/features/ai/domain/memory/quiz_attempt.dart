// A durable record of one quiz the learner took (Phase 1's Quiz was transient —
// scored in the sheet and thrown away). Pure domain; `data/memory/` persists it.
//
// SYNC-READY (per phase spec §1): a quiz attempt is an *event*, so unlike
// [ConceptMastery] it has no natural key to derive — identity is a generated,
// collision-resistant [attemptId] assigned once at creation and never rewritten.
// Isar's autoincrement id stays a local storage detail.

import 'concept_mastery.dart';
import 'stable_id.dart';

/// How one question in an attempt went, and which concepts it tested.
class QuizQuestionOutcome {
  final String prompt;
  final bool correct;

  /// Normalized concept keys this question exercised (see
  /// [normalizeConceptKey]). May be empty when nothing could be attributed —
  /// the question still counts toward the score, just not toward mastery.
  final List<String> conceptKeys;

  const QuizQuestionOutcome({
    required this.prompt,
    required this.correct,
    this.conceptKeys = const [],
  });
}

/// One completed quiz.
class QuizAttempt {
  final String attemptId;
  final int notebookId;
  final int pageId;
  final DateTime takenAt;
  final List<QuizQuestionOutcome> outcomes;

  const QuizAttempt({
    required this.attemptId,
    required this.notebookId,
    required this.pageId,
    required this.takenAt,
    required this.outcomes,
  });

  /// Creates an attempt with a freshly generated [attemptId].
  factory QuizAttempt.record({
    required int notebookId,
    required int pageId,
    required DateTime takenAt,
    required List<QuizQuestionOutcome> outcomes,
    String? attemptId,
  }) =>
      QuizAttempt(
        attemptId: attemptId ?? newStableId(),
        notebookId: notebookId,
        pageId: pageId,
        takenAt: takenAt,
        outcomes: outcomes,
      );

  int get totalCount => outcomes.length;
  int get correctCount => outcomes.where((o) => o.correct).length;

  /// 0.0–1.0; an attempt with no questions scores 0 rather than dividing by zero.
  double get scoreFraction =>
      totalCount == 0 ? 0 : correctCount / totalCount;

  /// Per-concept verdict for feeding [ConceptMastery.afterQuiz].
  ///
  /// A concept counts as correct only when **every** question testing it was
  /// answered correctly — one miss is enough to mark it shaky, which is the
  /// point of tracking concepts rather than a single topic-wide score.
  Map<String, bool> conceptOutcomes() {
    final verdicts = <String, bool>{};
    for (final outcome in outcomes) {
      for (final key in outcome.conceptKeys) {
        verdicts[key] = (verdicts[key] ?? true) && outcome.correct;
      }
    }
    return verdicts;
  }
}
