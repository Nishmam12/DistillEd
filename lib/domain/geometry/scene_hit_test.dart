// Hit-testing for selection: topmost element under a point, and all elements
// overlapping a marquee rectangle. Both work in scene coordinates and account
// for element rotation.

import 'dart:math' as math;
import 'dart:ui';

import '../model/scene_element.dart';
import 'element_bounds.dart';
import 'geometry_utils.dart';
import 'scene_geometry.dart';

class SceneHitTest {
  SceneHitTest._();

  /// Id of the topmost (highest zOrder) element whose body contains [scenePoint].
  static String? topmostAt(
    Offset scenePoint,
    List<SceneElement> elements, {
    bool includeLocked = false,
    double tolerance = 6,
  }) {
    final sorted = [...elements]..sort((a, b) => b.zOrder.compareTo(a.zOrder));
    for (final e in sorted) {
      if (e.isLocked && !includeLocked) continue;
      if (touches(e, scenePoint, tolerance)) return e.id;
    }
    return null;
  }

  /// Ids of every element whose world bounds intersect [marquee].
  static List<String> within(
    Rect marquee,
    List<SceneElement> elements, {
    bool includeLocked = false,
  }) {
    final hits = <String>[];
    for (final e in elements) {
      if (e.isLocked && !includeLocked) continue;
      if (GeometryUtils.rectsIntersect(SceneGeometry.worldAabb(e), marquee)) {
        hits.add(e.id);
      }
    }
    return hits;
  }

  /// Whether [p] (scene coordinates) touches [e]'s actual body within
  /// [tolerance]: strokes and lines by distance to the polyline, unfilled
  /// shapes by their outline only, frames by their border and name label only
  /// (so a frame drawn around content never steals taps meant for it).
  static bool touches(SceneElement e, Offset p, double tolerance) {
    // Transform the point into the element's local (un-rotated) frame.
    final local = e.rotation == 0
        ? p
        : GeometryUtils.rotatePoint(p, SceneGeometry.center(e), -e.rotation);
    final box = ElementBounds.of(e);
    switch (e) {
      case FreehandElement():
        final r = e.size / 2 + tolerance;
        if (!box.inflate(r).contains(local)) return false;
        return _nearPolyline(
            [for (final q in e.points) Offset(q.x, q.y)], local, r, false);
      case SceneShapeElement():
        final r = e.strokeWidth / 2 + tolerance;
        if (!box.inflate(r).contains(local)) return false;
        return _shapeTouches(e, box, local, r);
      case FrameElement():
        final r = 0.75 + tolerance;
        if (!box.inflate(r).contains(local)) {
          return _frameLabel(e, box).inflate(tolerance).contains(local);
        }
        return !box.deflate(r).contains(local) ||
            _frameLabel(e, box).inflate(tolerance).contains(local);
      default:
        return box.inflate(tolerance).contains(local);
    }
  }

  /// Where the painter draws a frame's name (just above its top-left corner).
  static Rect _frameLabel(FrameElement f, Rect box) => Rect.fromLTWH(
      box.left, box.top - 18, math.min(400, f.name.length * 8.0 + 8), 18);

  static bool _shapeTouches(
      SceneShapeElement s, Rect box, Offset p, double r) {
    final g = s.geometryData;
    final pts = [
      for (int i = 0; i + 1 < g.length; i += 2) Offset(g[i], g[i + 1])
    ];
    switch (s.shapeType) {
      case ShapeType.line:
      case ShapeType.arrow:
        return _nearPolyline(pts, p, r, false);
      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.diamond:
        if (s.hasFill && GeometryUtils.pointInPolygon(p, pts)) return true;
        return _nearPolyline(pts, p, r, true);
      case ShapeType.rectangle:
        return s.hasFill || !box.deflate(r).contains(p);
      case ShapeType.circle:
        final rx = box.width / 2, ry = box.height / 2;
        if (rx == 0 || ry == 0) return true;
        final c = box.center;
        final d = math.sqrt(math.pow((p.dx - c.dx) / rx, 2) +
            math.pow((p.dy - c.dy) / ry, 2));
        final off = (d - 1) * math.min(rx, ry);
        return s.hasFill ? off <= r : off.abs() <= r;
      case ShapeType.textBox:
      case ShapeType.svgImage:
        return true; // already inside the inflated box
    }
  }

  static bool _nearPolyline(
      List<Offset> pts, Offset p, double r, bool closed) {
    if (pts.isEmpty) return false;
    if (pts.length == 1) return (p - pts.first).distance <= r;
    final n = closed ? pts.length : pts.length - 1;
    for (int i = 0; i < n; i++) {
      if (GeometryUtils.pointToSegmentDistance(
              p, pts[i], pts[(i + 1) % pts.length]) <=
          r) {
        return true;
      }
    }
    return false;
  }
}
