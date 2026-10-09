import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/domain/services/eraser_service.dart';

SceneShapeElement _rect(String id, List<double> g, {bool locked = false}) =>
    SceneShapeElement(
      id: id,
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: g,
      color: 0xFF000000,
      strokeWidth: 1,
      isLocked: locked,
    );

void main() {
  final els = [
    _rect('a', [0, 0, 10, 10]),
    _rect('b', [100, 100, 110, 110]),
  ];

  test('hits the element under the eraser point', () {
    final hit = EraserService.hitAlongSegment(
        a: const Offset(5, 5), b: const Offset(5, 5), radius: 6, elements: els);
    expect(hit, {'a'});
  });

  test('a fast swipe catches every element it crosses', () {
    final hit = EraserService.hitAlongSegment(
        a: const Offset(5, 5),
        b: const Offset(105, 105),
        radius: 3,
        elements: els);
    expect(hit, {'a', 'b'});
  });

  test('respects the skip set', () {
    final hit = EraserService.hitAlongSegment(
        a: const Offset(5, 5),
        b: const Offset(105, 105),
        radius: 3,
        elements: els,
        skip: {'a'});
    expect(hit, {'b'});
  });

  test('never erases locked elements', () {
    final hit = EraserService.hitAlongSegment(
        a: const Offset(5, 5),
        b: const Offset(5, 5),
        radius: 4,
        elements: [_rect('a', [0, 0, 10, 10], locked: true)]);
    expect(hit, isEmpty);
  });

  test('does not erase a line when only its bounding box is touched', () {
    final line = SceneShapeElement(
        id: 'l',
        zOrder: 0,
        shapeType: ShapeType.line,
        geometryData: [0, 0, 100, 100],
        color: 0xFF000000,
        strokeWidth: 2);
    final hit = EraserService.hitAlongSegment(
        a: const Offset(90, 10),
        b: const Offset(90, 10),
        radius: 4,
        elements: [line]);
    expect(hit, isEmpty);
  });
}
