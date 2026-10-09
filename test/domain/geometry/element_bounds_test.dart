import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/geometry/element_bounds.dart';
import 'package:distill_ed/domain/geometry/geometry_utils.dart';
import 'package:distill_ed/domain/model/scene_element.dart';

void main() {
  group('ElementBounds', () {
    test('freehand bounds wrap all points', () {
      const e = FreehandElement(
        id: 'f',
        zOrder: 0,
        color: 0xFF000000,
        size: 2,
        points: [
          StrokePoint(x: 0, y: 0),
          StrokePoint(x: 10, y: 5),
          StrokePoint(x: 3, y: 8),
        ],
      );
      expect(ElementBounds.of(e), const Rect.fromLTRB(0, 0, 10, 8));
    });

    test('rectangle shape bounds come from its [l,t,r,b]', () {
      const e = SceneShapeElement(
          id: 's',
          zOrder: 0,
          shapeType: ShapeType.rectangle,
          geometryData: [0, 0, 20, 10],
          color: 0xFF000000,
          strokeWidth: 1);
      expect(ElementBounds.of(e), const Rect.fromLTRB(0, 0, 20, 10));
    });

    test('line shape bounds wrap its endpoints', () {
      const e = SceneShapeElement(
          id: 's',
          zOrder: 0,
          shapeType: ShapeType.line,
          geometryData: [2, 3, 8, 3],
          color: 0xFF000000,
          strokeWidth: 1);
      expect(ElementBounds.of(e), const Rect.fromLTRB(2, 3, 8, 3));
    });

    test('text and image bounds come from their rects', () {
      const t = TextElement(
          id: 't', zOrder: 0, geometryData: [5, 5, 15, 25], text: 'x',
          color: 0xFF000000);
      const i = ImageElement(
          id: 'i', zOrder: 0, geometryData: [0, 0, 4, 4],
          relativeImagePath: 'a.png');
      expect(ElementBounds.of(t), const Rect.fromLTRB(5, 5, 15, 25));
      expect(ElementBounds.of(i), const Rect.fromLTRB(0, 0, 4, 4));
    });
  });

  group('GeometryUtils', () {
    test('pointToSegmentDistance projects onto the segment', () {
      expect(
        GeometryUtils.pointToSegmentDistance(
            const Offset(5, 5), const Offset(0, 0), const Offset(10, 0)),
        closeTo(5, 1e-9),
      );
      // Beyond the end clamps to the endpoint.
      expect(
        GeometryUtils.pointToSegmentDistance(
            const Offset(20, 0), const Offset(0, 0), const Offset(10, 0)),
        closeTo(10, 1e-9),
      );
    });

    test('rectsIntersect detects overlap and disjoint', () {
      expect(
          GeometryUtils.rectsIntersect(const Rect.fromLTRB(0, 0, 10, 10),
              const Rect.fromLTRB(5, 5, 15, 15)),
          isTrue);
      expect(
          GeometryUtils.rectsIntersect(const Rect.fromLTRB(0, 0, 10, 10),
              const Rect.fromLTRB(20, 20, 30, 30)),
          isFalse);
    });

    test('pointInPolygon inside vs outside a square', () {
      final square = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ];
      expect(GeometryUtils.pointInPolygon(const Offset(5, 5), square), isTrue);
      expect(GeometryUtils.pointInPolygon(const Offset(15, 5), square), isFalse);
    });
  });
}
