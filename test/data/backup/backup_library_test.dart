import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/data/backup/backup_library.dart';
import 'package:margo/data/backup/notebook_archive.dart';
import 'package:margo/data/persistence/page_text_store.dart';
import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/features/home/data/repositories/note_repository.dart';
import 'package:margo/features/home/data/repositories/page_repository.dart';
import 'package:margo/features/home/domain/models/note_page.dart';
import 'package:margo/features/home/domain/models/notebook.dart';

/// Stands in for the Isar repositories: only what the backup uses.
class _Db {
  final Map<int, Notebook> notebooks = {};
  final List<NotePage> pages = [];
  int _nextNotebook = 1;
  int _nextPage = 1;

  NotePage newPage(int notebookId) {
    final p = NotePage()
      ..id = _nextPage++
      ..notebookId = notebookId
      ..pageIndex = pages.where((p) => p.notebookId == notebookId).length
      ..createdAt = DateTime(2026)
      ..modifiedAt = DateTime(2026);
    pages.add(p);
    return p;
  }
}

class _Notes implements NoteRepository {
  _Notes(this.db);
  final _Db db;

  @override
  Future<Notebook> createNotebook(String title,
      {int templateIndex = 0, int? backgroundColor, int? pageSize}) async {
    final n = Notebook()
      ..id = db._nextNotebook++
      ..title = title
      ..createdAt = DateTime(2026)
      ..modifiedAt = DateTime(2026)
      ..templateIndex = templateIndex
      ..pageSize = pageSize ?? 1;
    if (backgroundColor != null) n.backgroundColor = backgroundColor;
    db.notebooks[n.id] = n;
    db.newPage(n.id);
    return n;
  }

  @override
  Future<List<Notebook>> getAllNotebooks() async =>
      db.notebooks.values.where((n) => !n.isInTrash).toList();
  @override
  Future<Notebook?> getNotebook(int id) async => db.notebooks[id];
  @override
  Future<void> updateLayoutMode(int id, int layoutMode) async =>
      db.notebooks[id]!.layoutMode = layoutMode;
  @override
  Future<void> updatePageSize(int id, int pageSize) async =>
      db.notebooks[id]!.pageSize = pageSize;
  @override
  Future<void> setTags(int id, List<String> tags) async =>
      db.notebooks[id]!.tags = tags;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Pages implements PageRepository {
  _Pages(this.db);
  final _Db db;

  @override
  Future<NotePage> createPage(int notebookId) async => db.newPage(notebookId);
  @override
  Future<List<NotePage>> getPagesForNotebook(int notebookId) async =>
      db.pages.where((p) => p.notebookId == notebookId).toList()
        ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
  @override
  Future<void> setPageInfo(int pageId,
      {bool? bookmarked, String? title, int? templateOverride}) async {
    final p = db.pages.firstWhere((p) => p.id == pageId);
    if (bookmarked != null) p.bookmarked = bookmarked;
    if (title != null) p.title = title;
    if (templateOverride != null) p.templateOverride = templateOverride;
  }

  @override
  Future<void> tagImport(int pageId,
      {required String importGroupId, required String importSourceName}) async {
    final p = db.pages.firstWhere((p) => p.id == pageId);
    p.importGroupId = importGroupId;
    p.importSourceName = importSourceName;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late Directory docs;
  late _Db db;
  late InMemorySceneElementStore store;
  late InMemoryPageTextStore texts;
  late AppBackupLibrary library;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('margo_lib_');
    db = _Db();
    store = InMemorySceneElementStore();
    texts = InMemoryPageTextStore();
    library = AppBackupLibrary(
      notes: _Notes(db),
      pages: _Pages(db),
      elements: store,
      texts: texts,
      docsDir: docs.path,
    );
  });
  tearDown(() => docs.deleteSync(recursive: true));

