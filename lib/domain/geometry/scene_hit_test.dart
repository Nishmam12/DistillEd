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

  /// Ids of the elements a free-form lasso [loop] (scene coordinates, closed
  /// back to its start) has caught: those with at least [share] of their body
  /// inside it. A stroke counts by its own points, anything else by the corners
  /// and centre of its box, so a loop round a shape takes it and a loop that
  /// only clips an edge does not.
  static List<String> withinPolygon(
    List<Offset> loop,
    List<SceneElement> elements, {
    bool includeLocked = false,
    double share = 0.6,
  }) {
    if (loop.length < 3) return const [];
    final bounds = _polygonBounds(loop);
    final hits = <String>[];
    for (final e in elements) {
      if (e.isLocked && !includeLocked) continue;
      final box = SceneGeometry.worldAabb(e);
      if (!GeometryUtils.rectsIntersect(box, bounds)) continue;
      final samples = <Offset>[
        if (e is FreehandElement && e.points.isNotEmpty)
          for (final p in e.points)
            GeometryUtils.rotatePoint(
                Offset(p.x, p.y), SceneGeometry.center(e), e.rotation)
        else ...[
          box.topLeft,
          box.topRight,
          box.bottomLeft,
          box.bottomRight,
          box.center,
        ],
      ];
      final inside = samples.where((p) => pointInPolygon(p, loop)).length;
      if (inside / samples.length >= share) hits.add(e.id);
    }
    return hits;
  }

  /// Even-odd point-in-polygon test; the polygon is closed implicitly.
  static bool pointInPolygon(Offset p, List<Offset> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  static Rect _polygonBounds(List<Offset> pts) {
    var l = pts.first.dx, r = l, t = pts.first.dy, b = t;
    for (final p in pts) {
      if (p.dx < l) l = p.dx;
      if (p.dx > r) r = p.dx;
      if (p.dy < t) t = p.dy;
      if (p.dy > b) b = p.dy;
    }
    return Rect.fromLTRB(l, t, r, b);
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
