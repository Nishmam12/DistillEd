// Shared perfect_freehand stroke → Path conversion, used by both the static and
// active stroke layers so committed and in-progress ink look identical.
//
// Options match 1.0.2 exactly (thinning 0.6, smoothing 0.5, streamline 0.5,
// easing sin(t·π/2)) so ported strokes render the same.

import 'dart:math' show pi, sin;
import 'dart:ui';

// perfect_freehand also exports a `StrokePoint`; hide it so ours is unambiguous.
import 'package:perfect_freehand/perfect_freehand.dart'
    show getStroke, StrokeOptions, PointVector;

import '../../domain/model/stroke_point.dart';

class FreehandPath {
  FreehandPath._();

  /// Builds the filled outline path for [points]. Returns null when there is
  /// nothing to draw. [isComplete] tapers the tail when the stroke is finished.
  static Path? build(
    List<StrokePoint> points,
    double size, {
    required bool isComplete,
  }) {
    if (points.isEmpty) return null;

    final input =
        points.map((p) => PointVector(p.x, p.y, p.pressure)).toList();
    final simulate = points.first.simulatePressure;

    final outline = getStroke(
      input,
      options: StrokeOptions(
        size: size,
        thinning: 0.6,
        smoothing: 0.5,
        streamline: 0.5,
        easing: (t) => sin(t * pi / 2),
        simulatePressure: simulate,
        isComplete: isComplete,
      ),
    );
    if (outline.isEmpty) return null;
    return _buildPath(outline);
  }

  static Path _buildPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      path.quadraticBezierTo(
        p0.dx,
        p0.dy,
        (p0.dx + p1.dx) / 2,
        (p0.dy + p1.dy) / 2,
      );
    }
    if (points.length > 1) {
      path.lineTo(points.last.dx, points.last.dy);
    }
    path.close();
    return path;
  }
}
