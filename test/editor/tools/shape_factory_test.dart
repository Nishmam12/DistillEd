import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/model/scene_element.dart';
import 'package:distill_ed/editor/state/editor_tool_controller.dart';
import 'package:distill_ed/editor/tools/shape_factory.dart';

void main() {
  SceneShapeElement build(ShapeType type, Offset s, Offset c) =>
      ShapeFactory.build(
        tool: EditorToolState(shapeType: type),
        start: s,
        current: c,
        id: 'x',
        zOrder: 0,
        seed: 1,
      );

  test('rectangle geometry is [l,t,r,b] from the drag', () {
    final r = build(ShapeType.rectangle, const Offset(10, 20), const Offset(50, 60));
    expect(r.geometryData, [10, 20, 50, 60]);
  });

  test('drag from bottom-right to top-left still yields a normalized rect', () {
    final r = build(ShapeType.rectangle, const Offset(50, 60), const Offset(10, 20));
    expect(r.geometryData, [10, 20, 50, 60]);
  });

  test('diamond has four vertices', () {
    final d = build(ShapeType.diamond, const Offset(0, 0), const Offset(20, 40));
    expect(d.geometryData.length, 8);
  });

  test('triangle has three vertices', () {
    final t = build(ShapeType.triangle, const Offset(0, 0), const Offset(20, 40));
    expect(t.geometryData.length, 6);
  });

  test('arrow keeps drag direction and defaults to an end triangle', () {
    final a = build(ShapeType.arrow, const Offset(0, 0), const Offset(30, 0));
    expect(a.geometryData, [0, 0, 30, 0]);
    expect(a.endArrowhead, Arrowhead.triangle);
    expect(a.startArrowhead, Arrowhead.none);
  });
}
