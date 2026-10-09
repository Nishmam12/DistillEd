import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/geometry/scene_hit_test.dart';
import 'package:distill_ed/domain/model/scene_element.dart';

SceneShapeElement _rect(String id, int z, List<double> g, {bool locked = false}) =>
    SceneShapeElement(
      id: id,
      zOrder: z,
      shapeType: ShapeType.rectangle,
      geometryData: g,
      color: 0xFF000000,
      strokeWidth: 2,
      isLocked: locked,
    );

void main() {
  test('topmostAt returns the highest zOrder element under the point', () {
    final els = [
      _rect('a', 0, [0, 0, 20, 20]),
      _rect('b', 1, [0, 0, 20, 20]),
    ];
    expect(SceneHitTest.topmostAt(const Offset(1, 10), els), 'b');
  });

  test('topmostAt skips locked elements by default', () {
    final els = [
      _rect('a', 0, [0, 0, 20, 20]),
      _rect('b', 1, [0, 0, 20, 20], locked: true),
    ];
    expect(SceneHitTest.topmostAt(const Offset(1, 10), els), 'a');
  });

  test('topmostAt returns null when nothing is hit', () {
    final els = [_rect('a', 0, [0, 0, 20, 20])];
    expect(SceneHitTest.topmostAt(const Offset(100, 100), els), isNull);
  });

  test('within returns all elements intersecting the marquee', () {
    final els = [
      _rect('a', 0, [0, 0, 20, 20]),
      _rect('b', 1, [100, 100, 120, 120]),
    ];
    final hit = SceneHitTest.within(const Rect.fromLTRB(-5, -5, 30, 30), els);
    expect(hit, ['a']);
    final both = SceneHitTest.within(const Rect.fromLTRB(-5, -5, 200, 200), els);
    expect(both.toSet(), {'a', 'b'});
  });

  test('an unfilled shape is hit on its outline, not its empty interior', () {
    final els = [_rect('a', 0, [0, 0, 100, 100])];
    expect(SceneHitTest.topmostAt(const Offset(50, 50), els), isNull);
    expect(SceneHitTest.topmostAt(const Offset(1, 50), els), 'a');
  });

  test('a line is hit near the stroke, not in its bounding box corner', () {
    final line = SceneShapeElement(
        id: 'l',
        zOrder: 0,
        shapeType: ShapeType.line,
        geometryData: [0, 0, 100, 100],
        color: 0xFF000000,
        strokeWidth: 2);
    expect(SceneHitTest.topmostAt(const Offset(50, 52), [line]), 'l');
    expect(SceneHitTest.topmostAt(const Offset(90, 10), [line]), isNull);
  });

  test('a freehand stroke is hit along its path only', () {
    final stroke = FreehandElement(
      id: 's',
      zOrder: 0,
      points: [
        for (final x in [0.0, 50.0, 100.0]) StrokePoint(x: x, y: x, pressure: 0.5)
      ],
      color: 0xFF000000,
      size: 4,
      opacity: 1,
    );
    expect(SceneHitTest.topmostAt(const Offset(25, 26), [stroke]), 's');
    expect(SceneHitTest.topmostAt(const Offset(90, 10), [stroke]), isNull);
  });

  test('a frame around content does not steal taps on the content or interior',
      () {
    final frame = FrameElement(
        id: 'f', zOrder: 5, geometryData: [0, 0, 200, 200], name: 'F');
    final inner = SceneShapeElement(
        id: 'r',
        zOrder: 1,
        shapeType: ShapeType.rectangle,
        geometryData: [50, 50, 100, 100],
        color: 0xFF000000,
        strokeWidth: 2,
        hasFill: true);
    expect(SceneHitTest.topmostAt(const Offset(70, 70), [inner, frame]), 'r');
    expect(SceneHitTest.topmostAt(const Offset(150, 150), [inner, frame]),
        isNull);
    expect(SceneHitTest.topmostAt(const Offset(1, 100), [inner, frame]), 'f');
  });
}
