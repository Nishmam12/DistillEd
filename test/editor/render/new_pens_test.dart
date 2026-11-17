import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/element_style.dart';
import 'package:margo/domain/model/stroke_point.dart';
import 'package:margo/editor/render/freehand_path.dart';
import 'package:margo/editor/state/editor_tool_controller.dart';
import 'package:margo/editor/state/pen_presets.dart';

List<StrokePoint> _line(Offset a, Offset b) => [
      for (var i = 0; i <= 20; i++)
        StrokePoint(
          x: a.dx + (b.dx - a.dx) * i / 20,
          y: a.dy + (b.dy - a.dy) * i / 20,
          pressure: 0.5,
        ),
    ];

void main() {
  test('every pen draws, and the PDF outline agrees', () {
    final pts = _line(const Offset(0, 0), const Offset(100, 40));
    for (final kind in PenKind.values) {
      expect(FreehandPath.build(pts, 3, isComplete: true, kind: kind),
          isNotNull, reason: kind.name);
      expect(FreehandPath.outline(pts, 3, kind: kind).length, greaterThan(2),
          reason: kind.name);
      FreehandPath.paintFor(kind, 0xFF000000, 1); // no throw
    }
  });

  test('the calligraphy nib is broad on one diagonal and thin on the other',
      () {
    double area(List<Offset> o) {
      var sum = 0.0;
      for (var i = 0; i < o.length; i++) {
        final p = o[i], q = o[(i + 1) % o.length];
        sum += p.dx * q.dy - q.dx * p.dy;
      }
      return sum.abs() / 2;
    }

    // The nib lies along the -45° diagonal: a stroke across it shows its full
    // width, a stroke along it only the sliver.
    final across = FreehandPath.outline(
        _line(const Offset(0, 0), const Offset(100, 100)), 4,
        kind: PenKind.calligraphy);
    final along = FreehandPath.outline(
        _line(const Offset(0, 100), const Offset(100, 0)), 4,
        kind: PenKind.calligraphy);
    expect(area(across), greaterThan(area(along) * 3));
  });

  test('exporters lighten the marker and shading pencil like the canvas', () {
    expect(FreehandPath.alphaFactor(PenKind.ballpoint), 1);
    expect(FreehandPath.alphaFactor(PenKind.marker), FreehandPath.markerAlpha);
    expect(FreehandPath.alphaFactor(PenKind.shading), FreehandPath.shadingAlpha);
  });

  test('every pen can be picked: each kind has a first pen of its own', () {
    for (final kind in PenKind.values) {
      expect(defaultPenFor(kind).kind, kind, reason: kind.name);
    }
    final tools = EditorToolController();
    tools.setPenKind(PenKind.calligraphy);
    expect(tools.state.penKind, PenKind.calligraphy);
  });
}
