// Paints vector template patterns (ruled, dotted, grid, engineering, Cornell,
// music, isometric, checklist).
//
// The patterns are described once, as lines, dots and boxes sent to a
// [TemplateSink]. The canvas draws them through [TemplatePainter.paint]; the
// PDF export sends the same calls to its own sink, so the paper in an exported
// PDF is exactly the paper on screen, as vector lines.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/model/template_type.dart';
import 'template_config.dart';

/// Where a template's lines, dots and boxes go.
abstract class TemplateSink {
  void line(Offset a, Offset b, Color color, double width);

  /// Round dots of [radius], all the same colour.
  void dots(List<Offset> centres, Color color, double radius);

  /// The outline of a rounded box.
  void roundRect(Rect rect, double radius, Color color, double width);
}

/// Draws a template onto a Flutter [Canvas], reusing one [Paint] per style.
class CanvasTemplateSink implements TemplateSink {
  CanvasTemplateSink(this.canvas);

  final Canvas canvas;
  final Map<(Color, double, bool), Paint> _paints = {};

  Paint _paint(Color color, double width, {bool round = false}) =>
      _paints.putIfAbsent(
        (color, width, round),
        () => Paint()
          ..color = color
          ..strokeWidth = width
          ..style = PaintingStyle.stroke
          ..strokeCap = round ? StrokeCap.round : StrokeCap.butt,
      );

  @override
  void line(Offset a, Offset b, Color color, double width) =>
      canvas.drawLine(a, b, _paint(color, width));

  @override
  void dots(List<Offset> centres, Color color, double radius) =>
      canvas.drawPoints(
          ui.PointMode.points, centres, _paint(color, radius * 2, round: true));

  @override
  void roundRect(Rect rect, double radius, Color color, double width) =>
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)),
          _paint(color, width));
}

class TemplatePainter {
  /// Below this on-screen spacing (logical px) the pattern is too dense to read
  /// and is skipped — both a visual win (no grey mush when zoomed far out) and
  /// a guard against drawing hundreds of thousands of dots per frame.
  static const double _minOnScreenSpacing = 4.0;

  /// Paints the template pattern for the given type onto the canvas.
  ///
  /// By default the pattern is tiled across `0..size` (screen space). When
  /// [region] is supplied the pattern is instead tiled across that rectangle —
  /// callers that have applied a pan/zoom transform pass the visible *scene*
  /// rect so the pattern stays anchored to scene coordinates (and therefore
  /// pans and scales together with the drawn content).
  static void paint(
    Canvas canvas,
    Size size,
    TemplateType type,
    Color backgroundColor, {
    Rect? region,
    double zoom = 1.0,
    bool bounded = false,
  }) =>
      emit(
        CanvasTemplateSink(canvas),
        type,
        backgroundColor,
        region: region ?? (Offset.zero & size),
        zoom: region == null ? 1.0 : zoom,
        bounded: bounded,
      );

  /// Sends the pattern for [type] across [region] to [sink]. [zoom] is the
  /// on-screen scale, for skipping a pattern too dense to read; [bounded]
  /// says [region] is a real page (so Cornell can use its edges).
  static void emit(
    TemplateSink sink,
    TemplateType type,
    Color backgroundColor, {
    required Rect region,
    double zoom = 1.0,
    bool bounded = false,
  }) {
    if (type == TemplateType.blank) return;

    final config = TemplateConfig.forBackground(type, backgroundColor);
    final spacing = type.family == TemplateType.dotted ||
            type == TemplateType.isometric
        ? config.dotSpacing
        : config.lineSpacing;
    if (spacing * zoom < _minOnScreenSpacing) return;

    final r = region;
    switch (type.family) {
      case TemplateType.blank:
        return;
      case TemplateType.ruled:
        _ruled(sink, r, config);
      case TemplateType.dotted:
        _dotted(sink, r, config);
      case TemplateType.grid:
        _grid(sink, r, config);
      case TemplateType.engineeringGrid:
        _engineeringGrid(sink, r, config);
      case TemplateType.cornell:
        // The cue column and summary band need the page's real edges; on an
        // endless canvas it is a ruled page with a margin.
        bounded ? _cornell(sink, r, config) : _ruled(sink, r, config);
      case TemplateType.music:
        _music(sink, r, config);
      case TemplateType.isometric:
        _isometric(sink, r, config);
      case TemplateType.checklist:
        _checklist(sink, r, config);
      // Planners need a page; on an endless canvas they are ruled paper.
      case TemplateType.weeklyPlanner:
        bounded ? _weekly(sink, r, config) : _ruled(sink, r, config);
      case TemplateType.monthlyPlanner:
        bounded ? _monthly(sink, r, config) : _ruled(sink, r, config);
      case TemplateType.ruledNarrow ||
            TemplateType.ruledWide ||
            TemplateType.gridSmall ||
            TemplateType.gridLarge ||
            TemplateType.dottedSmall ||
            TemplateType.dottedLarge:
        break; // never a family
    }
  }

