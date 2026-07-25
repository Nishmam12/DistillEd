// Shared geometry for unified elements: the render/rotation centre and the
// world-space (rotation-aware) bounding box. Single source of truth so the
// painter, hit-tester and transformer all agree on where an element "is".

import 'dart:ui';

import 'shape_geometry.dart';
import '../model/scene_element.dart';
import 'element_bounds.dart';
import 'geometry_utils.dart';

class SceneGeometry {
  SceneGeometry._();

  /// The point an element rotates about (matches how the painter draws it).
  static Offset center(SceneElement e) {
    if (e is SceneShapeElement) return shapeCenter(e);
    return ElementBounds.of(e).center;
  }

  static Offset shapeCenter(SceneShapeElement s) {
    switch (s.shapeType) {
      case ShapeType.circle:
      case ShapeType.rectangle:
      case ShapeType.textBox:
      case ShapeType.svgImage:
        return ShapeGeometry.rectFromGeometry(s.geometryData).center;
      case ShapeType.line:
      case ShapeType.arrow:
        final (a, b) = ShapeGeometry.lineFromGeometry(s.geometryData);
        return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.diamond:
        final v = ShapeGeometry.verticesFromGeometry(s.geometryData);
        return v.isEmpty ? Offset.zero : ShapeGeometry.centroid(v);
    }
  }

  /// Axis-aligned bounding box in scene space, accounting for the element's
  /// rotation about its [center].
  static Rect worldAabb(SceneElement e) {
    final local = ElementBounds.of(e);
    if (e.rotation == 0) return local;
    final c = center(e);
    final corners = [
      local.topLeft,
      local.topRight,
      local.bottomRight,
      local.bottomLeft,
    ].map((p) => GeometryUtils.rotatePoint(p, c, e.rotation));
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in corners) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
