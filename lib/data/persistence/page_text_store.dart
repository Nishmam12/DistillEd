// Persistence boundary for per-page searchable text.
//
// Mirrors [SceneElementStore]: an abstraction so search can be unit-tested with
// an in-memory implementation and no native Isar, with the Isar-backed one used
// in production.

import 'package:isar/isar.dart';

import '../../shared/isar/isar_service.dart';
import 'page_text_record.dart';

/// One page's extracted text.
class PageText {
  final int pageId;
  final int notebookId;
  final String text;

  const PageText({
    required this.pageId,
    required this.notebookId,
    required this.text,
  });
}

abstract class PageTextStore {
  /// Writes (or replaces) the text for one page. Blank text removes the row
  /// rather than storing an empty string, so an erased page stops matching.
  Future<void> save({
    required int notebookId,
    required int pageId,
    required String text,
  });

  /// The stored text for [pageId], or '' when there is none.
  Future<String> forPage(int pageId);

  /// Every page's text for [notebookId], in page order where known.
  Future<List<PageText>> forNotebook(int notebookId);

  Future<void> deleteForPage(int pageId);

  Future<void> deleteForNotebook(int notebookId);
}

class IsarPageTextStore implements PageTextStore {
  Isar get _isar => IsarService.instance;

  @override
  Future<void> save({
    required int notebookId,
    required int pageId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await deleteForPage(pageId);
      return;
    }
    await _isar.writeTxn(() async {
      // Delete-then-insert in one transaction keeps it to one row per page
      // without a unique index (see [PageTextRecord.pageId]).
      await _isar.pageTextRecords.filter().pageIdEqualTo(pageId).deleteAll();
      await _isar.pageTextRecords.put(PageTextRecord()
        ..pageId = pageId
        ..notebookId = notebookId
        ..text = trimmed
        ..updatedAt = DateTime.now());
    });
  }

  @override
  Future<String> forPage(int pageId) async {
    final row = await _isar.pageTextRecords
        .filter()
        .pageIdEqualTo(pageId)
        .findFirst();
    return row?.text ?? '';
  }

  @override
  Future<List<PageText>> forNotebook(int notebookId) async {
    final rows = await _isar.pageTextRecords
        .filter()
        .notebookIdEqualTo(notebookId)
        .findAll();
    return [
      for (final r in rows)
        PageText(pageId: r.pageId, notebookId: r.notebookId, text: r.text),
    ];
  }

  @override
  Future<void> deleteForPage(int pageId) async {
    await _isar.writeTxn(() async {
      await _isar.pageTextRecords.filter().pageIdEqualTo(pageId).deleteAll();
    });
  }

  @override
  Future<void> deleteForNotebook(int notebookId) async {
    await _isar.writeTxn(() async {
      await _isar.pageTextRecords
          .filter()
          .notebookIdEqualTo(notebookId)
          .deleteAll();
    });
  }
}

/// In-memory store for tests.
class InMemoryPageTextStore implements PageTextStore {
  final Map<int, PageText> _byPage = {};

  @override
  Future<void> save({
    required int notebookId,
    required int pageId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _byPage.remove(pageId);
      return;
    }
    _byPage[pageId] =
        PageText(pageId: pageId, notebookId: notebookId, text: trimmed);
  }

  @override
  Future<String> forPage(int pageId) async => _byPage[pageId]?.text ?? '';

  @override
  Future<List<PageText>> forNotebook(int notebookId) async => [
        for (final p in _byPage.values)
          if (p.notebookId == notebookId) p,
      ];

  @override
  Future<void> deleteForPage(int pageId) async => _byPage.remove(pageId);

  @override
  Future<void> deleteForNotebook(int notebookId) async =>
      _byPage.removeWhere((_, p) => p.notebookId == notebookId);
}
