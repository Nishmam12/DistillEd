// True "pixel" erase for the unified scene — removes geometry instead of
// overlaying a clear layer.
//
// The old pixel eraser committed a FreehandElement(isEraser: true) drawn with
// BlendMode.clear, which only *visually* punched holes: the underlying
// element geometry stayed intact as one piece. That made the element eraser
// (which hit-tests real geometry) delete a whole element even after it had
// been visually split — and, since the AI pipeline reads geometry, visually
// erased ink was still recognized as text by summarization.
//
// Port of main's PixelEraserService (916e730) onto SceneElement. The caller
// passes the eraser gesture's filled outline [Path] — built with the same
// FreehandPath builder the renderer uses, so the committed cut matches the
// previewed hole (and this domain service stays free of the editor/render
// layer). Given that hole:
//   * each crossed FreehandElement splits into independent surviving
//     sub-elements;
//   * each partially-erased SceneShapeElement converts to freehand elements
//     and splits the same way (fill and roughness are dropped — the cut
//     follows the shape's ideal outline; elbowed arrows are treated as
//     straight);
//   * fully-covered elements are dropped entirely.
// Locked elements, legacy clear-blend eraser elements, text, images and
// frames are never touched. Bound text survives its cut container as a
// standalone TextElement.
//
// Interpolated points introduced by densification carry no capture timestamp
// (t = null), so a split stroke falls back to synthesized timing in
// handwriting recognition — deltas within surviving original points are lost
// only at the cut seams.

import 'dart:math' as math;
import 'dart:ui';

import '../../features/editor/domain/services/shape_geometry.dart';
import '../model/scene_element.dart';

/// The geometry changes a single pixel-erase gesture produces.
class ScenePixelEraseResult {
  /// Originals the cut removed (freehand elements and shapes).
  final List<SceneElement> removed;

  /// Surviving sub-strokes produced by the cut.
  final List<FreehandElement> added;

  const ScenePixelEraseResult({
    this.removed = const [],
    this.added = const [],
  });

  bool get isEmpty => removed.isEmpty && added.isEmpty;
}

class ScenePixelEraserService {
  ScenePixelEraserService._();

  /// Sample spacing (px) used to densify geometry before testing it against
  /// the eraser hole, so a cut through the middle of a long straight edge
  /// (whose only vertices are its far endpoints) is still detected. Kept well
  /// below a usable eraser width so a covered span always lands at least one
  /// sample.
  static const double _spacing = 1.5;

  /// Minimum surviving samples for a run to become an element — drops
  /// sub-pixel speckle at the cut edges.
  static const int _minRunLength = 2;

  /// Computes the geometry edit for erasing the filled [eraserPath] hole
  /// (scene coords — build it with `FreehandPath.build(points, size,
  /// isComplete: true)` so it matches the preview). Untouched elements are
  /// reported in neither list — only what actually changes.
  static ScenePixelEraseResult erase({
    required Path eraserPath,
    required List<SceneElement> elements,
  }) {
    final eraserBounds = eraserPath.getBounds();

    // Reserve every existing id so generated ids never collide.
    final usedIds = <String>{for (final e in elements) e.id};

    final removed = <SceneElement>[];
    final added = <FreehandElement>[];

    for (final element in elements) {
      if (element.isLocked) continue;
      switch (element) {
        case FreehandElement():
          _eraseFreehand(element, eraserPath, eraserBounds, usedIds,
              removed: removed, added: added);
        case SceneShapeElement():
          _eraseShape(element, eraserPath, eraserBounds, usedIds,
              removed: removed, added: added);
        case TextElement():
        case ImageElement():
        case FrameElement():
          break; // not splittable geometry
      }
    }

    return ScenePixelEraseResult(removed: removed, added: added);
  }

  static void _eraseFreehand(
    FreehandElement stroke,
    Path eraserPath,
    Rect eraserBounds,
    Set<String> usedIds, {
    required List<SceneElement> removed,
    required List<FreehandElement> added,
  }) {
    // Legacy clear-blend eraser elements have no geometry to cut — leave them.
    if (stroke.isEraser || stroke.points.isEmpty) return;
    if (!_strokeBounds(stroke).overlaps(eraserBounds)) return;

    final dense = _densifyPoints(stroke.points);
    final runs = _splitPoints(dense, eraserPath);
    final keptCount = runs.fold<int>(0, (n, r) => n + r.length);
    if (keptCount == dense.length) return; // nothing covered — keep as-is.

    removed.add(stroke);
    var n = 0;
    for (final run in runs) {
      if (run.length < _minRunLength) continue;
      added.add(stroke.copyWith(
        id: _uniqueId(stroke.id, ++n, usedIds),
        points: run,
      ));
    }
  }

