// Axis-aligned bounding boxes for unified [SceneElement]s.
//
// Returns the element's *local* (un-rotated) AABB. Rotation-aware selection
// bounds are layered on in Phase 4; here we provide the tight local box used by
// hit-testing, z-order banding and migration.

import 'dart:ui';

import '../model/scene_element.dart';
import 'shape_geometry.dart';

class ElementBounds {
  ElementBounds._();

  /// Local axis-aligned bounding box of [element]. Empty [Rect.zero]-ish boxes
  /// are returned for degenerate elements (no points / too little geometry).
  static Rect of(SceneElement element) {
    switch (element) {
      case FreehandElement():
        return _boundsOfPoints(
          element.points.map((p) => Offset(p.x, p.y)),
        );
      case SceneShapeElement():
        return _shapeBounds(element.shapeType, element.geometryData);
      case TextElement():
        return _rectFromLTRB(element.geometryData);
      case ImageElement():
        return _rectFromLTRB(element.geometryData);
      case FrameElement():
        return _rectFromLTRB(element.geometryData);
    }
  }

  static Rect _shapeBounds(ShapeType type, List<double> g) {
    switch (type) {
      case ShapeType.circle:
      case ShapeType.rectangle:
      case ShapeType.textBox:
      case ShapeType.svgImage:
        return _rectFromLTRB(g);
      case ShapeType.line:
      case ShapeType.arrow:
      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.diamond:
        return _boundsOfFlatPairs(g);
    }
  }

  static Rect _rectFromLTRB(List<double> g) {
    if (g.length < 4) return Rect.zero;
    return Rect.fromLTRB(g[0], g[1], g[2], g[3]).normalized();
  }

  static Rect _boundsOfFlatPairs(List<double> g) {
    final pts = <Offset>[];
    for (int i = 0; i + 1 < g.length; i += 2) {
      pts.add(Offset(g[i], g[i + 1]));
    }
    return _boundsOfPoints(pts);
  }

  static Rect _boundsOfPoints(Iterable<Offset> points) {
    return ShapeGeometry.boundingRect(points.toList());
  }
}

extension on Rect {
  /// Returns a rect with left<=right and top<=bottom.
  Rect normalized() => Rect.fromLTRB(
        left < right ? left : right,
        top < bottom ? top : bottom,
        left < right ? right : left,
        top < bottom ? bottom : top,
      );
}
