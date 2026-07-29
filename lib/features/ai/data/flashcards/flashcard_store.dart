// A small seam over Isar so the flashcard flow is unit-testable (fake the
// store) and features/ai never talks to IsarService directly outside data/.

import 'package:isar/isar.dart';

import '../../../../shared/isar/isar_service.dart';
import '../../domain/models/flashcard.dart';
import 'flashcard_record.dart';

abstract class FlashcardStore {
  /// Replaces a page's deck with [cards] (regenerating a page refreshes it
  /// rather than piling up duplicates).
  ///
  /// Review schedules survive the replace: a regenerated card that matches an
  /// existing one by [Flashcard.identityKey] keeps its progress. Without that,
  /// re-running generation would silently reset the learner's whole deck.
  Future<void> replaceForPage(int notebookId, int pageId, List<Flashcard> cards);

  /// All cards for a notebook, oldest first.
  Future<List<Flashcard>> forNotebook(int notebookId);

  /// The cards for a single page.
  Future<List<Flashcard>> forPage(int pageId);

  /// The notebook's cards that are due at [now], most overdue first.
  Future<List<Flashcard>> dueForNotebook(int notebookId, DateTime now);

  /// Persists one card's updated schedule after it was graded.
  Future<void> updateSchedule(Flashcard card);
}

class IsarFlashcardStore implements FlashcardStore {
  @override
  Future<void> replaceForPage(
    int notebookId,
    int pageId,
    List<Flashcard> cards,
  ) async {
    final existing = await forPage(pageId);
    final kept = preserveSchedules(cards, existing);
    return IsarService.instance.writeTxn(() async {
      final collection = IsarService.instance.flashcardRecords;
      await collection.filter().pageIdEqualTo(pageId).deleteAll();
      await collection
          .putAll([for (final c in kept) FlashcardRecord.fromDomain(c)]);
    });
  }

  @override
  Future<List<Flashcard>> dueForNotebook(int notebookId, DateTime now) async {
    return selectDue(await forNotebook(notebookId), now);
  }

  @override
  Future<void> updateSchedule(Flashcard card) async {
    await IsarService.instance.writeTxn(() async {
      final collection = IsarService.instance.flashcardRecords;
      // Located by page + front, the same identity the domain uses; the Isar id
      // is a local storage detail the domain never carries.
      final rows =
          await collection.filter().pageIdEqualTo(card.pageId).findAll();
      final match = rows
          .where((r) => r.toDomain().identityKey == card.identityKey)
          .firstOrNull;
      if (match == null) return;
      final updated = FlashcardRecord.fromDomain(card)..id = match.id;
      await collection.put(updated);
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
