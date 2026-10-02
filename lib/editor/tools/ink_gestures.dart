// Draw-to-shape and scribble-to-erase (docs/AI_PIPELINE_PLAN.md, item 17): two
// gestures decided AFTER a stroke has been committed, from what ML Kit's ink
// models make of it.
//
//  * Hold the pen still at the end of a stroke and a rectangle, ellipse,
//    triangle or arrow drawn freehand snaps to the clean shape.
//  * Scrub back and forth over something and it is wiped out.
//
// Everything here is pure. The classifier sits behind [InkClassifier] (ML Kit in
// production, a fake in tests), and the canvas only applies what
// [resolveInkGesture] returns — it never touches the pointer pipeline, whose
// palm rejection is hard-won and must stay exactly as it is.
//
// Both are conservative on purpose: ML Kit itself warns that some gestures cannot
// be told from writing, and a mistaken snap or scribble changes what the student
// drew. So each needs the model AND an independent check of the stroke's own
// geometry, and both land as ordinary undoable steps.

import 'dart:math' as math;
import 'dart:ui';

import '../../domain/geometry/element_bounds.dart';
import '../../domain/model/scene_element.dart';

/// ML Kit Digital Ink's shape recogniser: answers RECTANGLE, TRIANGLE, ARROW or
/// ELLIPSE.
const String kShapesModel = 'zxx-Zsym-x-shapes';

/// ML Kit Digital Ink's English gesture classifier: answers `scribble`, `strike`,
/// `circle`, `caret:above`, … or `writing`.
const String kGestureModel = 'en-x-gesture';

/// How long, in milliseconds, the pen must rest at the end of a stroke to ask for
/// a shape.
///
/// ponytail: a starting point. Too short and a pause at the end of a letter
/// snaps it; too long and nobody waits for it. Tune on a stylus.
const int kSnapHoldMs = 600;

/// Pen jitter below this many SCREEN pixels is not movement.
const double _kStillPx = 6;

double _distance(StrokePoint a, StrokePoint b) =>
    math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

