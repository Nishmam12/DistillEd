// Isar persistence for flashcards — the first durable AI artifact (quizzes are
// transient; flashcards are a deck you keep). The pure domain model lives in
// `domain/models/flashcard.dart`; this entity converts to/from it.

import 'package:isar/isar.dart';

import '../../domain/flashcards/spaced_repetition.dart';
import '../../domain/models/flashcard.dart';

part 'flashcard_record.g.dart';

@collection
class FlashcardRecord {
  Id id = Isar.autoIncrement;

  /// Plain (non-unique) indexes emit stable where-clauses; a unique index would
  /// pull in Isar's experimental ByIndex accessors and trip `flutter analyze`
  /// (same rationale as SummaryCache).
  @Index()
  late int notebookId;

  @Index()
  late int pageId;

  late String front;
  late String back;
  late DateTime createdAt;

  // ---- spaced repetition ----------------------------------------------------
  // Flat columns rather than an embedded object: Isar queries `dueAt` directly
  // to build the review queue, and an embedded field could not be indexed.

  int repetitions = 0;
  double easeFactor = ReviewSchedule.defaultEaseFactor;
  int intervalDays = 0;
  int lapses = 0;

  /// Null for a card that has never been reviewed — which counts as due.
  @Index()
  DateTime? dueAt;

  DateTime? lastReviewedAt;

  Flashcard toDomain() => Flashcard(
        front: front,
        back: back,
        notebookId: notebookId,
        pageId: pageId,
        createdAt: createdAt,
        schedule: ReviewSchedule(
          repetitions: repetitions,
          easeFactor: easeFactor,
          intervalDays: intervalDays,
          dueAt: dueAt,
          lastReviewedAt: lastReviewedAt,
          lapses: lapses,
        ),
      );

  static FlashcardRecord fromDomain(Flashcard card) => FlashcardRecord()
    ..notebookId = card.notebookId
    ..pageId = card.pageId
    ..front = card.front
    ..back = card.back
    ..createdAt = card.createdAt
    ..repetitions = card.schedule.repetitions
    ..easeFactor = card.schedule.easeFactor
    ..intervalDays = card.schedule.intervalDays
    ..lapses = card.schedule.lapses
    ..dueAt = card.schedule.dueAt
    ..lastReviewedAt = card.schedule.lastReviewedAt;
}
