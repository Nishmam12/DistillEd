import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/model/library_item.dart';
import 'package:distill_ed/domain/model/scene_element.dart';
import 'package:distill_ed/domain/services/library_service.dart';

void main() {
  final item = LibraryItem(
    id: 'lib',
    name: 'Pair',
    createdAt: DateTime(2026),
    elements: const [
      SceneShapeElement(
        id: 'a',
        zOrder: 0,
        shapeType: ShapeType.rectangle,
        geometryData: [40, 40, 60, 60],
        color: 0xFF000000,
        strokeWidth: 1,
      ),
      SceneShapeElement(
        id: 'b',
        zOrder: 1,
        shapeType: ShapeType.rectangle,
        geometryData: [70, 70, 90, 90],
        color: 0xFF000000,
        strokeWidth: 1,
      ),
    ],
  );

  test('instantiate re-ids, repositions to the drop point and re-stacks', () {
    var n = 0;
    final out = LibraryService.instantiate(
      item,
      at: const Offset(200, 200),
      nextId: () => 'new${n++}',
      baseZOrder: 5,
    );

    expect(out.length, 2);
    // Fresh ids (never the originals).
    expect(out.map((e) => e.id).toSet().intersection({'a', 'b'}), isEmpty);
    // Contiguous z-order from the base, preserving relative order.
    expect(out.map((e) => e.zOrder), [5, 6]);
    // Union top-left (was 40,40) now lands at the drop point.
    final first = out.first as SceneShapeElement;
    expect(first.geometryData[0], closeTo(200, 1e-6));
    expect(first.geometryData[1], closeTo(200, 1e-6));
  });

  test('an empty item instantiates to nothing', () {
    final empty = LibraryItem(
        id: 'e', name: 'e', createdAt: DateTime(2026), elements: const []);
    expect(
      LibraryService.instantiate(empty,
          at: Offset.zero, nextId: () => 'x', baseZOrder: 0),
      isEmpty,
    );
  });
}
