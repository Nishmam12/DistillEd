// Covers the page operations the Tier 0 page-management UI drives.
//
// [PageRepository] is Isar-backed, so it can't be constructed in a unit test.
// Dart's implicit interfaces let a fake `implements` it without ever running
// its constructor — the `_isar` field is private and so isn't part of the
// interface. The scene side uses the real [InMemorySceneElementStore].

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/domain/model/template_type.dart';
import 'package:margo/editor/state/page_notifier.dart';
import 'package:margo/features/home/data/repositories/page_repository.dart';
import 'package:margo/features/home/domain/models/note_page.dart';

/// In-memory stand-in that keeps page indexes contiguous, like the real one.
class FakePageRepository implements PageRepository {
  final List<NotePage> pages = [];
  int _nextId = 1;

  void _reindex() {
    for (var i = 0; i < pages.length; i++) {
      pages[i].pageIndex = i;
    }
  }

  @override
  Future<void> tagImport(
    int pageId, {
    required String importGroupId,
    required String importSourceName,
  }) async {
    for (final p in pages) {
      if (p.id == pageId) {
        p.importGroupId = importGroupId;
        p.importSourceName = importSourceName;
      }
    }
  }

  @override
  Future<void> setPageInfo(
    int pageId, {
    bool? bookmarked,
    String? title,
    int? templateOverride,
  }) async {
    for (final p in pages) {
      if (p.id != pageId) continue;
      if (bookmarked != null) p.bookmarked = bookmarked;
      if (title != null) p.title = title.trim();
      if (templateOverride != null) p.templateOverride = templateOverride;
    }
  }

  @override
  Future<NotePage> createPage(int notebookId) async {
    final page = NotePage()
      ..id = _nextId++
      ..notebookId = notebookId
      ..pageIndex = pages.length
      ..createdAt = DateTime.now()
      ..modifiedAt = DateTime.now();
    pages.add(page);
    _reindex();
    return page;
  }

  @override
  Future<void> deletePage(int notebookId, int pageIndex) async {
    if (pages.length <= 1) throw StateError('Cannot delete the only page.');
    pages.removeAt(pageIndex);
    _reindex();
  }

  @override
  Future<void> movePage(int notebookId, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= pages.length) return;
    final clamped = newIndex.clamp(0, pages.length - 1);
    pages.insert(clamped, pages.removeAt(oldIndex));
    _reindex();
  }

  @override
  Future<void> reorderPages(int notebookId, List<Id> newOrder) async {
    pages.sort((a, b) => newOrder.indexOf(a.id).compareTo(newOrder.indexOf(b.id)));
    _reindex();
  }

  @override
  Future<List<NotePage>> getPagesForNotebook(int notebookId) async =>
      List.of(pages);
}

FreehandElement _stroke(String id, {int zOrder = 0, String groupId = ''}) {
  return FreehandElement(
    id: id,
    zOrder: zOrder,
    groupId: groupId,
    points: const [StrokePoint(x: 1, y: 2, pressure: 1)],
    color: 0xFF000000,
    size: 2,
  );
}

