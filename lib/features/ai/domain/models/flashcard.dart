// A study flashcard: a front (prompt/term) and back (answer/definition),
// generated from a page and — unlike the transient quiz attempt — persisted
// (see `data/flashcards/flashcard_record.dart`). This is the pure domain model;
// the Isar entity converts to/from it.

class Flashcard {
  final String front;
  final String back;
  final int notebookId;
  final int pageId;
  final DateTime createdAt;

  const Flashcard({
    required this.front,
    required this.back,
    required this.notebookId,
    required this.pageId,
    required this.createdAt,
  });

  Flashcard copyWith({int? notebookId, int? pageId, DateTime? createdAt}) =>
      Flashcard(
        front: front,
        back: back,
        notebookId: notebookId ?? this.notebookId,
        pageId: pageId ?? this.pageId,
        createdAt: createdAt ?? this.createdAt,
      );
}
