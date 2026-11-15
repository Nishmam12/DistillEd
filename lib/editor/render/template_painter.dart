// Paints vector template patterns (ruled, dotted, grid, engineering) onto the canvas.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/model/template_type.dart';
import 'template_config.dart';

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
    bool bounded = false,
  }) {
    if (type == TemplateType.blank) return;

    final config = TemplateConfig.forBackground(type, backgroundColor);
    final r = region ?? (Offset.zero & size);

    // Cull only when tiling a transformed (scene-space) region; plain
    // screen-space callers always render at their native density.
    final scale = region == null ? 1.0 : zoom;
    final spacing = type == TemplateType.dotted || type == TemplateType.isometric
        ? config.dotSpacing
        : config.lineSpacing;
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
      case TemplateType.cornell:
        // The cue column and summary band need the page's real edges; on an
        // endless canvas it is a ruled page with a margin.
        bounded ? _paintCornell(canvas, r, config) : _paintRuled(canvas, r, config);
      case TemplateType.music:
        _paintMusic(canvas, r, config);
      case TemplateType.isometric:
        _paintIsometric(canvas, r, config);
      case TemplateType.checklist:
        _paintChecklist(canvas, r, config);
    }
  }

  /// Cornell notes: a cue column on the left, a summary band at the bottom and
  /// ruled lines in the notes area between them.
  static void _paintCornell(Canvas canvas, Rect page, TemplateConfig config) {
    final line = Paint()
      ..color = config.lineColor
      ..strokeWidth = config.lineWidth
      ..style = PaintingStyle.stroke;
    final divider = Paint()
      ..color = config.majorLineColor
      ..strokeWidth = config.majorLineWidth
      ..style = PaintingStyle.stroke;

    final cueX = page.left + page.width * 0.28;
    final summaryY = page.bottom - page.height * 0.18;

    for (final t in _ticks(page.top, summaryY, config.lineSpacing)) {
      canvas.drawLine(Offset(cueX, t.value), Offset(page.right, t.value), line);
    }
    canvas.drawLine(Offset(cueX, page.top), Offset(cueX, summaryY), divider);
    canvas.drawLine(
        Offset(page.left, summaryY), Offset(page.right, summaryY), divider);
  }

  /// Staves of five lines, a gap between each.
  static void _paintMusic(Canvas canvas, Rect region, TemplateConfig config) {
    final paint = Paint()
      ..color = config.lineColor
      ..strokeWidth = config.lineWidth
      ..style = PaintingStyle.stroke;
    final gap = config.lineSpacing;
    final staff = gap * 4;
    final period = staff + gap * 5;
    var top = (region.top / period).floor() * period + gap * 2;
    for (; top < region.bottom; top += period) {
      for (var i = 0; i < 5; i++) {
        final y = top + i * gap;
        if (y < region.top || y > region.bottom) continue;
        canvas.drawLine(Offset(region.left, y), Offset(region.right, y), paint);
      }
    }
  }

  /// Dots on a triangular lattice, the grid for isometric drawing.
  static void _paintIsometric(
      Canvas canvas, Rect region, TemplateConfig config) {
    final dotPaint = Paint()
      ..color = config.lineColor
      ..strokeWidth = config.dotRadius * 2
      ..strokeCap = StrokeCap.round;
    final s = config.dotSpacing;
    final rowHeight = s * 0.8660254037844386; // sqrt(3) / 2
    final dots = <Offset>[];
    for (final row in _ticks(region.top, region.bottom, rowHeight)) {
      final shift = row.index.isOdd ? s / 2 : 0.0;
      for (final x
          in _ticks(region.left - shift, region.right - shift, s)) {
        dots.add(Offset(x.value + shift, row.value));
      }
    }
    canvas.drawPoints(ui.PointMode.points, dots, dotPaint);
  }

  /// Ruled lines with an empty tick box at the start of each one.
  static void _paintChecklist(
      Canvas canvas, Rect region, TemplateConfig config) {
    final line = Paint()
      ..color = config.lineColor
      ..strokeWidth = config.lineWidth
      ..style = PaintingStyle.stroke;
    final box = Paint()
      ..color = config.majorLineColor
      ..strokeWidth = config.majorLineWidth
      ..style = PaintingStyle.stroke;
    final s = config.lineSpacing;
    const side = 14.0;
    const left = 24.0;
    for (final t in _ticks(region.top, region.bottom, s)) {
      canvas.drawLine(
          Offset(region.left, t.value), Offset(region.right, t.value), line);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, t.value - (s + side) / 2, side, side),
          const Radius.circular(3),
        ),
        box,
      );
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
    // One batched call of round-capped points instead of a drawCircle per dot.
    final dotPaint = Paint()
      ..color = config.lineColor
      ..strokeWidth = config.dotRadius * 2
      ..strokeCap = StrokeCap.round;

    final dots = <Offset>[
      for (final tx in _ticks(region.left, region.right, config.dotSpacing))
        for (final ty in _ticks(region.top, region.bottom, config.dotSpacing))
          Offset(tx.value, ty.value),
    ];
    canvas.drawPoints(ui.PointMode.points, dots, dotPaint);
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
