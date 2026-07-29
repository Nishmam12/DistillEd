// Tier 4.13: SM-2 scheduling. The roadmap's bar is "intervals lengthen on
// correct answers and shorten on misses" — these pin the exact behaviour.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/flashcards/spaced_repetition.dart';
import 'package:inkflow/features/ai/domain/models/flashcard.dart';

final _now = DateTime(2026, 7, 29, 10);

Flashcard _card(String front, {ReviewSchedule? schedule}) => Flashcard(
      front: front,
      back: 'back of $front',
      notebookId: 1,
      pageId: 10,
      createdAt: _now,
      schedule: schedule ?? ReviewSchedule.fresh,
    );

/// Passes [grade] n times in a row, advancing the clock to each due date.
ReviewSchedule _repeat(ReviewGrade grade, int times) {
  var schedule = ReviewSchedule.fresh;
  var clock = _now;
  for (var i = 0; i < times; i++) {
    schedule = schedule.afterReview(grade, now: clock);
    clock = schedule.dueAt!;
  }
  return schedule;
}

void main() {
  group('grades', () {
    test('only "again" fails', () {
      expect(ReviewGrade.again.passed, isFalse);
      expect(ReviewGrade.hard.passed, isTrue);
      expect(ReviewGrade.good.passed, isTrue);
      expect(ReviewGrade.easy.passed, isTrue);
    });
  });

  group('a new card', () {
    test('is due immediately', () {
      expect(ReviewSchedule.fresh.isDue(_now), isTrue);
      expect(ReviewSchedule.fresh.isNew, isTrue);
    });

    test('first pass schedules one day out', () {
      final next = ReviewSchedule.fresh.afterReview(ReviewGrade.good, now: _now);

      expect(next.intervalDays, 1);
      expect(next.repetitions, 1);
      expect(next.dueAt, DateTime(2026, 7, 30, 10));
    });

    test('second pass schedules six days out', () {
      final next = _repeat(ReviewGrade.good, 2);

      expect(next.intervalDays, 6);
      expect(next.repetitions, 2);
    });

    test('failing a new card is not counted as a lapse', () {
      final next =
          ReviewSchedule.fresh.afterReview(ReviewGrade.again, now: _now);

      expect(next.lapses, 0);
      expect(next.repetitions, 0);
    });
  });

  group('intervals lengthen on correct answers', () {
    test('each successive pass is longer than the last', () {
      var schedule = ReviewSchedule.fresh;
      var clock = _now;
      final intervals = <int>[];
      for (var i = 0; i < 6; i++) {
        schedule = schedule.afterReview(ReviewGrade.good, now: clock);
        clock = schedule.dueAt!;
        intervals.add(schedule.intervalDays);
      }

      for (var i = 1; i < intervals.length; i++) {
        expect(intervals[i], greaterThan(intervals[i - 1]),
            reason: 'interval $i should exceed ${i - 1}: $intervals');
      }
    });

    test('easy grows faster than good', () {
      expect(_repeat(ReviewGrade.easy, 4).intervalDays,
          greaterThan(_repeat(ReviewGrade.good, 4).intervalDays));
    });

    test('hard grows slower than good', () {
      expect(_repeat(ReviewGrade.hard, 4).intervalDays,
          lessThan(_repeat(ReviewGrade.good, 4).intervalDays));
    });

    test('easy raises the ease factor', () {
      final next = ReviewSchedule.fresh.afterReview(ReviewGrade.easy, now: _now);

      expect(next.easeFactor, greaterThan(ReviewSchedule.defaultEaseFactor));
    });

    test('good leaves the ease factor unchanged', () {
      final next = ReviewSchedule.fresh.afterReview(ReviewGrade.good, now: _now);

      expect(next.easeFactor, closeTo(ReviewSchedule.defaultEaseFactor, 1e-9));
    });

    test('hard lowers the ease factor', () {
      final next = ReviewSchedule.fresh.afterReview(ReviewGrade.hard, now: _now);

      expect(next.easeFactor, lessThan(ReviewSchedule.defaultEaseFactor));
    });
  });

  group('intervals shorten on misses', () {
    test('a miss sends a well-learned card back to one day', () {
      final learned = _repeat(ReviewGrade.good, 5);
      expect(learned.intervalDays, greaterThan(10));

      final lapsed =
          learned.afterReview(ReviewGrade.again, now: learned.dueAt!);

      expect(lapsed.intervalDays, 1);
      expect(lapsed.repetitions, 0);
    });

    test('a miss on a learned card counts as a lapse', () {
      final learned = _repeat(ReviewGrade.good, 3);

      final lapsed =
          learned.afterReview(ReviewGrade.again, now: learned.dueAt!);

      expect(lapsed.lapses, 1);
    });

    test('a miss lowers the ease factor', () {
      final learned = _repeat(ReviewGrade.good, 3);

      final lapsed =
          learned.afterReview(ReviewGrade.again, now: learned.dueAt!);

      expect(lapsed.easeFactor, lessThan(learned.easeFactor));
    });

    test('ease never falls below the floor, however many misses', () {
      var schedule = ReviewSchedule.fresh;
      var clock = _now;
      for (var i = 0; i < 30; i++) {
        schedule = schedule.afterReview(ReviewGrade.again, now: clock);
        clock = schedule.dueAt!;
      }

      expect(schedule.easeFactor, ReviewSchedule.minEaseFactor);
    });

    test('lapses accumulate and are never reset by a later pass', () {
      var schedule = _repeat(ReviewGrade.good, 3);
      schedule = schedule.afterReview(ReviewGrade.again, now: schedule.dueAt!);
      schedule = schedule.afterReview(ReviewGrade.good, now: schedule.dueAt!);

      expect(schedule.lapses, 1);
    });
  });

  group('due dates', () {
    test('a card is not due before its date', () {
      final next = ReviewSchedule.fresh.afterReview(ReviewGrade.good, now: _now);

      expect(next.isDue(_now), isFalse);
      expect(next.isDue(next.dueAt!), isTrue);
      expect(next.isDue(next.dueAt!.add(const Duration(days: 2))), isTrue);
    });

    test('adding days lands on the right calendar day', () {
      // Calendar arithmetic rather than Duration, so a DST shift cannot move
      // the interval by a day.
      final next = ReviewSchedule.fresh.afterReview(ReviewGrade.good, now: _now);

      expect(next.dueAt!.day, 30);
      expect(next.dueAt!.month, 7);
    });
  });

  group('review queue', () {
    test('due cards come back, not-yet-due cards do not', () {
      final due = _card('due', schedule: ReviewSchedule.fresh);
      final later = _card(
        'later',
        schedule: ReviewSchedule.fresh.afterReview(ReviewGrade.easy, now: _now),
      );

      final queue = selectDue([due, later], _now);

      expect(queue.map((c) => c.front), ['due']);
    });

    test('most overdue first', () {
      ReviewSchedule dueOn(DateTime when) =>
          ReviewSchedule(repetitions: 1, intervalDays: 1, dueAt: when,
              lastReviewedAt: when.subtract(const Duration(days: 1)));

      final queue = selectDue([
        _card('recent', schedule: dueOn(_now.subtract(const Duration(days: 1)))),
        _card('ancient', schedule: dueOn(_now.subtract(const Duration(days: 9)))),
      ], _now);

      expect(queue.map((c) => c.front), ['ancient', 'recent']);
    });

    test('new cards queue behind cards that are actually due', () {
      final backlog = _card(
        'backlog',
        schedule: ReviewSchedule(
          repetitions: 1,
          intervalDays: 1,
          dueAt: _now.subtract(const Duration(days: 3)),
          lastReviewedAt: _now.subtract(const Duration(days: 4)),
        ),
      );
      final brandNew = _card('new');

      final queue = selectDue([brandNew, backlog], _now);

      expect(queue.map((c) => c.front), ['backlog', 'new']);
    });
  });

  group('surviving regeneration', () {
    test('a regenerated card keeps its schedule', () {
      final studied = _card('What is ATP?',
          schedule: _repeat(ReviewGrade.good, 3));
      final regenerated = [_card('What is ATP?')];

      final merged = preserveSchedules(regenerated, [studied]);

      expect(merged.single.schedule.repetitions, 3);
      expect(merged.single.schedule.intervalDays,
          studied.schedule.intervalDays);
    });

    test('matching ignores case and whitespace differences', () {
      final studied =
          _card('What is  ATP?', schedule: _repeat(ReviewGrade.good, 2));
      final regenerated = [_card('what is atp?')];

      final merged = preserveSchedules(regenerated, [studied]);

      expect(merged.single.schedule.repetitions, 2);
    });

    test('a genuinely new card starts fresh', () {
      final studied = _card('old', schedule: _repeat(ReviewGrade.good, 3));

      final merged = preserveSchedules([_card('brand new')], [studied]);

      expect(merged.single.schedule.isNew, isTrue);
    });

    test('a card dropped from the deck simply goes', () {
      final studied = _card('gone', schedule: _repeat(ReviewGrade.good, 3));

      final merged = preserveSchedules([_card('kept')], [studied]);

      expect(merged.map((c) => c.front), ['kept']);
    });
  });

  group('grading a card', () {
    test('returns a card with the next schedule and same content', () {
      final card = _card('front');

      final graded = card.graded(ReviewGrade.good, now: _now);

      expect(graded.front, card.front);
      expect(graded.back, card.back);
      expect(graded.schedule.repetitions, 1);
      expect(card.schedule.repetitions, 0, reason: 'original is untouched');
    });
  });
}