  static void _eraseShape(
    SceneShapeElement shape,
    Path eraserPath,
    Rect eraserBounds,
    Set<String> usedIds, {
    required List<SceneElement> removed,
    required List<FreehandElement> added,
  }) {
    final outlines = _shapeOutlines(shape);
    if (outlines.isEmpty) return;
    if (!_outlineBounds(outlines, shape.strokeWidth).overlaps(eraserBounds)) {
      return;
    }

    bool touched = false;
    final shapeStrokes = <FreehandElement>[];
    final size = shape.strokeWidth <= 0 ? 2.0 : shape.strokeWidth;
    var n = 0;

    for (final (pts, closed) in outlines) {
      final dense = _densifyOffsets(pts, closed: closed);
      final runs = _splitOffsets(dense, eraserPath, closed: closed);
      final keptCount = runs.fold<int>(0, (n, r) => n + r.length);
      if (keptCount < dense.length) touched = true;
      for (final run in runs) {
        if (run.length < _minRunLength) continue;
        shapeStrokes.add(FreehandElement(
          id: _uniqueId(shape.id, ++n, usedIds),
          zOrder: shape.zOrder,
          color: shape.color,
          size: size,
          opacity: shape.opacity,
          groupId: shape.groupId,
          points: [
            for (final o in run) StrokePoint(x: o.dx, y: o.dy, pressure: 0.5),
          ],
        ));
      }
    }

    if (!touched) return; // eraser only grazed the bbox, not the outline.
    removed.add(shape);
    added.addAll(shapeStrokes);
  }

  // ---- Splitting ------------------------------------------------------------

  /// Splits [dense] into maximal runs of consecutive points NOT inside the
  /// eraser hole.
  static List<List<StrokePoint>> _splitPoints(
      List<StrokePoint> dense, Path eraser) {
    final runs = <List<StrokePoint>>[];
    var cur = <StrokePoint>[];
    for (final p in dense) {
      if (eraser.contains(Offset(p.x, p.y))) {
        if (cur.isNotEmpty) {
          runs.add(cur);
          cur = <StrokePoint>[];
        }
      } else {
        cur.add(p);
      }
    }
    if (cur.isNotEmpty) runs.add(cur);
    return runs;
  }

  /// Same, for shape outlines. For a [closed] ring, a surviving span that
  /// straddles the first/last seam is merged so the ring reopens as one
  /// connected arc.
  static List<List<Offset>> _splitOffsets(List<Offset> dense, Path eraser,
      {required bool closed}) {
    final runs = <List<Offset>>[];
    var cur = <Offset>[];
    for (final p in dense) {
      if (eraser.contains(p)) {
        if (cur.isNotEmpty) {
          runs.add(cur);
          cur = <Offset>[];
        }
      } else {
        cur.add(p);
      }
    }
    if (cur.isNotEmpty) runs.add(cur);

    if (closed && runs.length > 1) {
      if (!eraser.contains(dense.first) && !eraser.contains(dense.last)) {
        final tail = runs.removeLast();
        runs[0] = [...tail, ...runs[0]];
      }
    }
    return runs;
  }

  // ---- Densification --------------------------------------------------------

