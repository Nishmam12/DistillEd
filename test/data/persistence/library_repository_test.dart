import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/data/persistence/library_repository.dart';
import 'package:distill_ed/domain/model/library_item.dart';
import 'package:distill_ed/domain/model/scene_element.dart';

LibraryItem _item(String id) => LibraryItem(
      id: id,
      name: 'Item $id',
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      elements: const [
        SceneShapeElement(
          id: 'r',
          zOrder: 0,
          shapeType: ShapeType.rectangle,
          geometryData: [0, 0, 10, 10],
          color: 0xFF000000,
          strokeWidth: 1,
        ),
      ],
    );

void main() {
  test('in-memory repository stores and returns items', () async {
    final repo = InMemoryLibraryRepository();
    expect(await repo.load(), isEmpty);
    await repo.saveAll([_item('a'), _item('b')]);
    final loaded = await repo.load();
    expect(loaded.map((i) => i.id), ['a', 'b']);
  });

  test('file repository persists to disk and reloads identically', () async {
    final dir = await Directory.systemTemp.createTemp('inkflow_lib_test');
    addTearDown(() => dir.delete(recursive: true));
    final repo = FileLibraryRepository(File('${dir.path}/library.json'));

    expect(await repo.load(), isEmpty); // missing file → empty
    await repo.saveAll([_item('a')]);

    // A fresh repository instance reads the same file back.
    final reread = await FileLibraryRepository(File('${dir.path}/library.json'))
        .load();
    expect(reread.length, 1);
    expect(reread.first.id, 'a');
    expect(reread.first.name, 'Item a');
    expect(reread.first.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(reread.first.elements.single, isA<SceneShapeElement>());
    expect((reread.first.elements.single as SceneShapeElement).geometryData,
        [0, 0, 10, 10]);
  });

  test('a damaged file loads as an empty library and is kept as .bad', () async {
    final dir = await Directory.systemTemp.createTemp('lib_bad');
    final file = File('${dir.path}/library.json')..writeAsStringSync('{not json');

    final items = await FileLibraryRepository(file).load();

    expect(items, isEmpty);
    expect(File('${file.path}.bad').readAsStringSync(), '{not json');
    expect(file.existsSync(), isFalse);
    await dir.delete(recursive: true);
  });

  test('one damaged item is skipped; the rest load and the original is kept',
      () async {
    final dir = await Directory.systemTemp.createTemp('lib_partial');
    final file = File('${dir.path}/library.json')
      ..writeAsStringSync(jsonEncode({
        'version': 1,
        'items': [
          LibraryJson.encodeItem(_item('good')),
          {'name': 'no id, so it cannot be read'},
        ],
      }));

    final items = await FileLibraryRepository(file).load();

    expect(items.map((i) => i.id), ['good'],
        reason: 'one bad entry must not hide the rest of the library');
    expect(File('${file.path}.bad').existsSync(), isTrue,
        reason: 'the next save would drop the bad entry, so keep the original');
    await dir.delete(recursive: true);
  });
}