  /// A week to plan: a band for the dates at the top, then seven day boxes
  /// and one for notes, two across. Days are left unlabelled: they are
  /// written in, so any week (and any first day) fits.
  static void _weekly(TemplateSink sink, Rect page, TemplateConfig config) {
    final margin = page.width * 0.05;
    final inner = page.deflate(margin);
    final top = inner.top + inner.height * 0.08;
    sink.line(Offset(inner.left, top), Offset(inner.right, top),
        config.majorLineColor, config.majorLineWidth);
    final gap = margin / 2;
    final boxW = (inner.width - gap) / 2;
    final boxH = (inner.bottom - top - gap * 4) / 4;
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 2; col++) {
        final box = Rect.fromLTWH(inner.left + col * (boxW + gap),
            top + gap + row * (boxH + gap), boxW, boxH);
        sink.roundRect(box, 6, config.majorLineColor, config.majorLineWidth);
        // A line under the day's name.
        final y = box.top + config.lineSpacing;
        sink.line(Offset(box.left + 8, y), Offset(box.right - 8, y),
            config.lineColor, config.lineWidth);
      }
    }
  }

  /// A month to plan: a band for its name, a row for the weekdays, then six
  /// weeks of seven days.
  static void _monthly(TemplateSink sink, Rect page, TemplateConfig config) {
    final margin = page.width * 0.05;
    final inner = page.deflate(margin);
    final top = inner.top + inner.height * 0.08;
    final days = top + config.lineSpacing;
    sink.line(Offset(inner.left, top), Offset(inner.right, top),
        config.majorLineColor, config.majorLineWidth);
    final grid = Rect.fromLTRB(inner.left, days, inner.right, inner.bottom);
    sink.roundRect(Rect.fromLTRB(inner.left, top, inner.right, inner.bottom),
        6, config.majorLineColor, config.majorLineWidth);
    sink.line(Offset(grid.left, days), Offset(grid.right, days),
        config.majorLineColor, config.majorLineWidth);
    for (var c = 1; c < 7; c++) {
      final x = grid.left + grid.width * c / 7;
      sink.line(Offset(x, top), Offset(x, grid.bottom), config.lineColor,
          config.lineWidth);
    }
    for (var w = 1; w < 6; w++) {
      final y = grid.top + grid.height * w / 6;
      sink.line(Offset(grid.left, y), Offset(grid.right, y), config.lineColor,
          config.lineWidth);
    }
  }

  /// Cornell notes: a cue column on the left, a summary band at the bottom and
  /// ruled lines in the notes area between them.
  static void _cornell(TemplateSink sink, Rect page, TemplateConfig config) {
    final cueX = page.left + page.width * 0.28;
    final summaryY = page.bottom - page.height * 0.18;

    for (final t in _ticks(page.top, summaryY, config.lineSpacing)) {
      sink.line(Offset(cueX, t.value), Offset(page.right, t.value),
          config.lineColor, config.lineWidth);
    }
    sink.line(Offset(cueX, page.top), Offset(cueX, summaryY),
        config.majorLineColor, config.majorLineWidth);
    sink.line(Offset(page.left, summaryY), Offset(page.right, summaryY),
        config.majorLineColor, config.majorLineWidth);
  }

  /// Staves of five lines, a gap between each.
  static void _music(TemplateSink sink, Rect region, TemplateConfig config) {
    final gap = config.lineSpacing;
    final staff = gap * 4;
    final period = staff + gap * 5;
    var top = (region.top / period).floor() * period + gap * 2;
    for (; top < region.bottom; top += period) {
      for (var i = 0; i < 5; i++) {
        final y = top + i * gap;
        if (y < region.top || y > region.bottom) continue;
        sink.line(Offset(region.left, y), Offset(region.right, y),
            config.lineColor, config.lineWidth);
      }
    }
  }

  /// Dots on a triangular lattice, the grid for isometric drawing.
  static void _isometric(TemplateSink sink, Rect region, TemplateConfig config) {
    final s = config.dotSpacing;
    final rowHeight = s * 0.8660254037844386; // sqrt(3) / 2
    final dots = <Offset>[];
    for (final row in _ticks(region.top, region.bottom, rowHeight)) {
      final shift = row.index.isOdd ? s / 2 : 0.0;
      for (final x in _ticks(region.left - shift, region.right - shift, s)) {
        dots.add(Offset(x.value + shift, row.value));
      }
    }
    sink.dots(dots, config.lineColor, config.dotRadius);
  }

  /// Ruled lines with an empty tick box at the start of each one.
  static void _checklist(TemplateSink sink, Rect region, TemplateConfig config) {
    final s = config.lineSpacing;
    const side = 14.0;
    const left = 24.0;
    for (final t in _ticks(region.top, region.bottom, s)) {
      sink.line(Offset(region.left, t.value), Offset(region.right, t.value),
          config.lineColor, config.lineWidth);
      sink.roundRect(Rect.fromLTWH(left, t.value - (s + side) / 2, side, side),
          3, config.majorLineColor, config.majorLineWidth);
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

  /// Horizontal ruled lines and a left margin line.
  static void _ruled(TemplateSink sink, Rect region, TemplateConfig config) {
    for (final t in _ticks(region.top, region.bottom, config.lineSpacing)) {
      sink.line(Offset(region.left, t.value), Offset(region.right, t.value),
          config.lineColor, config.lineWidth);
    }
    sink.line(
      Offset(config.marginOffset, region.top),
      Offset(config.marginOffset, region.bottom),
      config.marginLineColor,
      config.lineWidth * 1.5,
    );
  }

  /// Evenly spaced dots.
  static void _dotted(TemplateSink sink, Rect region, TemplateConfig config) {
    sink.dots([
      for (final tx in _ticks(region.left, region.right, config.dotSpacing))
        for (final ty in _ticks(region.top, region.bottom, config.dotSpacing))
          Offset(tx.value, ty.value),
    ], config.lineColor, config.dotRadius);
  }

  /// A uniform grid of horizontal and vertical lines.
  static void _grid(TemplateSink sink, Rect region, TemplateConfig config) {
    for (final t in _ticks(region.left, region.right, config.lineSpacing)) {
      sink.line(Offset(t.value, region.top), Offset(t.value, region.bottom),
          config.lineColor, config.lineWidth);
    }
    for (final t in _ticks(region.top, region.bottom, config.lineSpacing)) {
      sink.line(Offset(region.left, t.value), Offset(region.right, t.value),
          config.lineColor, config.lineWidth);
    }
  }

  /// An engineering grid with minor and major lines.
  static void _engineeringGrid(
      TemplateSink sink, Rect region, TemplateConfig config) {
    void line(Offset a, Offset b, int index) =>
        index % config.majorLineInterval == 0
            ? sink.line(a, b, config.majorLineColor, config.majorLineWidth)
            : sink.line(a, b, config.lineColor, config.lineWidth);

    for (final t in _ticks(region.left, region.right, config.lineSpacing)) {
      line(Offset(t.value, region.top), Offset(t.value, region.bottom),
          t.index);
    }
    for (final t in _ticks(region.top, region.bottom, config.lineSpacing)) {
      line(Offset(region.left, t.value), Offset(region.right, t.value),
          t.index);
    }
  }
}
