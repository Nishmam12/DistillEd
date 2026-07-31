// Manages CRUD operations for NotePages, maintaining strictly contiguous indexes.

import 'package:isar/isar.dart';

import '../../../../data/persistence/page_text_record.dart';
import '../../domain/models/note_page.dart';
import '../../domain/models/notebook.dart';

class PageRepository {
  final Isar _isar;

  PageRepository(this._isar);

  /// Ensures page indexes are strictly contiguous (0..n-1). Idempotent and
  /// awaited: it loads the pages, gathers any whose index is wrong, and writes
  /// the corrections in a single transaction. Called after each mutating
  /// transaction, so it never nests inside another write.
  Future<void> _enforceContiguity(int notebookId) async {
    final pages = await getPagesForNotebook(notebookId);
    final fixes = <NotePage>[];
    for (int i = 0; i < pages.length; i++) {
      if (pages[i].pageIndex != i) {
        pages[i].pageIndex = i;
        fixes.add(pages[i]);
      }
    }
    if (fixes.isNotEmpty) {
      await _isar.writeTxn(() async {
        await _isar.notePages.putAll(fixes);
      });
    }
  }

  /// Creates a page at the end of the notebook.
  Future<NotePage> createPage(int notebookId) async {
    final page = await _isar.writeTxn(() async {
      final notebook = await _isar.notebooks.get(notebookId);
      if (notebook == null) throw StateError('Notebook not found');

      final newPage = NotePage()
        ..notebookId = notebookId
        ..pageIndex = notebook.pageCount
        ..createdAt = DateTime.now()
        ..modifiedAt = DateTime.now();

      await _isar.notePages.put(newPage);

      notebook.pageCount += 1;
      notebook.modifiedAt = DateTime.now();
      await _isar.notebooks.put(notebook);

      return newPage;
    });

    await _enforceContiguity(notebookId);
    return page;
  }

  /// Deletes the page at [pageIndex] and decrements subsequent indexes.
  Future<void> deletePage(int notebookId, int pageIndex) async {
    await _isar.writeTxn(() async {
      final notebook = await _isar.notebooks.get(notebookId);
      if (notebook == null) throw StateError('Notebook not found');
      if (notebook.pageCount <= 1) {
        throw StateError('Cannot delete the only page.');
      }

      final pageToDelete = await _isar.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexEqualTo(pageIndex)
          .findFirst();

      if (pageToDelete != null) {
        await _isar.notePages.delete(pageToDelete.id);
        // Drop the page's searchable text with it, or erased content stays
        // findable and the note keeps matching words it no longer contains.
        await _isar.pageTextRecords
            .filter()
            .pageIdEqualTo(pageToDelete.id)
            .deleteAll();
      }

      // Decrement all pages with index > pageIndex
      final subsequentPages = await _isar.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexGreaterThan(pageIndex)
          .findAll();

      for (final page in subsequentPages) {
        page.pageIndex -= 1;
        await _isar.notePages.put(page);
      }

      notebook.pageCount -= 1;
      notebook.modifiedAt = DateTime.now();
      await _isar.notebooks.put(notebook);
    });

    await _enforceContiguity(notebookId);
  }

  /// Moves one page from [oldIndex] to [newIndex] and reindexes to remain contiguous.
  Future<void> movePage(int notebookId, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    await _isar.writeTxn(() async {
      final pages = await _isar.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .sortByPageIndex()
          .findAll();

      // Guard against out-of-range indices to avoid a RangeError.
      if (oldIndex < 0 || oldIndex >= pages.length) return;
      final clampedNew = newIndex.clamp(0, pages.length - 1);

      final page = pages.removeAt(oldIndex);
      pages.insert(clampedNew, page);

      for (int i = 0; i < pages.length; i++) {
        if (pages[i].pageIndex != i) {
          pages[i].pageIndex = i;
          await _isar.notePages.put(pages[i]);
        }
      }

      final notebook = await _isar.notebooks.get(notebookId);
      if (notebook != null) {
        notebook.modifiedAt = DateTime.now();
        await _isar.notebooks.put(notebook);
      }
    });

    await _enforceContiguity(notebookId);
  }

  /// Applies a full new ordering based on a list of NotePage IDs.
  Future<void> reorderPages(int notebookId, List<Id> newOrder) async {
    await _isar.writeTxn(() async {
      for (int i = 0; i < newOrder.length; i++) {
        final page = await _isar.notePages.get(newOrder[i]);
        if (page != null && page.notebookId == notebookId && page.pageIndex != i) {
          page.pageIndex = i;
          await _isar.notePages.put(page);
        }
      }

      final notebook = await _isar.notebooks.get(notebookId);
      if (notebook != null) {
        notebook.modifiedAt = DateTime.now();
        await _isar.notebooks.put(notebook);
      }
    });

    await _enforceContiguity(notebookId);
  }

  /// Returns a single page by notebookId and pageIndex. Null if not found.
  Future<NotePage?> loadPage(int notebookId, int pageIndex) async {
    return await _isar.notePages
        .filter()
        .notebookIdEqualTo(notebookId)
        .and()
        .pageIndexEqualTo(pageIndex)
        .findFirst();
  }

  /// Marks [pageId] as having arrived from one import.
  ///
  /// Written as its own small transaction after the page exists, rather than as
  /// an argument to [createPage]: the import flow creates a page, loads its
  /// scene, and only then drops the rendered image on it, so there is no single
  /// point where "a page from lecture.pdf" is created in one go. Tagging
  /// afterwards keeps [createPage] the one plain way to add a page.
  Future<void> tagImport(
    int pageId, {
    required String importGroupId,
    required String importSourceName,
  }) async {
    await _isar.writeTxn(() async {
      final page = await _isar.notePages.get(pageId);
      if (page == null) return;
      page.importGroupId = importGroupId;
      page.importSourceName = importSourceName;
      await _isar.notePages.put(page);
    });
  }

  /// Every page of one import, in page order.
  Future<List<NotePage>> pagesInImportGroup(
      int notebookId, String importGroupId) async {
    return await _isar.notePages
        .filter()
        .notebookIdEqualTo(notebookId)
        .and()
        .importGroupIdEqualTo(importGroupId)
        .sortByPageIndex()
        .findAll();
  }

  /// Returns all pages for [notebookId] sorted by pageIndex ascending.
  Future<List<NotePage>> getPagesForNotebook(int notebookId) async {
    return await _isar.notePages
        .filter()
        .notebookIdEqualTo(notebookId)
        .sortByPageIndex()
        .findAll();
  }

  /// Updates the modifiedAt timestamp for a specific page.
  Future<void> updateModifiedAt(int notebookId, int pageIndex) async {
    await _isar.writeTxn(() async {
      final page = await loadPage(notebookId, pageIndex);
      if (page != null) {
        page.modifiedAt = DateTime.now();
        await _isar.notePages.put(page);
      }
    });
  }

  void updateModifiedAtSync(int notebookId, int pageIndex) {
    _isar.writeTxnSync(() {
      final page = _isar.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexEqualTo(pageIndex)
          .findFirstSync();
      if (page != null) {
        page.modifiedAt = DateTime.now();
        _isar.notePages.putSync(page);
      }
    });
  }
}
