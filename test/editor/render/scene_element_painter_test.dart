// Smoke test: every element kind paints without throwing (covers the rough,
// fill-style, stroke-style, arrowhead, text and image code paths).

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/render/scene_element_painter.dart';

void main() {
  test('paints all element kinds without error', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    const container = SceneShapeElement(
      id: 'box',
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [0, 0, 100, 60],
      color: 0xFF000000,
      strokeWidth: 2,
      hasFill: true,
      fillColor: 0xFFFFE066,
      fillStyle: FillStyle.crossHatch,
      edges: EdgeStyle.round,
      strokeStyle: StrokeStyle.dashed,
    );

    final elements = <SceneElement>[
      const FreehandElement(
        id: 'f',
        zOrder: 0,
        color: 0xFF000000,
        size: 3,
        points: [StrokePoint(x: 0, y: 0), StrokePoint(x: 10, y: 10)],
      ),
      container,
      const SceneShapeElement(
        id: 'ell',
        zOrder: 1,
        shapeType: ShapeType.circle,
        geometryData: [0, 0, 40, 40],
        color: 0xFF000000,
        strokeWidth: 2,
        roughness: 1.5,
        hasFill: true,
        fillColor: 0xFFAACCEE,
      ),
      const SceneShapeElement(
        id: 'arr',
        zOrder: 2,
        shapeType: ShapeType.arrow,
        geometryData: [0, 0, 50, 30],
        color: 0xFF000000,
        strokeWidth: 2,
        endArrowhead: Arrowhead.triangle,
        elbowed: true,
      ),
      const TextElement(
        id: 't',
        zOrder: 3,
        geometryData: [0, 0, 120, 30],
        text: 'bound',
        color: 0xFF000000,
        containerId: 'box',
      ),
      const ImageElement(
        id: 'img',
        zOrder: 4,
        geometryData: [0, 0, 80, 80],
        relativeImagePath: 'x.png',
        sourceDescription: 'pic',
      ),
    ];

    final byId = {for (final e in elements) e.id: e};
    expect(() {
      for (final e in elements) {
        SceneElementPainter.paint(canvas, e, byId: byId);
      }
      recorder.endRecording();
    }, returnsNormally);
  });

  // A shaft drawn to its full length runs past the arrowhead's point by half a
  // stroke width (further once roughness jitters the endpoint), which reads on
  // screen as the head stopping short of where the line ends. Trimming it back
  // into the head makes the point the end of the arrow.
  group('arrow shaft trimming', () {
    /// A rightward arrow: (0,0) → (100,0).
    const shaft = [Offset.zero, Offset(100, 0)];

    /// How far a triangular head reaches back down a shaft of width [w].
    double headReach(double w) => math.max(10.0, w * 3.5) * math.cos(0.5);

    test('a triangular head pulls the shaft back inside itself', () {
      const w = 2.0;
      final t = SceneElementPainter.trimShaftForHeads(
          shaft, Arrowhead.none, Arrowhead.triangle, w);

      expect(t.first, Offset.zero, reason: 'the tail has no head to clear');
      // Short of the tip...
      expect(t.last.dx, lessThan(100));
      // ...but not so far back that a gap opens at the head's base.
      expect(t.last.dx, greaterThan(100 - headReach(w)));
    });

    test('the round cap no longer pokes out past the point', () {
      for (final w in [1.0, 2.0, 4.0, 8.0, 16.0]) {
        final t = SceneElementPainter.trimShaftForHeads(
            shaft, Arrowhead.none, Arrowhead.triangle, w);
        // The cap extends half a stroke width beyond the path's end.
        expect(t.last.dx + w / 2, lessThanOrEqualTo(100.0),
            reason: 'stroke width $w overshoots the tip');
      }
    });

    test('both ends are trimmed when both carry a head', () {
      final t = SceneElementPainter.trimShaftForHeads(
          shaft, Arrowhead.triangle, Arrowhead.triangle, 2);
      expect(t.first.dx, greaterThan(0));
      expect(t.last.dx, lessThan(100));
      expect(t.first.dx, closeTo(100 - t.last.dx, 1e-9),
          reason: 'symmetric heads trim symmetrically');
    });

    test('a bar head trims only the cap; a dot head trims nothing', () {
      final bar = SceneElementPainter.trimShaftForHeads(
          shaft, Arrowhead.none, Arrowhead.bar, 4);
      expect(bar.last.dx, closeTo(98, 1e-9)); // 100 - w/2

      final dot = SceneElementPainter.trimShaftForHeads(
          shaft, Arrowhead.none, Arrowhead.dot, 4);
      expect(dot.last, const Offset(100, 0),
          reason: 'the disc is centred on the tip and already hides the cap');
    });

    test('a plain head-less line is left exactly as drawn', () {
      final t = SceneElementPainter.trimShaftForHeads(
          shaft, Arrowhead.none, Arrowhead.none, 8);
      expect(t, shaft);
    });

    test('an arrow shorter than its own head collapses, never reverses', () {
      const stub = [Offset.zero, Offset(3, 0)];
      final t = SceneElementPainter.trimShaftForHeads(
          stub, Arrowhead.none, Arrowhead.triangle, 2);
      expect(t.last.dx, greaterThanOrEqualTo(0.0));
      expect(t.last.dx, lessThanOrEqualTo(3.0));
    });

    test('an elbowed route keeps its corner and trims only the ends', () {
      // Horizontal-first right-angle route, as [_shaftPoints] builds it.
      const elbow = [Offset.zero, Offset(100, 0), Offset(100, 80)];
      final t = SceneElementPainter.trimShaftForHeads(
          elbow, Arrowhead.none, Arrowhead.triangle, 2);

      expect(t.length, 3);
      expect(t[1], const Offset(100, 0), reason: 'the corner does not move');
      expect(t.last.dx, 100.0, reason: 'the last leg runs straight down');
      expect(t.last.dy, lessThan(80));
    });

    test('a zero-length end segment is left alone rather than dividing by zero',
        () {
      const degenerate = [Offset(50, 50), Offset(50, 50)];
      final t = SceneElementPainter.trimShaftForHeads(
          degenerate, Arrowhead.triangle, Arrowhead.triangle, 2);
      expect(t, degenerate);
    });
  });
}
