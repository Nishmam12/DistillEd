import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/memory/concept_mastery.dart';

ConceptMastery concept(
  String name, {
  MasteryLevel level = MasteryLevel.learning,
  int notebookId = 1,
  DateTime? lastSeenAt,
  DateTime? lastReviewedAt,
  int timesReviewed = 0,
  int timesMissedInQuiz = 0,
}) =>
    ConceptMastery(
      conceptName: name,
      conceptKey: normalizeConceptKey(name),
      notebookId: notebookId,
      level: level,
      lastSeenAt: lastSeenAt ?? DateTime(2026, 7, 1),
      lastReviewedAt: lastReviewedAt,
      timesReviewed: timesReviewed,
      timesMissedInQuiz: timesMissedInQuiz,
    );

void main() {
  group('normalizeConceptKey', () {
    test('folds case and collapses whitespace so one concept stays one', () {
      expect(normalizeConceptKey(' Cell  Wall '), 'cell wall');
      expect(normalizeConceptKey('CELL   WALL'), normalizeConceptKey('cell wall'));
    });
  });

  group('MasteryLevel', () {
    test('promotes one step, saturating at mastered', () {
      expect(MasteryLevel.unseen.promoted, MasteryLevel.learning);
      expect(MasteryLevel.learning.promoted, MasteryLevel.practiced);
      expect(MasteryLevel.practiced.promoted, MasteryLevel.mastered);
      expect(MasteryLevel.mastered.promoted, MasteryLevel.mastered);
    });

    test('demotes one step but never back to unseen', () {
      expect(MasteryLevel.mastered.demoted, MasteryLevel.practiced);
      expect(MasteryLevel.practiced.demoted, MasteryLevel.learning);
      expect(MasteryLevel.learning.demoted, MasteryLevel.learning);
      expect(MasteryLevel.unseen.demoted, MasteryLevel.learning);
    });

    test('storage keys round-trip; unknown or null degrades to unseen', () {
      for (final level in MasteryLevel.values) {
        expect(MasteryLevelX.fromStorageKey(level.storageKey), level);
      }
      expect(MasteryLevelX.fromStorageKey('nonsense'), MasteryLevel.unseen);
      expect(MasteryLevelX.fromStorageKey(null), MasteryLevel.unseen);
    });
  });

  group('firstSeen', () {
    test('starts at learning, keeps the display spelling, normalizes the key',
        () {
      final c = ConceptMastery.firstSeen(
        conceptName: '  Cell  Wall ',
        notebookId: 3,
        at: DateTime(2026, 7, 1),
        pageId: 5,
      );
      expect(c.level, MasteryLevel.learning);
      expect(c.conceptKey, 'cell wall');
      expect(c.conceptName, 'Cell  Wall');
      expect(c.notebookId, 3);
      expect(c.lastPageId, 5);
    });
  });

  group('observed (Context Engine feed)', () {
    test('refreshes last-seen but never promotes — reading is not testing', () {
      final at = DateTime(2026, 7, 10);
      final after = concept('photosynthesis', level: MasteryLevel.practiced)
          .observed(at: at, pageId: 9);
      expect(after.level, MasteryLevel.practiced);
      expect(after.lastSeenAt, at);
      expect(after.lastPageId, 9);
    });

    test('lifts an unseen concept to learning', () {
      final after = concept('x', level: MasteryLevel.unseen)
          .observed(at: DateTime(2026, 7, 10));
      expect(after.level, MasteryLevel.learning);
    });
  });

  group('afterQuiz', () {
    test('a correct answer promotes and counts a review', () {
      final at = DateTime(2026, 7, 10);
      final after = concept('x', level: MasteryLevel.learning)
          .afterQuiz(correct: true, at: at);
      expect(after.level, MasteryLevel.practiced);
      expect(after.timesReviewed, 1);
      expect(after.timesMissedInQuiz, 0);
      expect(after.lastReviewedAt, at);
    });

    test('a miss demotes and is counted', () {
      final after = concept('x', level: MasteryLevel.mastered)
          .afterQuiz(correct: false, at: DateTime(2026, 7, 10));
      expect(after.level, MasteryLevel.practiced);
      expect(after.timesMissedInQuiz, 1);
      expect(after.timesReviewed, 1);
    });
  });

  group('flaggedAsGap (knowledge-gap signal)', () {
    test('counts the flag and makes the concept weak without moving level', () {
      final at = DateTime(2026, 7, 10);
      final before = concept('osmosis', level: MasteryLevel.mastered);
      expect(before.isWeak, isFalse);

      final after = before.flaggedAsGap(at: at, pageId: 4);
      expect(after.level, MasteryLevel.mastered,
          reason: 'a gap is a hint, not a test result');
      expect(after.timesFlaggedAsGap, 1);
      expect(after.isWeak, isTrue);
      expect(after.lastSeenAt, at);
      expect(after.lastPageId, 4);
    });

    test('lifts an unseen concept to learning', () {
      final after = concept('x', level: MasteryLevel.unseen)
          .flaggedAsGap(at: DateTime(2026, 7, 10));
      expect(after.level, MasteryLevel.learning);
    });
  });

  group('concept attribution', () {
    test('conceptKeysMentionedIn matches normalized mentions only', () {
      const concepts = ['Photosynthesis', 'Cell  Wall', 'Mitosis'];
      expect(
        conceptKeysMentionedIn('Explain PHOTOSYNTHESIS in plants', concepts),
        ['photosynthesis'],
      );
      expect(
        conceptKeysMentionedIn('What does the cell wall do?', concepts),
        ['cell wall'],
      );
      expect(conceptKeysMentionedIn('Unrelated question', concepts), isEmpty);
      expect(conceptKeysMentionedIn('', concepts), isEmpty);
    });

    test('conceptKeysMentionedIn dedupes and can match several', () {
      final keys = conceptKeysMentionedIn(
          'mitosis vs meiosis, and mitosis again', ['Mitosis', 'Meiosis']);
      expect(keys..sort(), ['meiosis', 'mitosis']);
    });

    test('conceptsMentionedIn maps a prose gap back onto real concepts', () {
      final concepts = [concept('Photosynthesis'), concept('Mitosis')];
      final hit = conceptsMentionedIn(
          'photosynthesis is used but never defined', concepts);
      expect(hit.map((c) => c.conceptKey), ['photosynthesis']);
      expect(conceptsMentionedIn('section ends mid-thought', concepts), isEmpty);
    });
  });

  group('review scheduling (SM-2-lite)', () {
    test('a never-reviewed concept is due as soon as it is seen', () {
      final c = concept('x', lastSeenAt: DateTime(2026, 7, 1));
      expect(c.dueAt(), DateTime(2026, 7, 1));
      expect(c.isDueForReview(DateTime(2026, 7, 1)), isTrue);
    });

    test('the interval grows with mastery', () {
      final reviewed = DateTime(2026, 7, 1);
      expect(
          concept('a', level: MasteryLevel.learning, lastReviewedAt: reviewed)
              .dueAt(),
          DateTime(2026, 7, 2));
      expect(
          concept('b', level: MasteryLevel.practiced, lastReviewedAt: reviewed)
              .dueAt(),
          DateTime(2026, 7, 4));
      expect(
          concept('c', level: MasteryLevel.mastered, lastReviewedAt: reviewed)
              .dueAt(),
          DateTime(2026, 7, 8));
    });

    test('not due until the interval elapses', () {
      final c = concept('x',
          level: MasteryLevel.mastered, lastReviewedAt: DateTime(2026, 7, 1));
      expect(c.isDueForReview(DateTime(2026, 7, 5)), isFalse);
      expect(c.isDueForReview(DateTime(2026, 7, 8)), isTrue);
    });
  });

  group('selectors', () {
    test('weak = below practiced or ever missed, weakest first', () {
      final all = [
        concept('mastered-but-missed',
            level: MasteryLevel.mastered, timesMissedInQuiz: 2),
        concept('learning-a', level: MasteryLevel.learning, timesMissedInQuiz: 1),
        concept('learning-b', level: MasteryLevel.learning, timesMissedInQuiz: 3),
        concept('clean', level: MasteryLevel.practiced),
      ];
      expect(selectWeak(all).map((c) => c.conceptName),
          ['learning-b', 'learning-a', 'mastered-but-missed']);
    });

    test('mastered selects only mastered', () {
      final all = [
        concept('a', level: MasteryLevel.mastered),
        concept('b', level: MasteryLevel.learning),
      ];
      expect(selectMastered(all).map((c) => c.conceptName), ['a']);
    });

    test('due sorts most-overdue first and excludes the not-yet-due', () {
      final all = [
        // mastered + 7d => due 7/16, still resting.
        concept('resting',
            level: MasteryLevel.mastered, lastReviewedAt: DateTime(2026, 7, 9)),
        // learning + 1d => due 7/2.
        concept('overdue',
            level: MasteryLevel.learning, lastReviewedAt: DateTime(2026, 7, 1)),
        // practiced + 3d => due 7/8.
        concept('mid',
            level: MasteryLevel.practiced, lastReviewedAt: DateTime(2026, 7, 5)),
      ];
      expect(selectDueForReview(all, DateTime(2026, 7, 10)).map((c) => c.conceptName),
          ['overdue', 'mid']);
    });
  });
}
