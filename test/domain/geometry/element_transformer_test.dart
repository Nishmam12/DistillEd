import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/geometry/element_transformer.dart';
import 'package:distill_ed/domain/model/scene_element.dart';

SceneShapeElement _rect(List<double> g) => SceneShapeElement(
      id: 'r',
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: g,
      color: 0xFF000000,
      strokeWidth: 2,
    );

void main() {
  test('translate moves shape geometry', () {
    final r = SceneTransformer.translate(_rect([0, 0, 10, 10]), const Offset(3, 4))
        as SceneShapeElement;
    expect(r.geometryData, [3, 4, 13, 14]);
  });

  test('translate moves freehand points', () {
    const f = FreehandElement(
        id: 'f',
        zOrder: 0,
        color: 0,
        size: 2,
        points: [StrokePoint(x: 0, y: 0), StrokePoint(x: 1, y: 1)]);
    final m = SceneTransformer.translate(f, const Offset(5, 5)) as FreehandElement;
    expect(m.points[0].x, 5);
    expect(m.points[1].y, 6);
  });

  test('scaleAbout scales geometry about the anchor', () {
    final r = SceneTransformer.scaleAbout(_rect([0, 0, 10, 10]), 2, 3, Offset.zero)
        as SceneShapeElement;
    expect(r.geometryData, [0, 0, 20, 30]);
  });

  test('scaleAbout scales freehand nib size by the average scale', () {
    const f = FreehandElement(
        id: 'f', zOrder: 0, color: 0, size: 4, points: [StrokePoint(x: 0, y: 0)]);
    final m = SceneTransformer.scaleAbout(f, 2, 2, Offset.zero) as FreehandElement;
    expect(m.size, 8);
  });

  test('rotateAbout rotates freehand points', () {
    const f = FreehandElement(
        id: 'f', zOrder: 0, color: 0, size: 2, points: [StrokePoint(x: 1, y: 0)]);
    final m = SceneTransformer.rotateAbout(f, math.pi / 2, Offset.zero)
        as FreehandElement;
    expect(m.points[0].x, closeTo(0, 1e-9));
    expect(m.points[0].y, closeTo(1, 1e-9));
  });

  test('rotateAbout a shape about its own centre sets the rotation field', () {
    final r = _rect([0, 0, 10, 10]); // centre (5,5)
    final m = SceneTransformer.rotateAbout(r, math.pi / 2, const Offset(5, 5))
        as SceneShapeElement;
    expect(m.rotation, closeTo(math.pi / 2, 1e-9));
    // geometry stays rigid; centre unchanged
    expect(m.geometryData, [0, 0, 10, 10]);
  });
}
