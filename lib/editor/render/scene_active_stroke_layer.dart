// Active stroke layer — paints ONLY the live in-progress pen stroke (scene
// coords). This is the sole layer that repaints during pen input, so it is kept
// trivial and isolated under its own RepaintBoundary.

import 'package:flutter/material.dart';

import '../../domain/model/stroke_point.dart';
import 'freehand_path.dart';

class SceneActiveStrokeLayer extends CustomPainter {
  final List<StrokePoint> points;
  final int color; // ARGB
  final double size;
  final double opacity;

  const SceneActiveStrokeLayer({
    required this.points,
    required this.color,
    required this.size,
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (points.isEmpty) return;
    final path = FreehandPath.build(points, size, isComplete: false);
    if (path == null) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = Color(color).withValues(alpha: opacity)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(SceneActiveStrokeLayer oldDelegate) =>
      !identical(points, oldDelegate.points) ||
      color != oldDelegate.color ||
      size != oldDelegate.size ||
      opacity != oldDelegate.opacity;
}
