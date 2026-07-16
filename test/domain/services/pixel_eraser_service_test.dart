import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/domain/services/pixel_eraser_service.dart';
import 'package:inkflow/editor/render/freehand_path.dart';

/// Builds the eraser hole exactly like the canvas call site does.
Path eraserHole(List<StrokePoint> points, double size) =>
    FreehandPath.build(points, size, isComplete: true)!;

/// A horizontal eraser swipe centred on y=0, spanning x in [45,55].
Path midSwipe() => eraserHole(const [
      StrokePoint(x: 45, y: 0, pressure: 0.5),
      StrokePoint(x: 55, y: 0, pressure: 0.5),
    ], 12);

void main() {
  group('ScenePixelEraserService.erase — freehand elements', () {
    test('cutting the middle of a stroke splits it into two sub-strokes', () {
      final stroke = FreehandElement(
        id: 'ink1',
        zOrder: 3,
        color: 0xFF000000,
        size: 4,
        points: [
          for (int x = 0; x <= 100; x += 2)
            StrokePoint(x: x.toDouble(), y: 0, pressure: 0.5),
        ],
      );

      final result = ScenePixelEraserService.erase(
        eraserPath: midSwipe(),
        elements: [stroke],
      );

      expect(result.removed.map((e) => e.id), ['ink1']);
      expect(result.added.length, 2,
          reason: 'a mid-cut yields a left and a right sub-stroke');

      // The two pieces sit on opposite sides of the erased gap.
      final leftMaxX = result.added[0].points
          .map((p) => p.x)
          .reduce((a, b) => a > b ? a : b);
      final rightMinX = result.added[1].points
          .map((p) => p.x)
          .reduce((a, b) => a < b ? a : b);
      expect(leftMaxX, lessThan(rightMinX));

      // Survivors keep the source's look and z-order; ids stay unique.
      for (final piece in result.added) {
        expect(piece.zOrder, 3);
        expect(piece.color, 0xFF000000);
        expect(piece.size, 4);
      }
      final ids = result.added.map((e) => e.id).toSet();
      expect(ids.length, 2);
      expect(ids.contains('ink1'), isFalse);
    });

    test('an element the eraser never touches is left untouched', () {
      const stroke = FreehandElement(
        id: 'far',
        zOrder: 0,
        color: 0xFF000000,
        size: 4,
        points: [
          StrokePoint(x: 0, y: 500, pressure: 0.5),
          StrokePoint(x: 100, y: 500, pressure: 0.5),
        ],
      );

      final result = ScenePixelEraserService.erase(
        eraserPath: midSwipe(),
        elements: const [stroke],
      );

      expect(result.isEmpty, isTrue);
    });

    test('legacy clear-blend eraser elements are never cut', () {
      const eraserElement = FreehandElement(
        id: 'old-eraser',
        zOrder: 0,
        color: 0x00000000,
        size: 20,
        isEraser: true,
        points: [
          StrokePoint(x: 0, y: 0, pressure: 0.5),
          StrokePoint(x: 100, y: 0, pressure: 0.5),
        ],
      );

      final result = ScenePixelEraserService.erase(
        eraserPath: midSwipe(),
        elements: const [eraserElement],
      );

      expect(result.isEmpty, isTrue);
    });

    test('locked elements are never cut', () {
      final locked = FreehandElement(
        id: 'locked',
        zOrder: 0,
        color: 0xFF000000,
        size: 4,
        isLocked: true,
        points: [
          for (int x = 0; x <= 100; x += 2)
            StrokePoint(x: x.toDouble(), y: 0, pressure: 0.5),
        ],
      );

      final result = ScenePixelEraserService.erase(
        eraserPath: midSwipe(),
        elements: [locked],
      );

      expect(result.isEmpty, isTrue);
    });
  });

  group('ScenePixelEraserService.erase — shapes', () {
    test('cutting a rectangle edge converts the shape into strokes', () {
      const rect = SceneShapeElement(
        id: 'r',
        zOrder: 5,
        shapeType: ShapeType.rectangle,
        geometryData: [0, -50, 100, 50],
        color: 0xFF112233,
        strokeWidth: 3,
      );

      // Swipe across the left edge (x=0) so it actually cuts the border.
      final result = ScenePixelEraserService.erase(
        eraserPath: eraserHole(const [
          StrokePoint(x: -10, y: 0, pressure: 0.5),
          StrokePoint(x: 10, y: 0, pressure: 0.5),
        ], 12),
        elements: const [rect],
      );

      expect(result.removed.map((e) => e.id), ['r']);
      expect(result.added, isNotEmpty,
          reason: 'the surviving border becomes stroke geometry');
      // Converted strokes carry the shape's colour/z-order, never isEraser.
      expect(result.added.first.color, 0xFF112233);
      expect(result.added.every((e) => e.zOrder == 5), isTrue);
      expect(result.added.every((e) => !e.isEraser), isTrue);
    });

    test('a shape the eraser never touches is left as a shape', () {
      const rect = SceneShapeElement(
        id: 'r',
        zOrder: 5,
        shapeType: ShapeType.rectangle,
        geometryData: [0, 400, 100, 500],
        color: 0xFF000000,
        strokeWidth: 3,
      );

      final result = ScenePixelEraserService.erase(
        eraserPath: midSwipe(),
        elements: const [rect],
      );

      expect(result.isEmpty, isTrue);
    });

    test('text, images and frames are never cut', () {
      const text = TextElement(
        id: 't',
        zOrder: 0,
        geometryData: [40, -10, 60, 10], // right under the swipe
        text: 'hello',
        color: 0xFF000000,
      );
      const image = ImageElement(
        id: 'i',
        zOrder: 1,
        geometryData: [40, -10, 60, 10],
        relativeImagePath: 'imports/x.png',
      );
      const frame = FrameElement(
        id: 'fr',
        zOrder: 2,
        geometryData: [40, -10, 60, 10],
      );

      final result = ScenePixelEraserService.erase(
        eraserPath: midSwipe(),
        elements: const [text, image, frame],
      );

      expect(result.isEmpty, isTrue);
    });
  });
}
