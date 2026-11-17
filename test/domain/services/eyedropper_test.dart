import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/domain/services/selection_editing.dart';

SceneShapeElement _box(String id, int z, int color) => SceneShapeElement(
      id: id,
      zOrder: z,
      shapeType: ShapeType.rectangle,
      geometryData: const [0, 0, 100, 100],
      color: color,
      strokeWidth: 4,
    );

void main() {
  test('the topmost coloured thing under the touch gives its colour', () {
    final elements = [_box('under', 0, 0xFF0000FF), _box('over', 1, 0xFFFF0000)];
    // On the outline, where both boxes are drawn.
    expect(SelectionEditing.colorAt(elements, const Offset(0, 50)), 0xFFFF0000);
  });

  test('nothing there, or nothing with a colour, gives nothing', () {
    expect(SelectionEditing.colorAt([_box('b', 0, 0xFF00FF00)],
        const Offset(500, 500)), isNull);
    expect(SelectionEditing.colorAt(const [], Offset.zero), isNull);
  });
}
