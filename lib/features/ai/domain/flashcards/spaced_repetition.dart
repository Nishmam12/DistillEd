// SM-2 scheduling for the flashcard deck.
//
// The deck was flip-through only: every card came back every session regardless
// of whether the learner knew it. This turns it into actual spaced repetition —
// intervals lengthen on recall and collapse on a lapse.
//
// SM-2 rather than FSRS deliberately: FSRS needs a trained parameter set and a
// review history to fit it against, and this app has neither yet. SM-2 is a
// closed-form rule that behaves sensibly from the very first review, and its
// state (repetitions / ease / interval) is a strict subset of what FSRS would
// later need — so migrating up is additive, not a rewrite.
//
// Pure and side-effect free: no storage, no clock of its own. `now` is always
// passed in so the schedule is deterministic and unit-testable.

import 'dart:math' as math;

/// How well the learner recalled a card. Maps onto SM-2's 0–5 quality scale.
enum ReviewGrade {
  /// Failed to recall. Resets the interval.
  again,

  /// Recalled, but with real difficulty.
  hard,

  /// Recalled correctly.
  good,

  /// Recalled instantly.
  easy;

  /// SM-2 quality. Only `again` is below the passing threshold of 3 — `hard` is
  /// a pass that shortens the next interval rather than a failure.
  int get quality => switch (this) {
        ReviewGrade.again => 2,
        ReviewGrade.hard => 3,
        ReviewGrade.good => 4,
        ReviewGrade.easy => 5,
      };

  bool get passed => quality >= 3;

  String get label => switch (this) {
        ReviewGrade.again => 'Again',
        ReviewGrade.hard => 'Hard',
        ReviewGrade.good => 'Good',
        ReviewGrade.easy => 'Easy',
      };
}

/// One card's scheduling state.
class ReviewSchedule {
  /// Consecutive successful reviews. Reset to 0 by a lapse.
  final int repetitions;

  /// SM-2 ease factor — how fast this card's interval grows. Floored at
  /// [minEaseFactor] so a repeatedly-failed card cannot collapse to a
  /// permanently daily interval.
  final double easeFactor;

  /// Days until the next review, from [lastReviewedAt].
  final int intervalDays;

  /// When the card is next due, or null if it has never been reviewed.
  final DateTime? dueAt;

  final DateTime? lastReviewedAt;

  /// How many times the learner has failed this card after previously passing
  /// it. Surfaced as "leech" evidence, and never reset.
  final int lapses;

  const ReviewSchedule({
    this.repetitions = 0,
    this.easeFactor = defaultEaseFactor,
    this.intervalDays = 0,
    this.dueAt,
    this.lastReviewedAt,
    this.lapses = 0,
  });

  /// SM-2's starting ease.
  static const double defaultEaseFactor = 2.5;

  /// SM-2's floor. Below this, intervals stop growing meaningfully.
  static const double minEaseFactor = 1.3;

  /// The interval after the first successful review.
  static const int firstIntervalDays = 1;

  /// The interval after the second successful review.
  static const int secondIntervalDays = 6;

  /// A card that has never been reviewed.
  static const ReviewSchedule fresh = ReviewSchedule();

  /// A never-reviewed card is due immediately — a new card should be studied.
  bool isDue(DateTime now) {
    final due = dueAt;
    if (due == null) return true;
    return !now.isBefore(due);
  }

  bool get isNew => lastReviewedAt == null;

  /// Applies [grade] and returns the next schedule.
  ///
  /// A pass grows the interval (1 day → 6 days → previous × ease). A failure
  /// resets repetitions and sends the card back to tomorrow, but keeps the
  /// accumulated ease penalty so a habitually-hard card stays short.
  ReviewSchedule afterReview(ReviewGrade grade, {required DateTime now}) {
    final quality = grade.quality;

    // Ease moves on every review, pass or fail — this is SM-2's EF' formula.
    final adjusted = easeFactor +
        (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    final nextEase = math.max(minEaseFactor, adjusted);

    if (!grade.passed) {
      return ReviewSchedule(
        repetitions: 0,
        easeFactor: nextEase,
        intervalDays: firstIntervalDays,
        dueAt: _addDays(now, firstIntervalDays),
        lastReviewedAt: now,
        // Only a card that had been learned can lapse; failing a brand-new card
        // is not a lapse, it is just not learned yet.
        lapses: repetitions > 0 ? lapses + 1 : lapses,
      );
    }

    final nextRepetitions = repetitions + 1;
    final nextInterval = switch (nextRepetitions) {
      1 => firstIntervalDays,
      2 => secondIntervalDays,
      // Grow by ease. `hard` still passes but should not grow as fast, so the
      // reduced ease it just produced is what multiplies here.
      _ => math.max(1, (intervalDays * nextEase).round()),
    };

    return ReviewSchedule(
      repetitions: nextRepetitions,
      easeFactor: nextEase,
      intervalDays: nextInterval,
      dueAt: _addDays(now, nextInterval),
      lastReviewedAt: now,
      lapses: lapses,
    );
  }

  /// Days added in UTC-safe fashion: adding a Duration across a DST boundary can
  /// land on the wrong calendar day, which would make an interval visibly off by
  /// one for anyone in a DST timezone.
  static DateTime _addDays(DateTime from, int days) {
    return DateTime(
      from.year,
      from.month,
      from.day + days,
      from.hour,
      from.minute,
      from.second,
      from.millisecond,
      from.microsecond,
    );
  }

  ReviewSchedule copyWith({
    int? repetitions,
    double? easeFactor,
    int? intervalDays,
    DateTime? dueAt,
    DateTime? lastReviewedAt,
    int? lapses,
  }) =>
      ReviewSchedule(
        repetitions: repetitions ?? this.repetitions,
        easeFactor: easeFactor ?? this.easeFactor,
        intervalDays: intervalDays ?? this.intervalDays,
        dueAt: dueAt ?? this.dueAt,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
        lapses: lapses ?? this.lapses,
      );
}

/// Orders a review queue: most overdue first, new cards after cards that are
/// actually due.
///
/// New-cards-last is a deliberate choice — clearing today's due backlog matters
/// more than meeting new material, and burying the backlog under new cards is
/// how a deck becomes unmanageable.
int compareForReview(ReviewSchedule a, ReviewSchedule b, DateTime now) {
  if (a.isNew != b.isNew) return a.isNew ? 1 : -1;
  final aDue = a.dueAt;
  final bDue = b.dueAt;
  if (aDue == null || bDue == null) return 0;
  return aDue.compareTo(bDue);
}
