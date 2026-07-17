// How this learner likes to be taught — inferred, never interrogated.
//
// Per the phase spec the pace signal is *derived*, not asked. It's also not
// stored: it's recomputed from mastery data whenever preferences are loaded, so
// it can never drift out of sync with the concepts it summarizes.

import '../context_engine/page_context.dart';
import '../features/explainer.dart';
import 'concept_mastery.dart';

/// Average number of quiz reviews it took to carry a concept to `mastered`.
///
/// Lower means this learner locks things in quickly. Null until at least one
/// concept is mastered — with no evidence, a made-up number is worse than
/// admitting we don't know yet. Mastered concepts with no recorded reviews are
/// ignored (they were never actually tested).
double? averageReviewsToMastery(Iterable<ConceptMastery> concepts) {
  final reviewed = [
    for (final c in concepts)
      if (c.level == MasteryLevel.mastered && c.timesReviewed > 0)
        c.timesReviewed,
  ];
  if (reviewed.isEmpty) return null;
  return reviewed.reduce((a, b) => a + b) / reviewed.length;
}

class LearningPreferences {
  /// The Explain mode the learner reaches for most (Phase 1's Explain modes).
  final ExplainMode? preferredExplainMode;

  /// The difficulty they settle at — seeds Quiz generation instead of always
  /// deriving it from a single page's `estimatedLevel`.
  final KnowledgeLevel? preferredDifficulty;

  /// Derived pace signal; see [averageReviewsToMastery]. Never persisted.
  final double? averageReviewsToMastery;

  const LearningPreferences({
    this.preferredExplainMode,
    this.preferredDifficulty,
    this.averageReviewsToMastery,
  });

  /// Nothing learned about the learner yet — every field absent rather than
  /// guessed, so callers keep their own sensible defaults.
  static const empty = LearningPreferences();

  LearningPreferences copyWith({
    ExplainMode? preferredExplainMode,
    KnowledgeLevel? preferredDifficulty,
    double? averageReviewsToMastery,
  }) =>
      LearningPreferences(
        preferredExplainMode: preferredExplainMode ?? this.preferredExplainMode,
        preferredDifficulty: preferredDifficulty ?? this.preferredDifficulty,
        averageReviewsToMastery:
            averageReviewsToMastery ?? this.averageReviewsToMastery,
      );
}