void main() {
  const notebookId = 7;

  late FakePageRepository repo;
  late InMemorySceneElementStore store;
  late PageNotifier notifier;

  setUp(() {
    repo = FakePageRepository();
    store = InMemorySceneElementStore();
    notifier = PageNotifier(repo, store, notebookId);
  });

  group('duplicatePage', () {
    test('inserts the copy directly after the source page', () async {
      await notifier.initialize();
      await notifier.insertPage();
      await notifier.insertPage();
      expect(notifier.state.pages.length, 3);

      final firstId = notifier.state.pages[0].id;
      final secondId = notifier.state.pages[1].id;

      await notifier.duplicatePage(0);

      expect(notifier.state.pages.length, 4);
      expect(notifier.state.pages[0].id, firstId);
      // The copy sits at index 1, pushing the old second page to index 2.
      expect(notifier.state.pages[2].id, secondId);
      expect(notifier.state.currentPageIndex, 1);
    });

    test('copies the scene content onto the new page', () async {
      await notifier.initialize();
      final sourceId = notifier.state.pages[0].id;
      await store.upsertForPage(notebookId, sourceId, [
        _stroke('a', zOrder: 0),
        _stroke('b', zOrder: 1),
      ]);

      await notifier.duplicatePage(0);

      final copyId = notifier.state.pages[1].id;
      final copied = await store.loadForPage(copyId);
      expect(copied, hasLength(2));
      expect(copied.map((e) => e.zOrder), [0, 1]);
    });

    test('re-mints element ids so the copy does not overwrite the source',
        () async {
      await notifier.initialize();
      final sourceId = notifier.state.pages[0].id;
      await store.upsertForPage(notebookId, sourceId, [_stroke('a')]);

      await notifier.duplicatePage(0);

      final copyId = notifier.state.pages[1].id;
      final source = await store.loadForPage(sourceId);
      final copy = await store.loadForPage(copyId);

      expect(source, hasLength(1));
      expect(copy, hasLength(1));
      expect(source.single.id, 'a');
      expect(copy.single.id, isNot('a'));
    });

    test('keeps grouped elements grouped without merging into the source group',
        () async {
      await notifier.initialize();
      final sourceId = notifier.state.pages[0].id;
      await store.upsertForPage(notebookId, sourceId, [
        _stroke('a', groupId: 'g1'),
        _stroke('b', zOrder: 1, groupId: 'g1'),
      ]);

      await notifier.duplicatePage(0);

      final copy = await store.loadForPage(notifier.state.pages[1].id);
      final groups = copy.map((e) => e.groupId).toSet();
      expect(groups, hasLength(1), reason: 'copies stay in one group');
      expect(groups.single, isNot('g1'), reason: 'but not the source group');
      expect(groups.single, isNotEmpty);
    });

    test('duplicating an empty page writes no elements', () async {
      await notifier.initialize();

      await notifier.duplicatePage(0);

      expect(await store.loadForPage(notifier.state.pages[1].id), isEmpty);
    });

    test('ignores an out-of-range index', () async {
      await notifier.initialize();

      await notifier.duplicatePage(5);

      expect(notifier.state.pages, hasLength(1));
    });
  });

  group('deletePage', () {
    test('clears the deleted page\'s scene elements', () async {
      await notifier.initialize();
      await notifier.insertPage();
      final doomedId = notifier.state.pages[1].id;
      await store.upsertForPage(notebookId, doomedId, [_stroke('a')]);

      await notifier.deletePage(1);

      expect(notifier.state.pages, hasLength(1));
      expect(await store.loadForPage(doomedId), isEmpty);
    });

    test('leaves other pages\' elements untouched', () async {
      await notifier.initialize();
      await notifier.insertPage();
      final keptId = notifier.state.pages[0].id;
      final doomedId = notifier.state.pages[1].id;
      await store.upsertForPage(notebookId, keptId, [_stroke('keep')]);
      await store.upsertForPage(notebookId, doomedId, [_stroke('go')]);

      await notifier.deletePage(1);

      expect(await store.loadForPage(keptId), hasLength(1));
    });

    test('refuses to delete the only page', () async {
      await notifier.initialize();
      final onlyId = notifier.state.pages.single.id;
      await store.upsertForPage(notebookId, onlyId, [_stroke('a')]);

      await notifier.deletePage(0);

      expect(notifier.state.pages, hasLength(1));
      expect(await store.loadForPage(onlyId), hasLength(1));
    });
  });

  group('reorderPages', () {
    test('moving a page left updates the order', () async {
      await notifier.initialize();
      await notifier.insertPage();
      final secondId = notifier.state.pages[1].id;

      await notifier.reorderPages(1, 0);

      expect(notifier.state.pages[0].id, secondId);
    });

    test('order survives a reload from the repository', () async {
      await notifier.initialize();
      await notifier.insertPage();
      await notifier.insertPage();
      final thirdId = notifier.state.pages[2].id;

      await notifier.reorderPages(2, 0);
      final reloaded = await repo.getPagesForNotebook(notebookId);

      expect(reloaded.first.id, thirdId);
      expect(reloaded.map((p) => p.pageIndex), [0, 1, 2]);
    });
  });

  group('movePagesAfter', () {
    test('imported pages go right after the page the user was on', () async {
      await notifier.initialize(); // page A
      await notifier.insertPage(); // B
      await notifier.insertPage(); // C
      final ids = notifier.state.pages.map((p) => p.id).toList();
      // Two imported pages, appended at the end as the import does.
      await notifier.insertPage();
      await notifier.insertPage();
      final imported = notifier.state.pages.skip(3).map((p) => p.id).toList();

      await notifier.movePagesAfter(imported, afterIndex: 0);

      expect(notifier.state.pages.map((p) => p.id),
          [ids[0], ...imported, ids[1], ids[2]]);
      expect(notifier.state.currentPageIndex, 1,
          reason: 'opens on the first imported page');
    });

    test('after the last page is the same as at the end', () async {
      await notifier.initialize();
      await notifier.insertPage();
      final before = notifier.state.pages.map((p) => p.id).toList();
      await notifier.insertPage();
      final imported = [notifier.state.pages.last.id];

      await notifier.movePagesAfter(imported, afterIndex: 1);

      expect(notifier.state.pages.map((p) => p.id), [...before, ...imported]);
      expect(notifier.state.currentPageIndex, 2);
    });
  });

  group('several pages at once', () {
    Future<List<int>> four() async {
      await notifier.initialize();
      for (var i = 0; i < 3; i++) {
        await notifier.insertPage();
      }
      return [for (final p in notifier.state.pages) p.id];
    }

    List<int> ids() => [for (final p in notifier.state.pages) p.id];

    test('orderAfterMove lands the first moved page at the index', () {
      expect(PageNotifier.orderAfterMove([1, 2, 3, 4], {2, 3}, 0), [2, 3, 1, 4]);
      expect(PageNotifier.orderAfterMove([1, 2, 3, 4], {1}, 3), [2, 3, 4, 1]);
      expect(PageNotifier.orderAfterMove([1, 2, 3, 4], {1}, 99), [2, 3, 4, 1]);
      expect(PageNotifier.orderAfterMove([1, 2, 3, 4], {4}, 1), [1, 4, 2, 3]);
    });

    test('movePages reorders and the open page stays open', () async {
      final a = await four();
      notifier.switchPage(2); // a[2]
      await notifier.movePages([a[0], a[1]], 99);
      expect(ids(), [a[2], a[3], a[0], a[1]]);
      expect(notifier.state.pages[notifier.state.currentPageIndex].id, a[2]);
    });

    test('deletePages removes pages and their content', () async {
      final a = await four();
      await store.upsertForPage(notebookId, a[1], [_stroke('x')]);
      expect(await notifier.deletePages([a[1], a[3]]), isTrue);
      expect(ids(), [a[0], a[2]]);
      expect(await store.loadForPage(a[1]), isEmpty);
    });

    test('deletePages refuses to empty the notebook', () async {
      final a = await four();
      expect(await notifier.deletePages(a), isFalse);
      expect(ids(), a);
    });

    test('duplicatePages puts each copy right after its original', () async {
      final a = await four();
      await store.upsertForPage(notebookId, a[0], [_stroke('s')]);
      await notifier.duplicatePages([a[0], a[2]]);
      final now = ids();
      expect(now.length, 6);
      expect([now[0], now[2], now[3]], [a[0], a[1], a[2]]);
      expect(await store.loadForPage(now[1]), hasLength(1));
    });
  });

  group('bookmark, name and template', () {
    test('setBookmarked and renamePage update the page', () async {
      await notifier.initialize();
      final id = notifier.state.pages.first.id;
      await notifier.setBookmarked(id, true);
      await notifier.renamePage(id, '  Chapter 1 ');
      expect(notifier.state.pages.first.bookmarked, isTrue);
      expect(notifier.state.pages.first.title, 'Chapter 1');
    });

    test('toggleBookmarks marks a mixed set, then clears it', () async {
      await notifier.initialize();
      await notifier.insertPage();
      final a = notifier.state.pages[0].id;
      final b = notifier.state.pages[1].id;
      await notifier.setBookmarked(a, true);
      await notifier.toggleBookmarks([a, b]);
      expect(notifier.state.pages.every((p) => p.bookmarked), isTrue);
      await notifier.toggleBookmarks([a, b]);
      expect(notifier.state.pages.any((p) => p.bookmarked), isFalse);
    });

    test('a page template overrides the notebook and can be cleared',
        () async {
      await notifier.initialize();
      final page = notifier.state.pages.first;
      expect(templateForPage(page, TemplateType.ruled), TemplateType.ruled);
      await notifier.setPageTemplate(page.id, TemplateType.grid.index);
      expect(templateForPage(notifier.state.pages.first, TemplateType.ruled),
          TemplateType.grid);
      await notifier.setPageTemplate(page.id, kNotebookTemplate);
      expect(templateForPage(notifier.state.pages.first, TemplateType.ruled),
          TemplateType.ruled);
    });

    test('a duplicate keeps the bookmark, name and template', () async {
      await notifier.initialize();
      final id = notifier.state.pages.first.id;
      await notifier.setBookmarked(id, true);
      await notifier.renamePage(id, 'Proofs');
      await notifier.setPageTemplate(id, 2);
      await notifier.duplicatePage(0);
      final copy = notifier.state.pages[1];
      expect(copy.bookmarked, isTrue);
      expect(copy.title, 'Proofs');
      expect(copy.templateOverride, 2);
    });
  });
}
