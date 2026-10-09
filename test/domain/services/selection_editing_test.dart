import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/model/scene_element.dart';
import 'package:distill_ed/domain/services/selection_editing.dart';

void main() {
  test('duplicate gives fresh ids, offsets geometry, and remaps groups', () {
    int n = 0;
    String nextId() => 'gen${n++}';

    final selected = [
      const SceneShapeElement(
          id: 'a',
          zOrder: 0,
          shapeType: ShapeType.rectangle,
          geometryData: [0, 0, 10, 10],
          color: 0xFF000000,
          strokeWidth: 1,
          groupId: 'g1'),
      const SceneShapeElement(
          id: 'b',
          zOrder: 0,
          shapeType: ShapeType.rectangle,
          geometryData: [20, 0, 30, 10],
          color: 0xFF000000,
          strokeWidth: 1,
          groupId: 'g1'),
    ];

    final copies = SelectionEditing.duplicate(selected,
        offset: const Offset(5, 5), nextId: nextId);

    expect(copies.length, 2);
    // new ids, not the originals
    expect(copies.map((e) => e.id).toSet().intersection({'a', 'b'}), isEmpty);
    // both copies share ONE new group, different from the original
    final groups = copies.map((e) => e.groupId).toSet();
    expect(groups.length, 1);
    expect(groups.first, isNot('g1'));
    // geometry offset applied
    final a = copies[0] as SceneShapeElement;
    expect(a.geometryData, [5, 5, 15, 15]);
  });

  test('withLocked and withGroup update the right fields', () {
    const e = FreehandElement(id: 'f', zOrder: 0, color: 0, size: 1, points: []);
    expect(SelectionEditing.withLocked(e, true).isLocked, true);
    expect(SelectionEditing.withGroup(e, 'gX').groupId, 'gX');
  });
}
