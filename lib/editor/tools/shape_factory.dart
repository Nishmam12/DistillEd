// Builds a [SceneShapeElement] from a drag (start → current) and the current
// tool style. Used for both the live preview and the committed shape so they
// look identical.

import 'dart:ui';

import '../../domain/model/scene_element.dart';
import '../state/editor_tool_controller.dart';

class ShapeFactory {
  ShapeFactory._();

  static SceneShapeElement build({
    required EditorToolState tool,
    required Offset start,
    required Offset current,
    required String id,
    required int zOrder,
    required int seed,
  }) {
    return SceneShapeElement(
      id: id,
      zOrder: zOrder,
      shapeType: tool.shapeType,
      geometryData: _geometry(tool.shapeType, start, current),
      color: tool.color,
      strokeWidth: tool.size,
      opacity: tool.opacity,
      hasFill: tool.hasFill,
      fillColor: tool.fillColor,
      fillStyle: tool.fillStyle,
      strokeStyle: tool.strokeStyle,
      edges: tool.edges,
      seed: seed,
      startArrowhead: tool.startArrowhead,
      endArrowhead: tool.endArrowhead,
      elbowed: tool.elbowed,
    );
  }

  static List<double> _geometry(ShapeType type, Offset s, Offset c) {
    final rect = Rect.fromPoints(s, c);
    switch (type) {
      case ShapeType.line:
      case ShapeType.arrow:
        // Keep direction (start → current) so the arrowhead lands at the end.
        return [s.dx, s.dy, c.dx, c.dy];
      case ShapeType.diamond:
        return [
          rect.center.dx, rect.top, // top
          rect.right, rect.center.dy, // right
          rect.center.dx, rect.bottom, // bottom
          rect.left, rect.center.dy, // left
        ];
      case ShapeType.triangle:
        return [
          rect.left, rect.bottom,
          rect.right, rect.bottom,
          rect.center.dx, rect.top,
        ];
      case ShapeType.circle:
      case ShapeType.rectangle:
      case ShapeType.polygon:
      case ShapeType.textBox:
      case ShapeType.svgImage:
        return [rect.left, rect.top, rect.right, rect.bottom];
    }
  }
}
