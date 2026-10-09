// Hand-drawn ("rough") rendering, ported from the proven 1.0.2 rough_renderer.
// Outline edges are perturbed with a stable per-shape seed (two overlaid passes
// for the sketchy double-stroke); fills are clipped diagonal hachure lines.
// Deterministic for a given seed, so a shape looks identical on every repaint.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class RoughRenderer {
  RoughRenderer._();

  /// Wobbly outline through [points]; [closed] joins last → first.
  static Path outline(
      List<Offset> points, bool closed, int seed, double roughness) {
    final path = Path();
    if (points.length < 2) return path;
    final rng = math.Random(seed);
    final amp = (1.6 * roughness).clamp(0.0, 6.0);
    final n = points.length;
    final edgeCount = closed ? n : n - 1;

    for (int pass = 0; pass < 2; pass++) {
      for (int i = 0; i < edgeCount; i++) {
        _roughLine(path, points[i], points[(i + 1) % n], rng, amp);
      }
    }
    return path;
  }

  static void _roughLine(
      Path path, Offset a, Offset b, math.Random rng, double amp) {
    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    final perp = Offset(-d.dy, d.dx) / len;

    final a2 = a + Offset(_r(rng, amp), _r(rng, amp));
    final b2 = b + Offset(_r(rng, amp), _r(rng, amp));
    final mid =
        Offset((a2.dx + b2.dx) / 2, (a2.dy + b2.dy) / 2) + perp * _r(rng, amp);

    path.moveTo(a2.dx, a2.dy);
    path.quadraticBezierTo(mid.dx, mid.dy, b2.dx, b2.dy);
  }

  static double _r(math.Random rng, double amp) =>
      (rng.nextDouble() * 2 - 1) * amp;

  /// Fills [clipPath] with parallel 45° hachure lines.
  static void hachure(
    Canvas canvas,
    Path clipPath,
    Rect bounds,
    int seed,
    Paint linePaint, {
    double gap = 8,
  }) {
    _lines(canvas, clipPath, bounds, seed, linePaint, gap, mirror: false);
  }

  /// Fills [clipPath] with two crossing families of diagonal lines.
  static void crossHatch(
    Canvas canvas,
    Path clipPath,
    Rect bounds,
    int seed,
    Paint linePaint, {
    double gap = 8,
  }) {
    _lines(canvas, clipPath, bounds, seed, linePaint, gap, mirror: false);
    _lines(canvas, clipPath, bounds, seed ^ 0x55555555, linePaint, gap,
        mirror: true);
  }

  static void _lines(
    Canvas canvas,
    Path clipPath,
    Rect bounds,
    int seed,
    Paint linePaint,
    double gap, {
    required bool mirror,
  }) {
    // A gap that does not advance would never reach the far edge.
    if (bounds.isEmpty || gap <= 0) return;
    canvas.save();
    canvas.clipPath(clipPath);
    final rng = math.Random(seed ^ 0x9E3779B9);
    final h = bounds.height;
    for (double c = -h; c < bounds.width; c += gap) {
      final x0 = bounds.left + c;
      final j = (rng.nextDouble() * 2 - 1) * 1.5;
      if (mirror) {
        canvas.drawLine(Offset(x0 + j, bounds.bottom),
            Offset(x0 + h + j, bounds.top), linePaint);
      } else {
        canvas.drawLine(Offset(x0 + j, bounds.top),
            Offset(x0 + h + j, bounds.bottom), linePaint);
      }
    }
    canvas.restore();
  }

  /// Closed polygon approximating the ellipse inscribed in [rect].
  static List<Offset> ellipsePolygon(Rect rect, [int steps = 40]) {
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
}
