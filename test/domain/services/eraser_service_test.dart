import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/element_style.dart' show PenKind;
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/domain/services/eraser_service.dart';

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

  group('eraser modes', () {
    const shape = SceneShapeElement(
      id: 'box',
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [0, 0, 10, 10],
      color: 0xFF000000,
      strokeWidth: 1,
    );
    final elements = <SceneElement>[
      _ink('pen'),
      _ink('marker', kind: PenKind.highlighter),
      _ink('pdf-ink', locked: true),
      shape,
    ];

    test('highlighter only leaves everything else alone', () {
      expect(
          EraserService.erasable(elements, highlighterOnly: true)
              .map((e) => e.id),
          ['marker']);
      expect(EraserService.erasable(elements, highlighterOnly: false),
          same(elements));
    });

    test('whole-page actions never take a locked element', () {
      expect(
          EraserService.pageEraseTargets(elements, PageErase.handwriting)
              .map((e) => e.id),
          ['pen', 'marker']);
      expect(
          EraserService.pageEraseTargets(elements, PageErase.everything)
              .map((e) => e.id),
          ['pen', 'marker', 'box']);
    });
  });
}

FreehandElement _ink(String id, {PenKind kind = PenKind.ballpoint, bool locked = false}) =>
    FreehandElement(
      id: id,
      zOrder: 0,
      points: const [StrokePoint(x: 0, y: 0, pressure: 0.5), StrokePoint(x: 5, y: 5, pressure: 0.5)],
      color: 0xFF000000,
      size: 2,
      penKind: kind,
      isLocked: locked,
    );
