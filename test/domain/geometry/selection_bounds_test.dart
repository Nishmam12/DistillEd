import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/geometry/selection_bounds.dart';
import 'package:distill_ed/domain/model/scene_element.dart';

void main() {
  const box = Rect.fromLTRB(0, 0, 100, 50);

  test('union is the AABB of the selected elements', () {
    final els = [
      const SceneShapeElement(
          id: 'a',
          zOrder: 0,
          shapeType: ShapeType.rectangle,
          geometryData: [0, 0, 40, 20],
          color: 0xFF000000,
          strokeWidth: 1),
      const SceneShapeElement(
          id: 'b',
          zOrder: 0,
          shapeType: ShapeType.rectangle,
          geometryData: [60, 30, 100, 50],
          color: 0xFF000000,
          strokeWidth: 1),
    ];
    expect(SelectionBounds.union(els), const Rect.fromLTRB(0, 0, 100, 50));
  });

  test('corner resize scales both axes about the opposite corner', () {
    final r = SelectionBounds.resize(box, HandlePos.bottomRight, const Offset(200, 100));
    expect(r.anchor, const Offset(0, 0));
    expect(r.sx, closeTo(2, 1e-9));
    expect(r.sy, closeTo(2, 1e-9));
  });

  test('edge resize scales only one axis', () {
    final r = SelectionBounds.resize(box, HandlePos.right, const Offset(150, 25));
    expect(r.sx, closeTo(1.5, 1e-9));
    expect(r.sy, closeTo(1, 1e-9));
  });

  test('aspect lock equalises the scale on a corner', () {
    final r = SelectionBounds.resize(box, HandlePos.bottomRight,
        const Offset(200, 60),
        aspect: true);
    expect(r.sx, r.sy);
    expect(r.sx, closeTo(2, 1e-9)); // max(2, 1.2)
  });

  test('resize from centre anchors at the box centre', () {
    final r = SelectionBounds.resize(box, HandlePos.bottomRight,
        const Offset(100, 50),
        fromCenter: true);
    expect(r.anchor, box.center);
  });
}
