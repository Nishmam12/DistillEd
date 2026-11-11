// Active stroke layer — paints ONLY the live in-progress pen stroke (scene
// coords). This is the sole layer that repaints during pen input, so it is kept
// trivial and isolated under its own RepaintBoundary.
//
// The stroke is a mutable buffer that the painter listens to directly: a new
// point appends in place and marks the layer for repaint, with no list copy and
// no widget rebuild. Several points arriving inside one frame cost one paint.

import 'package:flutter/material.dart';

import '../../domain/model/element_style.dart';
import '../../domain/model/stroke_point.dart';
import 'freehand_path.dart';

/// The stroke being drawn right now, and how it should look.
class ActiveStroke extends ChangeNotifier {
  List<StrokePoint> _points = [];

  int _color = 0xFF000000; // ARGB
  double _size = 0;
  double _opacity = 1.0;
  PenKind _kind = PenKind.ballpoint;

  /// The live points. Owned by this object — read, do not keep or mutate; use
  /// [take] to receive them for good.
  List<StrokePoint> get points => _points;

  bool get isEmpty => _points.isEmpty;
  bool get isNotEmpty => _points.isNotEmpty;

  int get color => _color;
  double get size => _size;
  double get opacity => _opacity;
  PenKind get kind => _kind;

  /// Starts a stroke at [first], replacing whatever was in progress.
  void begin(
    StrokePoint first, {
    required int color,
    required double size,
    double opacity = 1.0,
    PenKind kind = PenKind.ballpoint,
  }) {
    _points = [first];
    _color = color;
    _size = size;
    _opacity = opacity;
    _kind = kind;
    notifyListeners();
  }

  /// Appends [point] to the stroke in progress. Ignored when none is.
  void add(StrokePoint point) {
    if (_points.isEmpty) return;
    _points.add(point);
    notifyListeners();
  }

  /// Ends the stroke and hands its points to the caller, who now owns them.
  List<StrokePoint> take() {
    final taken = _points;
    if (taken.isEmpty) return const [];
    _points = [];
    notifyListeners();
    return taken;
  }

  /// Discards the stroke in progress.
  void clear() {
    if (_points.isEmpty) return;
    _points = [];
    notifyListeners();
  }
}

class SceneActiveStrokeLayer extends CustomPainter {
  final ActiveStroke stroke;

  SceneActiveStrokeLayer(this.stroke) : super(repaint: stroke);

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (stroke.isEmpty) return;
    final path = FreehandPath.build(stroke.points, stroke.size,
        isComplete: false, kind: stroke.kind);
    if (path == null) return;
    canvas.drawPath(
        path, FreehandPath.paintFor(stroke.kind, stroke.color, stroke.opacity));
  }

  @override
  bool shouldRepaint(SceneActiveStrokeLayer oldDelegate) =>
      !identical(stroke, oldDelegate.stroke);
}
