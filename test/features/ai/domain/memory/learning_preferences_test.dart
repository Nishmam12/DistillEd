import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';
import 'package:inkflow/features/ai/domain/features/explainer.dart';
import 'package:inkflow/features/ai/domain/memory/concept_mastery.dart';
import 'package:inkflow/features/ai/domain/memory/learning_preferences.dart';

ConceptMastery concept(
  String name, {
  required MasteryLevel level,
  int timesReviewed = 0,
}) =>
    ConceptMastery(
      conceptName: name,
      conceptKey: normalizeConceptKey(name),
      notebookId: 1,
      level: level,
      lastSeenAt: DateTime(2026, 7, 1),
      timesReviewed: timesReviewed,
    );

void main() {
  group('averageReviewsToMastery (derived pace signal)', () {
    test('averages reviews across mastered concepts only', () {
      final pace = averageReviewsToMastery([
        concept('a', level: MasteryLevel.mastered, timesReviewed: 2),
        concept('b', level: MasteryLevel.mastered, timesReviewed: 4),
        // Not mastered — still in progress, so it says nothing about pace yet.
        concept('c', level: MasteryLevel.learning, timesReviewed: 9),
      ]);
      expect(pace, 3.0);
    });

    test('is null with no evidence rather than inventing a number', () {
      expect(averageReviewsToMastery(const []), isNull);
      expect(
        averageReviewsToMastery(
            [concept('a', level: MasteryLevel.learning, timesReviewed: 3)]),
        isNull,
      );
    });

    test('ignores mastered concepts that were never actually reviewed', () {
      expect(
        averageReviewsToMastery(
            [concept('a', level: MasteryLevel.mastered, timesReviewed: 0)]),
        isNull,
      );
    });
  });

  group('LearningPreferences', () {
    test('empty knows nothing, so callers keep their own defaults', () {
      expect(LearningPreferences.empty.preferredExplainMode, isNull);
      expect(LearningPreferences.empty.preferredDifficulty, isNull);
      expect(LearningPreferences.empty.averageReviewsToMastery, isNull);
    });

    test('copyWith overrides only what it is given', () {
      final prefs = LearningPreferences.empty.copyWith(
        preferredExplainMode: ExplainMode.child,
        preferredDifficulty: KnowledgeLevel.advanced,
      );
      expect(prefs.preferredExplainMode, ExplainMode.child);
      expect(prefs.preferredDifficulty, KnowledgeLevel.advanced);

      final paced = prefs.copyWith(averageReviewsToMastery: 2.5);
      expect(paced.averageReviewsToMastery, 2.5);
      expect(paced.preferredExplainMode, ExplainMode.child,
          reason: 'untouched fields survive');
    });
  });
}
