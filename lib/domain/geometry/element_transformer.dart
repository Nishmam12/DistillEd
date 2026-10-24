// Applies move / scale / rotate to a unified [SceneElement], returning a new
// immutable element. Mirrors the proven 1.0.2 lasso transform:
//   * Freehand ink bakes the transform into its points (it has no rotation
//     field at paint time).
//   * Shapes/text/image scale/translate their geometry; rotation is applied via
//     the `rotation` field plus orbiting the element's centre, so the geometry
//     stays rigid (matching how the painter rotates them).
// Stroke width is a style and is not scaled; freehand nib size and font size
// scale with the element so ink/text grow when resized.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../model/scene_element.dart';
import 'geometry_utils.dart';
import 'scene_geometry.dart';

class SceneTransformer {
  SceneTransformer._();

  /// A translated freehand remembers its source and offset, so the painter can
  /// shift the source's cached outline instead of re-running perfect_freehand on
  /// every pointer move of a drag.
  static final Expando<(FreehandElement, Offset)> shiftedFrom = Expando();

  /// A freehand rotated or scaled mid-gesture: its source and the affine map
  /// (column-major 4x4) from the source's outline. Preview only: the painter
  /// maps the cached source outline each frame without caching the result, and
  /// [settle] drops the mark on pen-up so the committed stroke is rebuilt exactly.
  static final Expando<(FreehandElement, Float64List)> transformedFrom =
      Expando();

  /// Ends the preview for a committed element (see [transformedFrom]).
  static void settle(SceneElement e) => transformedFrom[e] = null;

  static Float64List _affine(
          double a, double b, double c, double d, double tx, double ty) =>
      Float64List.fromList(
          [a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1]);

  static SceneElement translate(SceneElement e, Offset d) {
    final moved = _mapGeometry(e, (p) => p + d);
    if (e is FreehandElement) shiftedFrom[moved] = (e, d);
    return moved;
  }

  static SceneElement scaleAbout(
      SceneElement e, double sx, double sy, Offset anchor) {
    var fx = sx, fy = sy;
    final SceneElement scaled;
    if (e.rotation != 0 && e is! FreehandElement) {
      // The handles live on the world-space box, but the geometry is stored
      // un-rotated. Orbit the centre by the world scale, and size the geometry
      // by the scale projected onto the element's own axes so it stays a
      // rigid rotated rectangle.
      final c = SceneGeometry.center(e);
      final nc = Offset(anchor.dx + (c.dx - anchor.dx) * sx,
          anchor.dy + (c.dy - anchor.dy) * sy);
      final cos2 = math.cos(e.rotation) * math.cos(e.rotation);
      fx = cos2 * sx + (1 - cos2) * sy;
      fy = (1 - cos2) * sx + cos2 * sy;
      scaled = _mapGeometry(
        e,
        (p) => Offset(nc.dx + (p.dx - c.dx) * fx, nc.dy + (p.dy - c.dy) * fy),
      );
    } else {
      scaled = _mapGeometry(
        e,
        (p) => Offset(
          anchor.dx + (p.dx - anchor.dx) * sx,
          anchor.dy + (p.dy - anchor.dy) * sy,
        ),
      );
    }
    final avg = (fx.abs() + fy.abs()) / 2;
    if (scaled is FreehandElement) {
      final out = scaled.copyWith(size: scaled.size * avg);
      transformedFrom[out] = (
        e as FreehandElement,
        _affine(sx, 0, 0, sy, anchor.dx * (1 - sx), anchor.dy * (1 - sy)),
      );
      return out;
    }
    if (scaled is TextElement) {
      return scaled.copyWith(fontSize: scaled.fontSize * avg);
    }
    return scaled;
  }

  static SceneElement rotateAbout(SceneElement e, double angle, Offset center) {
    if (e is FreehandElement) {
      final out = e.copyWith(
        points: e.points.map((sp) {
          final r = GeometryUtils.rotatePoint(Offset(sp.x, sp.y), center, angle);
          return sp.copyWith(x: r.dx, y: r.dy);
        }).toList(),
      );
      final c = math.cos(angle), s = math.sin(angle);
      transformedFrom[out] = (
        e,
        _affine(c, s, -s, c, center.dx - center.dx * c + center.dy * s,
            center.dy - center.dx * s - center.dy * c),
      );
      return out;
    }
    // A frame is an axis-aligned container: it draws and clips unrotated, so
    // turning it would only skew its selection box away from what is drawn.
    if (e is FrameElement) return e;
    // Shapes/text/image: orbit the element centre and add to the rotation field.
    final gc = SceneGeometry.center(e);
    final nc = GeometryUtils.rotatePoint(gc, center, angle);
    final moved = translate(e, nc - gc);
    return _withRotation(moved, e.rotation + angle);
  }

  static SceneElement _mapGeometry(SceneElement e, Offset Function(Offset) f) {
    switch (e) {
      case FreehandElement():
        return e.copyWith(
          points: e.points.map((sp) {
            final p = f(Offset(sp.x, sp.y));
            return sp.copyWith(x: p.dx, y: p.dy);
          }).toList(),
        );
      case SceneShapeElement():
        return e.copyWith(geometryData: _mapPairs(e.geometryData, f));
      case TextElement():
        return e.copyWith(geometryData: _mapPairs(e.geometryData, f));
      case ImageElement():
        return e.copyWith(geometryData: _mapPairs(e.geometryData, f));
      case FrameElement():
        return e.copyWith(geometryData: _mapPairs(e.geometryData, f));
    }
  }

  static List<double> _mapPairs(List<double> g, Offset Function(Offset) f) {
    final out = List<double>.from(g);
    for (int i = 0; i + 1 < out.length; i += 2) {
      final p = f(Offset(out[i], out[i + 1]));
      out[i] = p.dx;
      out[i + 1] = p.dy;
    }
    return out;
  }

  static SceneElement _withRotation(SceneElement e, double rot) {
    switch (e) {
      case FreehandElement():
        return e.copyWith(rotation: rot);
      case SceneShapeElement():
        return e.copyWith(rotation: rot);
      case TextElement():
        return e.copyWith(rotation: rot);
      case ImageElement():
        return e.copyWith(rotation: rot);
      case FrameElement():
        return e.copyWith(rotation: rot);
    }
  }
}
