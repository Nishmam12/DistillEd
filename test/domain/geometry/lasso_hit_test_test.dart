import 'package:flutter_test/flutter_test.dart';

import 'package:margo/domain/geometry/scene_hit_test.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/domain/services/selection_editing.dart';

void main() {
  FreehandElement stroke(String id, List<(double, double)> pts,
          {bool locked = false}) =>
      FreehandElement(
        id: id,
        zOrder: 0,
        color: 0xFF000000,
        size: 2,
        isLocked: locked,
        points: [for (final (x, y) in pts) StrokePoint(x: x, y: y, pressure: 1)],
      );

  SceneShapeElement box(String id, double l, double t, double r, double b) =>
      SceneShapeElement(
        id: id,
        zOrder: 0,
        shapeType: ShapeType.rectangle,
        geometryData: [l, t, r, b],
        color: 0xFF000000,
        strokeWidth: 2,
      );

  // An L-shaped loop: a rectangle (0,0)-(200,200) with the top-right
  // quadrant (100,0)-(200,100) cut out.
  const lShape = [
    Offset(0, 0),
    Offset(100, 0),
    Offset(100, 100),
    Offset(200, 100),
    Offset(200, 200),
    Offset(0, 200),
  ];

  group('pointInPolygon', () {
    test('inside, outside and in the notch of a concave loop', () {
      expect(SceneHitTest.pointInPolygon(const Offset(50, 50), lShape), isTrue);
      expect(SceneHitTest.pointInPolygon(const Offset(150, 150), lShape), isTrue);
      expect(SceneHitTest.pointInPolygon(const Offset(150, 50), lShape), isFalse,
          reason: 'the cut-out corner');
      expect(SceneHitTest.pointInPolygon(const Offset(300, 300), lShape), isFalse);
    });
  });

  group('withinPolygon', () {
    test('takes what the loop encloses, not what only its box touches', () {
      final inside = stroke('in', [(20, 20), (60, 40), (80, 80)]);
      final notch = stroke('notch', [(130, 20), (160, 40), (180, 80)]);
      final far = stroke('far', [(400, 400), (420, 420)]);
      expect(
          SceneHitTest.withinPolygon(lShape, [inside, notch, far]), ['in']);
    });

    test('a stroke half in, half out is taken only past the share', () {
      // 3 of 5 points inside (0.6) is taken; 2 of 5 is not.
      final mostly = stroke('m', [
        (10, 10), (20, 20), (30, 30), (300, 300), (310, 310)
      ]);
      final partly = stroke('p', [
        (10, 10), (20, 20), (300, 300), (310, 310), (320, 320)
      ]);
      expect(SceneHitTest.withinPolygon(lShape, [mostly, partly]), ['m']);
    });

    test('a shape is taken when its box is mostly inside', () {
      final yes = box('y', 20, 120, 90, 190);
      final no = box('n', 120, 20, 190, 90);
      expect(SceneHitTest.withinPolygon(lShape, [yes, no]), ['y']);
    });

    test('locked elements are left unless asked for', () {
      final paper = stroke('lock', [(20, 20), (60, 60)], locked: true);
      expect(SceneHitTest.withinPolygon(lShape, [paper]), isEmpty);
      expect(
          SceneHitTest.withinPolygon(lShape, [paper], includeLocked: true),
          ['lock']);
    });

    test('fewer than three points is no loop', () {
      expect(
          SceneHitTest.withinPolygon(
              const [Offset(0, 0), Offset(10, 10)], [box('a', 0, 0, 5, 5)]),
          isEmpty);
    });
  });

  group('recolour and thickness', () {
    test('colour reaches ink, shapes and text, and leaves images alone', () {
      final ink = stroke('i', [(0, 0), (5, 5)]);
      final shape = box('s', 0, 0, 10, 10);
      const text = TextElement(
          id: 't',
          zOrder: 0,
          geometryData: [0, 0, 50, 20],
          text: 'x',
          color: 0xFF000000,
          fontSize: 20,
          fontFamily: 'Roboto');
      const image = ImageElement(
          id: 'p',
          zOrder: 0,
          geometryData: [0, 0, 10, 10],
          relativeImagePath: 'p.png');

      expect(SelectionEditing.hasColor(ink), isTrue);
      expect(SelectionEditing.hasColor(image), isFalse);
      expect((SelectionEditing.withColor(ink, 0xFFFF0000) as FreehandElement).color,
          0xFFFF0000);
      expect(
          (SelectionEditing.withColor(shape, 0xFF00FF00) as SceneShapeElement)
              .color,
          0xFF00FF00);
      expect((SelectionEditing.withColor(text, 0xFF0000FF) as TextElement).color,
          0xFF0000FF);
      expect(SelectionEditing.withColor(image, 0xFFFF0000), same(image));
    });

    test('thickness sets a stroke size or a shape line width only', () {
      final ink = stroke('i', [(0, 0), (5, 5)]);
      final shape = box('s', 0, 0, 10, 10);
      expect((SelectionEditing.withThickness(ink, 8) as FreehandElement).size, 8);
      expect(
          (SelectionEditing.withThickness(shape, 8) as SceneShapeElement)
              .strokeWidth,
          8);
      expect(SelectionEditing.thicknessOf(ink), 2);
      expect(SelectionEditing.thicknessOf(shape), 2);
      expect(SelectionEditing.hasThickness(ink), isTrue);
    });
  });
}
