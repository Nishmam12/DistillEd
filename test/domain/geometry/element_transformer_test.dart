import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/geometry/element_transformer.dart';
import 'package:margo/domain/geometry/scene_geometry.dart';
import 'package:margo/domain/model/scene_element.dart';

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

  test('right-handle resize of a 90-degree rotated rect grows it on screen '
      'horizontally, keeping the opposite edge', () {
    // 40x10 rect rotated 90 deg about its centre (20,5): on screen it spans
    // x 15..25, y -15..25. Dragging the right handle doubles the screen width.
    final r = _rect([0, 0, 40, 10]).copyWith(rotation: math.pi / 2);
    final before = SceneGeometry.worldAabb(r);
    final m = SceneTransformer.scaleAbout(
        r, 2, 1, before.centerLeft) as SceneShapeElement;
    final after = SceneGeometry.worldAabb(m);
    expect(after.width, closeTo(before.width * 2, 1e-6));
    expect(after.height, closeTo(before.height, 1e-6));
    expect(after.left, closeTo(before.left, 1e-6));
  });

  test('rotateAbout leaves a frame unrotated', () {
    const fr = FrameElement(id: 'f', zOrder: 0, geometryData: [0, 0, 10, 10]);
    expect(SceneTransformer.rotateAbout(fr, 1, Offset.zero), same(fr));
  });

  test('rotate/scale preview maps the source exactly as the points move', () {
    final src = FreehandElement(
      id: 'f',
      zOrder: 0,
      color: 0,
      size: 4,
      points: const [
        StrokePoint(x: 10, y: 20, pressure: 0.5),
        StrokePoint(x: 40, y: -5, pressure: 0.5),
      ],
    );
    for (final out in [
      SceneTransformer.rotateAbout(src, 0.7, const Offset(3, 9)),
      SceneTransformer.scaleAbout(src, 2, 0.5, const Offset(-4, 6)),
    ]) {
      final (from, m) = SceneTransformer.transformedFrom[out]!;
      expect(from, same(src));
      final pts = (out as FreehandElement).points;
      for (var i = 0; i < pts.length; i++) {
        final p = src.points[i];
        expect(m[0] * p.x + m[4] * p.y + m[12], closeTo(pts[i].x, 1e-9));
        expect(m[1] * p.x + m[5] * p.y + m[13], closeTo(pts[i].y, 1e-9));
      }
      SceneTransformer.settle(out);
      expect(SceneTransformer.transformedFrom[out], isNull);
    }
  });
}
