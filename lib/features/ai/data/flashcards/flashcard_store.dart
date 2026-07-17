// A small seam over Isar so the flashcard flow is unit-testable (fake the
// store) and features/ai never talks to IsarService directly outside data/.

import 'package:isar/isar.dart';

import '../../../../shared/isar/isar_service.dart';
import '../../domain/models/flashcard.dart';
import 'flashcard_record.dart';

abstract class FlashcardStore {
  /// Replaces a page's deck with [cards] (regenerating a page refreshes it
  /// rather than piling up duplicates).
  Future<void> replaceForPage(int notebookId, int pageId, List<Flashcard> cards);

  /// All cards for a notebook, oldest first.
  Future<List<Flashcard>> forNotebook(int notebookId);

  /// The cards for a single page.
  Future<List<Flashcard>> forPage(int pageId);
}

class IsarFlashcardStore implements FlashcardStore {
  @override
  Future<void> replaceForPage(
    int notebookId,
    int pageId,
    List<Flashcard> cards,
  ) {
    return IsarService.instance.writeTxn(() async {
      final collection = IsarService.instance.flashcardRecords;
      await collection.filter().pageIdEqualTo(pageId).deleteAll();
      await collection
          .putAll([for (final c in cards) FlashcardRecord.fromDomain(c)]);
    });
  }

  @override
  Future<List<Flashcard>> forNotebook(int notebookId) async {
    final rows = await IsarService.instance.flashcardRecords
        .filter()
        .notebookIdEqualTo(notebookId)
        .findAll();
    rows.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [for (final r in rows) r.toDomain()];
  }

  @override
  Future<List<Flashcard>> forPage(int pageId) async {
    final rows = await IsarService.instance.flashcardRecords
        .filter()
        .pageIdEqualTo(pageId)
        .findAll();
    return [for (final r in rows) r.toDomain()];
  }
}