Rect _boundsOf(List<StrokePoint> points) {
  var left = points.first.x, right = left;
  var top = points.first.y, bottom = top;
  for (final p in points) {
    left = math.min(left, p.x);
    right = math.max(right, p.x);
    top = math.min(top, p.y);
    bottom = math.max(bottom, p.y);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

double _pathLength(List<StrokePoint> points) {
  var length = 0.0;
  for (var i = 1; i < points.length; i++) {
    length += _distance(points[i - 1], points[i]);
  }
  return length;
}

/// How long the pen has stayed where it ended up, in milliseconds: from when it
/// arrived within [epsilon] of its final position to [upMs], when it lifted.
///
/// Measured from the points, not from the last pointer event: a stylus keeps
/// reporting while it rests, with a pixel or two of jitter, so "time since the
/// last event" would never reach a hold. [epsilon] is in the points' own units —
/// pass `6 / zoom` for scene points. 0 when the points carry no timestamps.
int holdDurationMs(List<StrokePoint> points, int upMs, {double epsilon = _kStillPx}) {
  if (points.isEmpty) return 0;
  final last = points.last;
  var i = points.length - 1;
  while (i > 0 && _distance(points[i - 1], last) <= epsilon) {
    i--;
  }
  final arrived = points[i].t;
  return arrived == null ? 0 : math.max(0, upMs - arrived);
}

/// Whether a stroke was ended with a deliberate hold: the pen rested for
/// [kSnapHoldMs] AND the stroke is big enough, on the screen, to be a drawing
/// rather than a dot or a letter. [zoom] converts scene units to screen pixels.
bool isHoldToSnap(
  List<StrokePoint> points,
  int upMs, {
  double zoom = 1,
  int holdMs = kSnapHoldMs,
}) {
  if (points.length < 2) return false;
  if (holdDurationMs(points, upMs, epsilon: _kStillPx / zoom) < holdMs) {
    return false;
  }
  final bounds = _boundsOf(points);
  final screenSize = math.max(bounds.width, bounds.height) * zoom;
  return screenSize >= 40 && _pathLength(points) * zoom >= 60;
}

/// The shape an ML Kit shape label stands for, as the geometry a
/// `SceneShapeElement` takes.
typedef SnapGeometry = ({ShapeType type, List<double> geometry});

/// The clean shape for [label] (ML Kit's RECTANGLE / ELLIPSE / TRIANGLE / ARROW,
/// in any case) fitted to [points]; null for any other label or no points.
SnapGeometry? snapGeometry(String label, List<StrokePoint> points) {
  if (points.isEmpty) return null;
  final b = _boundsOf(points);

  switch (label.toUpperCase()) {
    case 'RECTANGLE':
      return (
        type: ShapeType.rectangle,
        geometry: [b.left, b.top, b.right, b.bottom],
      );
    case 'ELLIPSE':
      return (
        type: ShapeType.circle,
        geometry: [b.left, b.top, b.right, b.bottom],
      );
    case 'TRIANGLE':
      final pointUp = _wider(points, b, bottom: true) >= _wider(points, b, bottom: false);
      return (
        type: ShapeType.triangle,
        geometry: pointUp
            ? [b.left, b.bottom, b.right, b.bottom, b.center.dx, b.top]
            : [b.left, b.top, b.right, b.top, b.center.dx, b.bottom],
      );
    case 'ARROW':
      // The shaft comes first and the head's barbs after, so the tip is the point
      // farthest from where the stroke began.
      final start = points.first;
      var tip = start;
      for (final p in points) {
        if (_distance(start, p) > _distance(start, tip)) tip = p;
      }
      return (type: ShapeType.arrow, geometry: [start.x, start.y, tip.x, tip.y]);
  }
  return null;
}

/// How wide the stroke is across the bottom (or top) third of [b] — what tells a
/// triangle drawn point-up (wide at the bottom) from one drawn point-down.
double _wider(List<StrokePoint> points, Rect b, {required bool bottom}) {
  final third = b.height / 3;
  final inBand = [
    for (final p in points)
      if (bottom ? p.y >= b.bottom - third : p.y <= b.top + third) p.x,
  ];
  if (inBand.isEmpty) return 0;
  return inBand.reduce(math.max) - inBand.reduce(math.min);
}

/// Whether the stroke is scrubbing: long for its size (it doubles back over
/// itself) and with at least four reversals of direction along its main axis.
///
/// This is the stroke's own evidence, kept apart from the classifier's: a circle
/// or a flourish can fool a model, and it cannot fake this.
bool looksLikeScribble(List<StrokePoint> points) {
  if (points.length < 8) return false;
  final b = _boundsOf(points);
  final diagonal = math.sqrt(b.width * b.width + b.height * b.height);
  if (diagonal < 24) return false;
  if (_pathLength(points) / diagonal < 3) return false;

  // Count turns along whichever axis the stroke spans more of, ignoring swings
  // smaller than a fifth of that span.
  final horizontal = b.width >= b.height;
  final threshold = 0.2 * (horizontal ? b.width : b.height);
  double along(StrokePoint p) => horizontal ? p.x : p.y;

  var extreme = along(points.first);
  var direction = 0;
  var reversals = 0;
  for (final p in points) {
    final v = along(p);
    if (direction == 0) {
      if ((v - extreme).abs() >= threshold) {
        direction = v > extreme ? 1 : -1;
        extreme = v;
      }
    } else if (direction > 0) {
      if (v > extreme) {
        extreme = v;
      } else if (extreme - v >= threshold) {
        reversals++;
        direction = -1;
        extreme = v;
      }
    } else {
      if (v < extreme) {
        extreme = v;
      } else if (v - extreme >= threshold) {
        reversals++;
        direction = 1;
        extreme = v;
      }
    }
  }
  return reversals >= 4;
}

/// The elements a scribble over [scribble] wipes out: things the student drew or
/// typed that it mostly covers.
///
/// "Mostly" is 60% of the element's area inside the scribble, so a small scribble
/// never deletes a big drawing it happens to sit on, and one that merely grazes
/// something leaves it. Pictures and frames are never victims (scribbling on a
/// photo annotates it), nor locked elements, nor pixel-eraser strokes, nor the
/// scribble itself ([excludeId]).
List<SceneElement> scribbleVictims(
  List<SceneElement> scene,
  Rect scribble, {
  required String excludeId,
}) {
  final victims = <SceneElement>[];
  for (final element in scene) {
    if (element.id == excludeId || element.isLocked) continue;
    if (element is ImageElement || element is FrameElement) continue;
    if (element is FreehandElement && element.isEraser) continue;

    // Inflated so a perfectly straight line, which has no area, can be covered.
    final bounds = ElementBounds.of(element).inflate(2);
    final overlap = bounds.intersect(scribble);
    if (overlap.isEmpty) continue;
    final covered = overlap.width * overlap.height;
    if (covered >= 0.6 * bounds.width * bounds.height) victims.add(element);
  }
  return victims;
}

/// What a classifier made of one stroke.
typedef InkClass = ({String label, double? score});

/// ML Kit's ink models, behind a seam so the decisions above are tested with a
/// fake and the plugin stays in `ml_kit_ink_classifier.dart`.
abstract class InkClassifier {
  /// [stroke] classified by ML Kit model [model] ([kShapesModel] or
  /// [kGestureModel]): its best label, or null when nothing was recognised or the
  /// model is not on the device (it is never downloaded behind the student's back).
  Future<InkClass?> classify(FreehandElement stroke, {required String model});
}

/// What to do about a stroke that was just drawn.
sealed class InkGestureAction {
  const InkGestureAction();
}

/// Replace the freehand stroke with [shape], in its place.
class SnapToShape extends InkGestureAction {
  final SceneShapeElement shape;
  const SnapToShape(this.shape);
}

/// Wipe out [victims] along with the scribble that covered them.
class ScribbleErase extends InkGestureAction {
  final List<SceneElement> victims;
  const ScribbleErase(this.victims);
}

/// Decides whether [stroke] — just committed, and so already in [scene] — was a
/// gesture rather than a drawing, and which. Null for an ordinary stroke.
///
/// A scribble needs the model's word AND the stroke's own scrubbing AND something
/// under it to erase; the model is not even asked until the last two hold. A snap
/// needs the pen held at the end ([isHoldToSnap], with [upMs] the lift time and
/// [zoom] the scale of scene units to screen pixels) AND a shape label the model
/// is sure enough of to name. A scribble outranks a snap.
///
/// A classifier that is missing or fails means "ordinary stroke": a gesture the
/// student did not get costs nothing, one they did not mean costs their work.
Future<InkGestureAction?> resolveInkGesture({
  required FreehandElement stroke,
  required List<SceneElement> scene,
  required int upMs,
  required InkClassifier classifier,
  required bool snapShapes,
  required bool scribbleErase,
  required double zoom,
  required String Function() newId,
  required int seed,
}) async {
  Future<String?> ask(String model) async {
    try {
      return (await classifier.classify(stroke, model: model))?.label;
    } catch (_) {
      return null;
    }
  }

  if (scribbleErase && looksLikeScribble(stroke.points)) {
    final victims =
        scribbleVictims(scene, _boundsOf(stroke.points), excludeId: stroke.id);
    if (victims.isNotEmpty &&
        (await ask(kGestureModel))?.toLowerCase() == 'scribble') {
      return ScribbleErase(victims);
    }
  }

  if (snapShapes && isHoldToSnap(stroke.points, upMs, zoom: zoom)) {
    final label = await ask(kShapesModel);
    final snap = label == null ? null : snapGeometry(label, stroke.points);
    if (snap != null) {
      return SnapToShape(SceneShapeElement(
        id: newId(),
        zOrder: stroke.zOrder,
        shapeType: snap.type,
        geometryData: snap.geometry,
        color: stroke.color,
        strokeWidth: stroke.size,
        opacity: stroke.opacity,
        seed: seed,
      ));
    }
  }
  return null;
}
