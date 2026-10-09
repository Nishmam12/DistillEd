// The editor's Isar store, on a real database. A batch that names one element
// twice must leave one row for that element, not two copies of it on the page.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:distill_ed/data/persistence/isar_scene_element_store.dart';
import 'package:distill_ed/data/persistence/scene_element_record.dart';
import 'package:distill_ed/domain/model/scene_element.dart';

import '../../support/isar_native_library.dart';

SceneShapeElement _rect(String id, {required int zOrder, int color = 0xFF000000}) =>
    SceneShapeElement(
      id: id,
      zOrder: zOrder,
      shapeType: ShapeType.rectangle,
      geometryData: const [0, 0, 10, 10],
      color: color,
      strokeWidth: 1,
    );

Future<void> main() async {
  final library = await isarNativeLibrary();
  final skip = library == null ? 'Isar native library not found' : null;

  group('IsarSceneElementStore', () {
    late Directory dir;
    late Isar isar;
    late IsarSceneElementStore store;

    setUpAll(() async {
      if (library != null) await initIsarForTests(library);
    });

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('scene_store_test_');
      isar = await Isar.open(
        [SceneElementRecordSchema, AppMetaSchema],
        directory: dir.path,
        name: 'scene_store',
      );
      store = IsarSceneElementStore(isar: () => isar);
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
      await dir.delete(recursive: true);
    });

    test('a batch that names one element twice keeps one row, the last copy',
        () async {
      await store.upsertForPage(1, 10, [
        _rect('dup', zOrder: 1, color: 0xFFFF0000),
        _rect('dup', zOrder: 2, color: 0xFF00FF00),
      ]);

      final rows = await isar.sceneElementRecords.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.elementId, 'dup');
      expect(rows.single.zOrder, 2);
      expect(rows.single.color, 0xFF00FF00);
    }, skip: skip);

    test('saving the same page again replaces its elements, never duplicates',
        () async {
      await store.upsertForPage(1, 10, [_rect('a', zOrder: 0)]);
      await store.upsertForPage(1, 10, [_rect('a', zOrder: 5)]);

      final loaded = await store.loadForPage(10);
      expect(loaded.map((e) => e.id), ['a']);
      expect(loaded.single.zOrder, 5);
    }, skip: skip);
  });
}