  /// Interpolated points get no capture timestamp (t stays null) — see the
  /// library-level note on recognition timing.
  static List<StrokePoint> _densifyPoints(List<StrokePoint> pts) {
    if (pts.length < 2) return List<StrokePoint>.from(pts);
    final out = <StrokePoint>[pts.first];
    for (int i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final dist =
          math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y));
      final steps = dist > _spacing ? (dist / _spacing).ceil() : 1;
      for (int s = 1; s <= steps; s++) {
        final f = s / steps;
        out.add(StrokePoint(
          x: a.x + (b.x - a.x) * f,
          y: a.y + (b.y - a.y) * f,
          pressure: a.pressure + (b.pressure - a.pressure) * f,
          simulatePressure: a.simulatePressure,
        ));
      }
    }
    return out;
  }

  static List<Offset> _densifyOffsets(List<Offset> pts,
      {required bool closed}) {
    if (pts.length < 2) return List<Offset>.from(pts);
    final out = <Offset>[pts.first];
    // A closed ring adds one extra segment (last vertex → first) so the edge
    // that closes the loop is sampled too; its final step would re-add the
    // start vertex, so it is skipped.
    final segCount = closed ? pts.length : pts.length - 1;
    for (int i = 0; i < segCount; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final dist = (b - a).distance;
      final steps = dist > _spacing ? (dist / _spacing).ceil() : 1;
      for (int s = 1; s <= steps; s++) {
        if (closed && i == segCount - 1 && s == steps) break;
        out.add(Offset.lerp(a, b, s / steps)!);
      }
    }
    return out;
  }

  // ---- Shape → polyline outlines --------------------------------------------

  /// The drawn outline(s) of [shape] as world-space polylines paired with
  /// whether each is a closed ring. Rotation is applied about the shape's
  /// centre. Elbowed arrows are approximated by their straight line.
  static List<(List<Offset>, bool)> _shapeOutlines(SceneShapeElement shape) {
    final data = shape.geometryData;
    final centre = _shapeCentre(shape);
    final rot = shape.rotation;
    Offset r(Offset p) => rot == 0 ? p : _rotateAround(p, centre, rot);
    List<Offset> rl(List<Offset> l) => [for (final p in l) r(p)];

    switch (shape.shapeType) {
      case ShapeType.line:
        final (s, e) = ShapeGeometry.lineFromGeometry(data);
        return [(rl([s, e]), false)];
      case ShapeType.arrow:
        if (data.length < 4) return const [];
        final s = Offset(data[0], data[1]);
        final e = Offset(data[2], data[3]);
        final res = <(List<Offset>, bool)>[(rl([s, e]), false)];
        if (data.length >= 8) {
          res.add((
            rl([Offset(data[4], data[5]), e, Offset(data[6], data[7])]),
            false,
          ));
        }
        return res;
      case ShapeType.rectangle:
        final rect = ShapeGeometry.rectFromGeometry(data);
        return [
          (
            rl([rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft]),
            true,
          )
        ];
      case ShapeType.circle:
        final rect = ShapeGeometry.rectFromGeometry(data);
        return [(rl(_ellipsePoints(rect)), true)];
      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.diamond:
        final v = ShapeGeometry.verticesFromGeometry(data);
        return v.length >= 2 ? [(rl(v), true)] : const [];
      case ShapeType.textBox:
      case ShapeType.svgImage:
        // SceneShapeElement never carries these kinds (they are TextElement /
        // ImageElement); defensive for the shared enum.
        return const [];
    }
  }

  static List<Offset> _ellipsePoints(Rect rect, [int steps = 64]) {
    final cx = rect.center.dx, cy = rect.center.dy;
    final rx = rect.width / 2, ry = rect.height / 2;
    return [
      for (int i = 0; i < steps; i++)
        Offset(
          cx + math.cos(i / steps * 2 * math.pi) * rx,
          cy + math.sin(i / steps * 2 * math.pi) * ry,
        ),
    ];
  }

  static Offset _rotateAround(Offset p, Offset c, double angle) {
    final cosA = math.cos(angle), sinA = math.sin(angle);
    final dx = p.dx - c.dx, dy = p.dy - c.dy;
    return Offset(c.dx + dx * cosA - dy * sinA, c.dy + dx * sinA + dy * cosA);
  }

  static Offset _shapeCentre(SceneShapeElement shape) {
    switch (shape.shapeType) {
      case ShapeType.circle:
      case ShapeType.rectangle:
      case ShapeType.textBox:
      case ShapeType.svgImage:
        return ShapeGeometry.rectFromGeometry(shape.geometryData).center;
      case ShapeType.line:
      case ShapeType.arrow:
        final (start, end) =
            ShapeGeometry.lineFromGeometry(shape.geometryData);
        return Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.diamond:
        final verts = ShapeGeometry.verticesFromGeometry(shape.geometryData);
        return verts.isEmpty ? Offset.zero : ShapeGeometry.centroid(verts);
    }
  }

  // ---- Bounds / id helpers --------------------------------------------------

  static Rect _strokeBounds(FreehandElement stroke) {
    double minX = stroke.points.first.x, maxX = minX;
    double minY = stroke.points.first.y, maxY = minY;
    for (final p in stroke.points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(stroke.size / 2 + 1);
  }

  static Rect _outlineBounds(
      List<(List<Offset>, bool)> outlines, double strokeWidth) {
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final (pts, _) in outlines) {
      for (final p in pts) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    if (minX > maxX) return Rect.zero;
    return Rect.fromLTRB(minX, minY, maxX, maxY)
        .inflate((strokeWidth <= 0 ? 2.0 : strokeWidth) / 2 + 1);
  }

  /// Derives a unique id from the source element's id, so surviving pieces
  /// stay associated with their origin.
  static String _uniqueId(String sourceId, int n, Set<String> used) {
    var candidate = '$sourceId/e$n';
    while (used.contains(candidate)) {
      n++;
      candidate = '$sourceId/e$n';
    }
    used.add(candidate);
    return candidate;
  }
}