  /// A notebook with handwriting on page 1 and a PDF page on page 2.
  Future<int> seed() async {
    final nb = await _Notes(db).createNotebook('Chemistry',
        templateIndex: 3, backgroundColor: 0xFFFFFDF7);
    await _Notes(db).setTags(nb.id, ['exam']);
    final second = db.newPage(nb.id);
    second
      ..importGroupId = 'import-9'
      ..importSourceName = 'slides.pdf';
    final first = db.pages.firstWhere((p) => p.notebookId == nb.id);

    await store.replaceForPage(nb.id, first.id, const [
      FreehandElement(
          id: 'ink', zOrder: 0, color: 0xFF000000, size: 3,
          penKind: PenKind.pencil,
          points: [StrokePoint(x: 0, y: 0), StrokePoint(x: 9, y: 9)]),
    ]);
    final rel = 'notes/${nb.id}/imports/pdf_h_1.png';
    File('${docs.path}/$rel')
      ..createSync(recursive: true)
      ..writeAsBytesSync([7, 7, 7]);
    File('${docs.path}/notes/${nb.id}/imports/pdf_h_1.txt')
        .writeAsStringSync('Alkanes');
    await store.replaceForPage(nb.id, second.id, [
      ImageElement(
          id: 'pdf', zOrder: 0, geometryData: const [0, 0, 10, 10],
          relativeImagePath: rel, isLocked: true),
    ]);
    await texts.save(notebookId: nb.id, pageId: first.id, text: 'Covalent bonds');
    return nb.id;
  }

  test('a snapshot holds the pages, ink, text and pictures', () async {
    final id = await seed();
    final s = (await library.snapshot(id))!;

    expect(s.meta.title, 'Chemistry');
    expect(s.meta.tags, ['exam']);
    expect(s.pages, hasLength(2));
    expect((s.pages[0].elements.single as FreehandElement).penKind, PenKind.pencil);
    expect(s.pages[0].text, 'Covalent bonds');
    expect(s.pages[1].importSourceName, 'slides.pdf');
    expect(s.media.keys, containsAll([
      'notes/$id/imports/pdf_h_1.png',
      'notes/$id/imports/pdf_h_1.txt',
    ]));
  });

  test('a bookmark, a page name and a page template survive a restore',
      () async {
    final id = await seed();
    final first = db.pages.firstWhere((p) => p.notebookId == id);
    first
      ..bookmarked = true
      ..title = 'Bonds'
      ..templateOverride = 2;
    final bytes = NotebookArchive.encode((await library.snapshot(id))!);
    final newId = await library.add(NotebookArchive.decode(bytes));

    final pages = await _Pages(db).getPagesForNotebook(newId);
    expect(pages[0].bookmarked, isTrue);
    expect(pages[0].title, 'Bonds');
    expect(pages[0].templateOverride, 2);
    expect(pages[1].bookmarked, isFalse);
    expect(pages[1].title, '');
    expect(pages[1].templateOverride, -1);
  });

  test('a notebook in the trash is not backed up', () async {
    final id = await seed();
    db.notebooks[id]!.deletedAt = DateTime(2026);
    expect(await library.snapshot(id), isNull);
    expect(await library.notebookIds(), isNot(contains(id)));
  });

  test('a notebook backed up at fit screen restores at fit screen, not A4',
      () async {
    final id = await seed();
    db.notebooks[id]!.pageSize = 0;
    final bytes = NotebookArchive.encode((await library.snapshot(id))!);
    final newId = await library.add(NotebookArchive.decode(bytes));
    expect(db.notebooks[newId]!.pageSize, 0);
  });

  test('restoring adds a copy with its own pages and files', () async {
    final id = await seed();
    final bytes = NotebookArchive.encode((await library.snapshot(id))!);

    final newId = await library.add(NotebookArchive.decode(bytes));
    expect(newId, isNot(id));

    final nb = db.notebooks[newId]!;
    expect(nb.title, 'Chemistry');
    expect(nb.templateIndex, 3);
    expect(nb.pageSize, db.notebooks[id]!.pageSize,
        reason: 'the paper size is restored as backed up');
    expect(nb.tags, ['exam']);

    final pages = await _Pages(db).getPagesForNotebook(newId);
    expect(pages, hasLength(2));
    expect(pages[1].importSourceName, 'slides.pdf');

    final image = (await store.loadForPage(pages[1].id)).single as ImageElement;
    expect(image.relativeImagePath, 'notes/$newId/imports/pdf_h_1.png');
    expect(File('${docs.path}/${image.relativeImagePath}').readAsBytesSync(),
        [7, 7, 7]);
    expect(await texts.forPage(pages[0].id), 'Covalent bonds');

    // The original is untouched.
    expect(File('${docs.path}/notes/$id/imports/pdf_h_1.png').existsSync(), isTrue);
    expect(await _Pages(db).getPagesForNotebook(id), hasLength(2));
  });
}
