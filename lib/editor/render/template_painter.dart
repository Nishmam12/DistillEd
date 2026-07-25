// Paints vector template patterns (ruled, dotted, grid, engineering) onto the canvas.

import 'package:flutter/material.dart';

import '../../domain/model/template_type.dart';
import '../../domain/model/template_config.dart';

class TemplatePainter {
  /// Paints the template pattern for the given type onto the canvas.
  ///
  /// By default the pattern is tiled across `0..size` (screen space). When
  /// [region] is supplied the pattern is instead tiled across that rectangle —
  /// callers that have applied a pan/zoom transform pass the visible *scene*
  /// rect so the pattern stays anchored to scene coordinates (and therefore
  /// pans and scales together with the drawn content).
  /// Below this on-screen spacing (logical px) the pattern is too dense to read
  /// and is skipped — both a visual win (no grey mush when zoomed far out) and
  /// a guard against drawing hundreds of thousands of dots per frame.
  static const double _minOnScreenSpacing = 4.0;

  static void paint(
    Canvas canvas,
    Size size,
    TemplateType type,
    Color backgroundColor, {
    Rect? region,
    double zoom = 1.0,
  }) {
    if (type == TemplateType.blank) return;

    final config = TemplateConfig.forBackground(type, backgroundColor);
    final r = region ?? (Offset.zero & size);

    // Cull only when tiling a transformed (scene-space) region; plain
    // screen-space callers always render at their native density.
    final scale = region == null ? 1.0 : zoom;
    final spacing =
        type == TemplateType.dotted ? config.dotSpacing : config.lineSpacing;
    if (spacing * scale < _minOnScreenSpacing) return;

    switch (type) {
      case TemplateType.blank:
        return;
      case TemplateType.ruled:
        _paintRuled(canvas, r, config);
      case TemplateType.dotted:
        _paintDotted(canvas, r, config);
      case TemplateType.grid:
        _paintGrid(canvas, r, config);
      case TemplateType.engineeringGrid:
        _paintEngineeringGrid(canvas, r, config);
    }
  }

  /// Multiples of [spacing] strictly inside `(start, end)`. With `start == 0`
  /// this reproduces the original `spacing, 2*spacing, … < end` tiling, while
  /// also tiling correctly across negative/panned coordinates.
  static Iterable<({int index, double value})> _ticks(
    double start,
    double end,
    double spacing,
  ) sync* {
    int i = (start / spacing).floor() + 1;
    double v = i * spacing;
    while (v < end) {
      yield (index: i, value: v);
      i++;
      v += spacing;
    }
  }

  /// Paints horizontal ruled lines with an optional left margin line.
  static void _paintRuled(Canvas canvas, Rect region, TemplateConfig config) {
    final linePaint = Paint()
      ..color = config.lineColor
      ..strokeWidth = config.lineWidth
      ..style = PaintingStyle.stroke;

    final marginPaint = Paint()
      ..color = config.marginLineColor
      ..strokeWidth = config.lineWidth * 1.5
      ..style = PaintingStyle.stroke;

    // Horizontal lines
    for (final t in _ticks(region.top, region.bottom, config.lineSpacing)) {
      canvas.drawLine(
        Offset(region.left, t.value),
        Offset(region.right, t.value),
        linePaint,
      );
    }

    // Left margin line
    canvas.drawLine(
      Offset(config.marginOffset, region.top),
      Offset(config.marginOffset, region.bottom),
      marginPaint,
    );
  }

  /// Paints evenly spaced dots across the canvas.
  static void _paintDotted(Canvas canvas, Rect region, TemplateConfig config) {
    final dotPaint = Paint()
      ..color = config.lineColor
      ..style = PaintingStyle.fill;

    for (final tx in _ticks(region.left, region.right, config.dotSpacing)) {
      for (final ty in _ticks(region.top, region.bottom, config.dotSpacing)) {
        canvas.drawCircle(
            Offset(tx.value, ty.value), config.dotRadius, dotPaint);
      }
    }
  }

  /// Paints a uniform grid of horizontal and vertical lines.
  static void _paintGrid(Canvas canvas, Rect region, TemplateConfig config) {
    final linePaint = Paint()
      ..color = config.lineColor
      ..strokeWidth = config.lineWidth
      ..style = PaintingStyle.stroke;

    // Vertical lines
    for (final t in _ticks(region.left, region.right, config.lineSpacing)) {
      canvas.drawLine(
        Offset(t.value, region.top),
        Offset(t.value, region.bottom),
        linePaint,
      );
    }

    // Horizontal lines
    for (final t in _ticks(region.top, region.bottom, config.lineSpacing)) {
      canvas.drawLine(
        Offset(region.left, t.value),
        Offset(region.right, t.value),
        linePaint,
      );
    }
  }

  /// Paints an engineering grid with minor and major lines.
  static void _paintEngineeringGrid(
    Canvas canvas,
    Rect region,
    TemplateConfig config,
  ) {
    final minorPaint = Paint()
      ..color = config.lineColor
      ..strokeWidth = config.lineWidth
      ..style = PaintingStyle.stroke;

    final majorPaint = Paint()
      ..color = config.majorLineColor
      ..strokeWidth = config.majorLineWidth
      ..style = PaintingStyle.stroke;

    Paint paintFor(int index) =>
        index % config.majorLineInterval == 0 ? majorPaint : minorPaint;

    // Vertical lines
    for (final t in _ticks(region.left, region.right, config.lineSpacing)) {
      canvas.drawLine(
        Offset(t.value, region.top),
        Offset(t.value, region.bottom),
        paintFor(t.index),
      );
    }

    // Horizontal lines
    for (final t in _ticks(region.top, region.bottom, config.lineSpacing)) {
      canvas.drawLine(
        Offset(region.left, t.value),
        Offset(region.right, t.value),
        paintFor(t.index),
      );
    }
  }
}
