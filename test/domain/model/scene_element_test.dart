import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/model/scene_element.dart';

void main() {
  group('SceneElement', () {
    test('each subtype reports its kind', () {
      const freehand = FreehandElement(
          id: 'f', zOrder: 0, points: [], color: 0xFF000000, size: 2);
      const shape = SceneShapeElement(
          id: 's',
          zOrder: 0,
          shapeType: ShapeType.rectangle,
          geometryData: [0, 0, 1, 1],
          color: 0xFF000000,
          strokeWidth: 1);
      const text = TextElement(
          id: 't', zOrder: 0, geometryData: [0, 0, 1, 1], text: 'hi',
          color: 0xFF000000);
      const image = ImageElement(
          id: 'i', zOrder: 0, geometryData: [0, 0, 1, 1],
          relativeImagePath: 'a.png');

      expect(freehand.kind, SceneElementKind.freehand);
      expect(shape.kind, SceneElementKind.shape);
      expect(text.kind, SceneElementKind.text);
      expect(image.kind, SceneElementKind.image);
    });

    test('copyWith overrides only the given fields', () {
      const shape = SceneShapeElement(
          id: 's',
          zOrder: 3,
          shapeType: ShapeType.circle,
          geometryData: [0, 0, 10, 10],
          color: 0xFF112233,
          strokeWidth: 2,
          seed: 42,
          roughness: 1.5);

      final moved = shape.copyWith(zOrder: 7, geometryData: [1, 1, 11, 11]);
      expect(moved.id, 's');
      expect(moved.zOrder, 7);
      expect(moved.geometryData, [1, 1, 11, 11]);
      expect(moved.seed, 42); // preserved
      expect(moved.roughness, 1.5); // preserved
      expect(moved.color, 0xFF112233); // preserved
      // original untouched
      expect(shape.zOrder, 3);
      expect(shape.geometryData, [0, 0, 10, 10]);
    });
  });
}
