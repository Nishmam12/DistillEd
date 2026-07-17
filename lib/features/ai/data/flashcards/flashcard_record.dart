// Isar persistence for flashcards — the first durable AI artifact (quizzes are
// transient; flashcards are a deck you keep). The pure domain model lives in
// `domain/models/flashcard.dart`; this entity converts to/from it.

import 'package:isar/isar.dart';

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

  Flashcard toDomain() => Flashcard(
        front: front,
        back: back,
        notebookId: notebookId,
        pageId: pageId,
        createdAt: createdAt,
      );

  static FlashcardRecord fromDomain(Flashcard card) => FlashcardRecord()
    ..notebookId = card.notebookId
    ..pageId = card.pageId
    ..front = card.front
    ..back = card.back
    ..createdAt = card.createdAt;
}
