// Shared perfect_freehand stroke → Path conversion, used by both the static and
// active stroke layers so committed and in-progress ink look identical.
//
// Each [PenKind] is a set of perfect_freehand options plus a paint. Ballpoint
// keeps the 1.0.2 options exactly (thinning 0.6, smoothing 0.5, streamline 0.5,
// easing sin(t·π/2)) so ported strokes render the same.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

// perfect_freehand also exports a `StrokePoint`; hide it so ours is unambiguous.
import 'package:perfect_freehand/perfect_freehand.dart'
    show getStroke, StrokeOptions, PointVector;

import '../../domain/model/element_style.dart';
import '../../domain/model/stroke_point.dart';

class FreehandPath {
  FreehandPath._();

  /// How see-through a highlighter is at full opacity: enough to read the
  /// writing under it.
  static const double highlighterAlpha = 0.4;

  /// Pencil graphite is a little lighter than ink.
  static const double pencilAlpha = 0.85;

  /// Builds the filled outline path for [points] drawn with [kind]. Returns
  /// null when there is nothing to draw. [isComplete] tapers the tail when the
  /// stroke is finished.
  static Path? build(
    List<StrokePoint> points,
    double size, {
    required bool isComplete,
    PenKind kind = PenKind.ballpoint,
  }) {
    if (points.isEmpty) return null;

    final input =
        points.map((p) => PointVector(p.x, p.y, p.pressure)).toList();
    final simulate = points.first.simulatePressure;

    final outline = getStroke(
      input,
      options: _options(kind, size, simulate: simulate, isComplete: isComplete),
    );
    if (outline.isEmpty) return null;
    return _buildPath(outline);
  }

  static StrokeOptions _options(
    PenKind kind,
    double size, {
    required bool simulate,
    required bool isComplete,
  }) =>
      switch (kind) {
        PenKind.ballpoint => StrokeOptions(
            size: size,
            thinning: 0.6,
            smoothing: 0.5,
            streamline: 0.5,
            easing: (t) => math.sin(t * math.pi / 2),
            simulatePressure: simulate,
            isComplete: isComplete,
          ),
        // Strong thick-thin. Without a pressure pen, perfect_freehand derives
        // pressure from speed, so fast strokes thin out like a nib would.
        PenKind.fountain => StrokeOptions(
            size: size,
            thinning: 0.9,
            smoothing: 0.6,
            streamline: 0.45,
            easing: (t) => t,
            simulatePressure: simulate,
            isComplete: isComplete,
          ),
        // One width whatever the pressure, and a steadier line.
        PenKind.highlighter => StrokeOptions(
            size: size,
            thinning: 0,
            smoothing: 0.5,
            streamline: 0.7,
            easing: (t) => t,
            simulatePressure: false,
            isComplete: isComplete,
          ),
        PenKind.pencil => StrokeOptions(
            size: size,
            thinning: 0.45,
            smoothing: 0.4,
            streamline: 0.35,
            easing: (t) => t,
            simulatePressure: simulate,
            isComplete: isComplete,
          ),
      };

  /// The paint a stroke of [kind] fills its outline with.
  static Paint paintFor(PenKind kind, int color, double opacity) {
    final base = Color(color);
    return switch (kind) {
      PenKind.ballpoint || PenKind.fountain => Paint()
        ..color = base.withValues(alpha: base.a * opacity)
        ..style = PaintingStyle.fill,
      PenKind.highlighter => Paint()
        ..color = base.withValues(alpha: highlighterAlpha * opacity)
        ..style = PaintingStyle.fill,
      PenKind.pencil => _pencilPaint(base, opacity),
    };
  }

  static Paint _pencilPaint(Color base, double opacity) {
    final paint = Paint()
      ..color = base.withValues(alpha: pencilAlpha * opacity)
      ..style = PaintingStyle.fill;
    final grain = _PencilGrain.shader;
    if (grain == null) {
      // The grain is still being made; plain graphite until it is.
      _PencilGrain.ensure();
      return paint;
    }
    // The grain image is white with varying alpha; tint it to the pen's
    // colour. The paint's own alpha still scales the whole stroke.
    return paint
      ..shader = grain
      ..colorFilter = ColorFilter.mode(base, BlendMode.srcIn);
  }

  /// Starts making the pencil grain so the first pencil stroke has it.
  static void warmUp() => _PencilGrain.ensure();

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

/// A small tile of random grain, decoded once and repeated under pencil
/// strokes. Seeded, so pencil looks the same on every run and in exports.
class _PencilGrain {
  static const int _side = 64;
  static ui.ImageShader? shader;
  static bool _started = false;

  static void ensure() {
    if (_started) return;
    _started = true;
    final rnd = math.Random(7);
    final pixels = Uint8List(_side * _side * 4);
    for (var i = 0; i < _side * _side; i++) {
      pixels[i * 4] = 255;
      pixels[i * 4 + 1] = 255;
      pixels[i * 4 + 2] = 255;
      // Mostly solid with gaps, like graphite catching paper texture.
      pixels[i * 4 + 3] = rnd.nextDouble() < 0.18 ? 60 + rnd.nextInt(80) : 255;
    }
    ui.decodeImageFromPixels(
      pixels,
      _side,
      _side,
      ui.PixelFormat.rgba8888,
      (image) => shader = ui.ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        Float64List.fromList([
          0.5, 0, 0, 0, //
          0, 0.5, 0, 0,
          0, 0, 1, 0,
          0, 0, 0, 1,
        ]),
      ),
    );
  }
}
