// The search-text queue on a real database: an edit marks its page ready, a
// run reads ready pages and marks them done, and a read that fails or cannot
// happen yet is retried without losing anything.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:margo/data/persistence/isar_scene_element_store.dart';
import 'package:margo/data/persistence/page_index_queue.dart';
import 'package:margo/data/persistence/page_index_task.dart';
import 'package:margo/data/persistence/page_text_store.dart';
import 'package:margo/data/persistence/scene_element_record.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/features/home/domain/models/note_page.dart';

import '../../support/isar_native_library.dart';

Future<void> main() async {
  final library = await isarNativeLibrary();
  final skip = library == null ? 'Isar native library not found' : null;

  late Directory dir;
  late Isar isar;
  late InMemoryPageTextStore texts;
  // What each page reads as; a page missing here throws.
  late Map<int, Object> reads;
  late PageIndexQueue queue;

  setUpAll(() async {
    if (library != null) await initIsarForTests(library);
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('page_index_test_');
    isar = await Isar.open(
      [NotePageSchema, PageIndexTaskSchema, SceneElementRecordSchema, AppMetaSchema],
      directory: dir.path,
      name: 'page_index',
    );
    await isar.writeTxn(() => isar.notePages.putAll([
          for (final id in [1, 2, 3])
            NotePage()
              ..id = id
              ..notebookId = 7
              ..pageIndex = id
              ..createdAt = DateTime(2026)
              ..modifiedAt = DateTime(2026),
        ]));
    texts = InMemoryPageTextStore();
    reads = {};
    queue = PageIndexQueue(
      isar: () => isar,
      texts: texts,
      readPage: (id) async {
        final r = reads[id];
        if (r is String) return (text: r, indexText: r);
        if (r is Exception) throw r;
        throw StateError('unreadable');
      },
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  Future<PageIndexTask?> row(int pageId) =>
      isar.pageIndexTasks.filter().pageIdEqualTo(pageId).findFirst();

  test('the first run reads pages with no text, and leaves pages that '
      'already have some', () async {
    await texts.save(notebookId: 7, pageId: 2, text: 'deep read');
    reads.addAll({1: 'mitosis', 2: 'light read', 3: ''});
    await queue.run();

    expect(await texts.forPage(1), 'mitosis');
    expect(await texts.forPage(2), 'deep read');
    for (final id in [1, 2, 3]) {
      expect((await row(id))!.state, PageIndexState.done);
    }
  }, skip: skip);

  test('an edit marks its page ready again, and the next run reads it',
      () async {
    reads.addAll({1: 'old', 2: '', 3: ''});
    await queue.run();
    await IsarSceneElementStore(isar: () => isar).upsertForPage(7, 1, [
      const SceneShapeElement(
        id: 'a',
        zOrder: 0,
        shapeType: ShapeType.rectangle,
        geometryData: [0, 0, 1, 1],
        color: 0xFF000000,
        strokeWidth: 1,
      ),
    ]);
    expect((await row(1))!.state, PageIndexState.ready);

    reads[1] = 'new';
    await queue.run();
    expect(await texts.forPage(1), 'new');
    expect((await row(1))!.state, PageIndexState.done);
  }, skip: skip);

  test('no handwriting model yet: stays ready and costs no attempt; a failing '
      'page gives up after three tries, until it is edited', () async {
    reads.addAll({1: const PageReadDeferred(), 3: ''}); // 2 throws
    for (var i = 0; i < PageIndexTask.maxAttempts; i++) {
      await queue.run();
    }
    final deferred = (await row(1))!;
    expect(deferred.state, PageIndexState.ready);
    expect(deferred.attempts, 0);
    expect((await row(2))!.state, PageIndexState.failed);

    await isar.writeTxn(() => markPageForIndex(isar, 2));
    expect((await row(2))!.state, PageIndexState.ready);
    expect((await row(2))!.attempts, 0);
  }, skip: skip);

  test('a page changed during its read stays ready; a deleted page loses its '
      'row', () async {
    reads.addAll({2: '', 3: ''});
    // Page 1 is edited while it is being read.
    queue = PageIndexQueue(
      isar: () => isar,
      texts: texts,
      readPage: (id) async {
        if (id == 1) await isar.writeTxn(() => markPageForIndex(isar, 1));
        return (text: 'x', indexText: 'x');
      },
    );
    await queue.run();
    expect((await row(1))!.state, PageIndexState.ready);

    await isar.writeTxn(() => isar.notePages.delete(3));
    await queue.drain();
    await queue.fill();
    expect(await row(3), isNull);
  }, skip: skip);
}
