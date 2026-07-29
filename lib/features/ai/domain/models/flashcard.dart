// A study flashcard: a front (prompt/term) and back (answer/definition),
// generated from a page and — unlike the transient quiz attempt — persisted
// (see `data/flashcards/flashcard_record.dart`). This is the pure domain model;
// the Isar entity converts to/from it.

import '../flashcards/spaced_repetition.dart';

class Flashcard {
  final String front;
  final String back;
  final int notebookId;
  final int pageId;
  final DateTime createdAt;

  /// Spaced-repetition state. Defaults to [ReviewSchedule.fresh] so a
  /// newly-generated card is due immediately.
  final ReviewSchedule schedule;

  const Flashcard({
    required this.front,
    required this.back,
    required this.notebookId,
    required this.pageId,
    required this.createdAt,
    this.schedule = ReviewSchedule.fresh,
  });

  /// Stable identity for a card within its page.
  ///
  /// Regenerating a page's deck replaces it wholesale, so without a key that
  /// survives regeneration every card's review history would be thrown away
  /// each time the user re-ran generation. The front is what identifies a card
  /// to a learner, so it is the key — case- and whitespace-folded so trivial
  /// rewording does not orphan the schedule.
  String get identityKey => front.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );

  bool isDue(DateTime now) => schedule.isDue(now);

  Flashcard copyWith({
    int? notebookId,
    int? pageId,
    DateTime? createdAt,
    ReviewSchedule? schedule,
  }) =>
      Flashcard(
        front: front,
        back: back,
        notebookId: notebookId ?? this.notebookId,
        pageId: pageId ?? this.pageId,
        createdAt: createdAt ?? this.createdAt,
        schedule: schedule ?? this.schedule,
      );

  /// Applies a review grade, returning the card with its next schedule.
  Flashcard graded(ReviewGrade grade, {required DateTime now}) =>
      copyWith(schedule: schedule.afterReview(grade, now: now));
}

/// Carries review state across a deck regeneration.
///
/// Returns [fresh] cards with the schedule of any [existing] card sharing their
/// [Flashcard.identityKey], so re-running generation on a page the learner has
/// already studied keeps their progress instead of resetting the whole deck to
/// day zero.
List<Flashcard> preserveSchedules(
  List<Flashcard> fresh,
  Iterable<Flashcard> existing,
) {
  if (fresh.isEmpty) return fresh;
  final byKey = <String, ReviewSchedule>{
    for (final card in existing) card.identityKey: card.schedule,
  };
  return [
    for (final card in fresh)
      if (byKey[card.identityKey] case final kept?)
        card.copyWith(schedule: kept)
      else
        card,
  ];
}

/// The cards due for review at [now], most overdue first, new cards last.
List<Flashcard> selectDue(Iterable<Flashcard> cards, DateTime now) {
  final due = [
    for (final card in cards)
      if (card.isDue(now)) card,
  ];
  due.sort((a, b) => compareForReview(a.schedule, b.schedule, now));
  return due;
}
