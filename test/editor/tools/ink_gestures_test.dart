import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/tools/ink_gestures.dart';

/// Points from `(x, y, t)` triples.
List<StrokePoint> pts(List<(double, double, int)> raw) =>
    [for (final (x, y, t) in raw) StrokePoint(x: x, y: y, t: t)];

/// A polyline sampled every [stepMs], through the given corner points.
List<StrokePoint> trace(List<(double, double)> corners, {int stepMs = 10}) {
  final out = <StrokePoint>[];
  var t = 0;
  for (var i = 0; i < corners.length - 1; i++) {
    final (x0, y0) = corners[i];
    final (x1, y1) = corners[i + 1];
    for (var s = 0; s < 10; s++) {
      final f = s / 10;
      out.add(StrokePoint(x: x0 + (x1 - x0) * f, y: y0 + (y1 - y0) * f, t: t));
      t += stepMs;
    }
  }
  final (lx, ly) = corners.last;
  out.add(StrokePoint(x: lx, y: ly, t: t));
  return out;
}

FreehandElement stroke(List<StrokePoint> points,
        {String id = 's', int color = 0xFF112233, double size = 3, double opacity = 0.8, int z = 4}) =>
    FreehandElement(
        id: id, zOrder: z, points: points, color: color, size: size, opacity: opacity);

SceneShapeElement box(String id, Rect r, {bool locked = false}) => SceneShapeElement(
      id: id,
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [r.left, r.top, r.right, r.bottom],
      color: 0xFF000000,
      strokeWidth: 2,
      isLocked: locked,
    );

void main() {
  group('holdDurationMs — how long the pen has stayed put at the end', () {
    test('a pen held still after drawing: from when it arrived to the lift', () {
      // Draws to (100,0) by t=300, then rests with 2 px of jitter until t=1000.
      final points = pts([
        (0, 0, 0), (50, 0, 150), (100, 0, 300),
        (101, 1, 400), (100, 2, 500), (99, 1, 700), (100, 0, 900),
      ]);

      expect(holdDurationMs(points, 1000), 700);
    });

    test('lifting while still moving is no hold at all', () {
      final points = pts([(0, 0, 0), (40, 0, 100), (80, 0, 200), (120, 0, 300)]);

      expect(holdDurationMs(points, 310), 10);
    });

    test('jitter bigger than the tolerance is movement, not a hold', () {
      final points = pts([
        (100, 0, 300), (120, 0, 400), (100, 0, 500), (120, 0, 600), (100, 0, 700),
      ]);

      expect(holdDurationMs(points, 800), 100);
    });

    test('a pen that never left where it came down is held for the stroke',
        () {
      final points = pts([(10, 10, 0), (11, 10, 200), (10, 11, 400)]);

      expect(holdDurationMs(points, 600), 600);
    });

    test('the tolerance scales with zoom: 6 screen px is fewer scene units '
        'when zoomed in', () {
      final points = pts([(0, 0, 0), (100, 0, 200), (104, 0, 300), (100, 0, 400)]);

      expect(holdDurationMs(points, 500, epsilon: 6), 300);
      expect(holdDurationMs(points, 500, epsilon: 2), 100);
    });

    test('with no timestamps there is nothing to measure', () {
      final points = [const StrokePoint(x: 0, y: 0), const StrokePoint(x: 1, y: 0)];

      expect(holdDurationMs(points, 1000), 0);
    });

    test('no points, no hold', () {
      expect(holdDurationMs(const [], 1000), 0);
    });
  });

  group('isHoldToSnap', () {
    // A 100 px stroke drawn in 300 ms.
    List<StrokePoint> big() => trace([(0, 0), (100, 0), (100, 100)]);

    test('a big stroke held long enough snaps', () {
      final points = big();
      final up = points.last.t! + 800;

      expect(isHoldToSnap(points, up), isTrue);
    });

    test('a big stroke lifted at once does not', () {
      final points = big();

      expect(isHoldToSnap(points, points.last.t! + 20), isFalse);
    });

    test('a hold just short of the bar does not; at it does', () {
      final points = big();
      final end = points.last.t!;

      expect(isHoldToSnap(points, end + kSnapHoldMs - 1), isFalse);
      expect(isHoldToSnap(points, end + kSnapHoldMs), isTrue);
    });

    test('a tiny held stroke — a dot, a letter — never snaps', () {
      final points = trace([(0, 0), (12, 0), (12, 12)]);

      expect(isHoldToSnap(points, points.last.t! + 2000), isFalse);
    });

    test('size is judged on the screen, so zooming out does not make a '
        'big drawing look tiny', () {
      // 30 scene units at 3x zoom is 90 screen px.
      final points = trace([(0, 0), (30, 0), (30, 30)]);

      expect(isHoldToSnap(points, points.last.t! + 800, zoom: 1), isFalse);
      expect(isHoldToSnap(points, points.last.t! + 800, zoom: 3), isTrue);
    });
  });

  group('snapGeometry — the shape a recognised stroke becomes', () {
    List<StrokePoint> wobblyRect() => trace(
        [(12, 10), (210, 14), (205, 118), (8, 112), (14, 11)]);

    test('RECTANGLE → a rectangle around the stroke', () {
      final snap = snapGeometry('RECTANGLE', wobblyRect())!;

      expect(snap.type, ShapeType.rectangle);
      expect(snap.geometry, [8, 10, 210, 118]);
    });

    test('ELLIPSE → a circle shape (an ellipse) around the stroke', () {
      final snap = snapGeometry('ELLIPSE', wobblyRect())!;

      expect(snap.type, ShapeType.circle);
      expect(snap.geometry, [8, 10, 210, 118]);
    });

    test('TRIANGLE drawn point-up stays point-up', () {
      final up = trace([(50, 0), (100, 100), (0, 100), (50, 0)]);

      final snap = snapGeometry('TRIANGLE', up)!;

      expect(snap.type, ShapeType.triangle);
      expect(snap.geometry, [0, 100, 100, 100, 50, 0]);
    });

    test('TRIANGLE drawn point-down stays point-down', () {
      final down = trace([(0, 0), (100, 0), (50, 100), (0, 0)]);

      final snap = snapGeometry('TRIANGLE', down)!;

      expect(snap.geometry, [0, 0, 100, 0, 50, 100]);
    });

    test('ARROW → a straight arrow from where it started to its tip', () {
      // Shaft left to right, then the two barbs of the head.
      final arrow = trace([(0, 50), (120, 50), (105, 38), (120, 50), (105, 62)]);

      final snap = snapGeometry('ARROW', arrow)!;

      expect(snap.type, ShapeType.arrow);
      expect(snap.geometry, [0, 50, 120, 50]);
    });

    test('the label is matched without regard to case', () {
      expect(snapGeometry('rectangle', wobblyRect())?.type, ShapeType.rectangle);
    });

    test('a label that is not one of the four is no shape', () {
      expect(snapGeometry('SQUIGGLE', wobblyRect()), isNull);
      expect(snapGeometry('', wobblyRect()), isNull);
    });

    test('no points, no shape', () {
      expect(snapGeometry('RECTANGLE', const []), isNull);
    });
  });

  group('looksLikeScribble', () {
    List<StrokePoint> zigzag({bool vertical = false, int passes = 6}) {
      final corners = <(double, double)>[];
      for (var i = 0; i <= passes; i++) {
        final along = i.isEven ? 0.0 : 90.0;
        final across = i * 12.0;
        corners.add(vertical ? (across, along) : (along, across));
      }
      return trace(corners);
    }

    test('back-and-forth scrubbing is a scribble', () {
      expect(looksLikeScribble(zigzag()), isTrue);
      expect(looksLikeScribble(zigzag(vertical: true)), isTrue);
    });

    test('a circle is not', () {
      final circle = [
        for (var i = 0; i <= 40; i++)
          StrokePoint(
              x: 60 + 50 * math.cos(i / 40 * 2 * math.pi),
              y: 60 + 50 * math.sin(i / 40 * 2 * math.pi),
              t: i * 10),
      ];

      expect(looksLikeScribble(circle), isFalse);
    });

    test('a straight line is not', () {
      expect(looksLikeScribble(trace([(0, 0), (150, 0)])), isFalse);
    });

    test('a single swing out and back is not — a scribble scrubs several times',
        () {
      expect(looksLikeScribble(trace([(0, 0), (100, 0), (0, 5)])), isFalse);
    });

    test('a tiny zigzag is not, however many turns it has', () {
      // Five reversals and plenty of doubling back — but only ~22 px across.
      expect(
          looksLikeScribble(trace([
            (0, 0), (20, 0), (0, 2), (20, 4), (0, 6), (20, 8), (0, 10),
          ])),
          isFalse);
    });

    test('a wavy underline is not — it never turns back along its length', () {
      final wave = [
        for (var i = 0; i <= 40; i++)
          StrokePoint(
              x: i * 5.0, y: 10 * math.sin(i / 40 * 4 * 2 * math.pi), t: i * 10),
      ];

      expect(looksLikeScribble(wave), isFalse);
    });

    test('writing that loops back but mostly travels is not — a scribble stays '
        'put, handwriting moves on', () {
      // Forward 55, back 30, forward 55 … six turns, but it ends 130 px along:
      // the path is under 2.5x its size, where scrubbing is over 3x.
      final cursive = trace([
        (0, 0), (55, 1), (25, 2), (80, 3), (50, 4), (105, 5), (75, 6), (130, 7),
      ]);

      expect(looksLikeScribble(cursive), isFalse);
    });

    test('three passes is not enough; five is', () {
      List<StrokePoint> passes(int n) => trace([
            for (var i = 0; i <= n; i++) (i.isEven ? 0.0 : 100.0, i * 3.0),
          ]);

      expect(looksLikeScribble(passes(4)), isFalse, reason: '3 reversals');
      expect(looksLikeScribble(passes(5)), isTrue, reason: '4 reversals');
    });

    test('too few points are not', () {
      expect(looksLikeScribble(pts([(0, 0, 0), (50, 0, 10), (0, 0, 20)])), isFalse);
    });
  });

  group('scribbleVictims — what a scribble wipes out', () {
    const scribble = Rect.fromLTWH(100, 100, 100, 60);

    test('an element it covers is a victim', () {
      final inside = box('in', const Rect.fromLTWH(110, 110, 60, 30));

      expect(scribbleVictims([inside], scribble, excludeId: 'x'), [inside]);
    });

    test('one it barely touches is not', () {
      final grazed = box('graze', const Rect.fromLTWH(180, 140, 100, 100));

      expect(scribbleVictims([grazed], scribble, excludeId: 'x'), isEmpty);
    });

    test('half covered is not enough; mostly covered is', () {
      final half = box('half', const Rect.fromLTWH(150, 100, 100, 60));
      final mostly = box('mostly', const Rect.fromLTWH(130, 100, 100, 60));

      expect(scribbleVictims([half], scribble, excludeId: 'x'), isEmpty);
      expect(scribbleVictims([mostly], scribble, excludeId: 'x'), [mostly]);
    });

    test('a big drawing a small scribble sits inside is not wiped out', () {
      final big = box('big', const Rect.fromLTWH(0, 0, 600, 600));

      expect(scribbleVictims([big], scribble, excludeId: 'x'), isEmpty);
    });

    test('a thin line it covers is a victim although it has no area', () {
      const line = SceneShapeElement(
        id: 'line',
        zOrder: 0,
        shapeType: ShapeType.line,
        geometryData: [110, 130, 190, 130],
        color: 0xFF000000,
        strokeWidth: 2,
      );

      expect(scribbleVictims([line], scribble, excludeId: 'x'), [line]);
    });

    test('ink it covers is a victim', () {
      final ink = stroke(trace([(120, 120), (180, 150)]), id: 'ink');

      expect(scribbleVictims([ink], scribble, excludeId: 'x'), [ink]);
    });

    test('text it covers is a victim', () {
      const text = TextElement(
          id: 't',
          zOrder: 0,
          geometryData: [110, 110, 190, 140],
          text: 'oops',
          color: 0xFF000000);

      expect(scribbleVictims([text], scribble, excludeId: 'x'), [text]);
    });

    test('a picture or a frame never is — scribbling on a photo annotates it',
        () {
      const image = ImageElement(
          id: 'img',
          zOrder: 0,
          geometryData: [110, 110, 190, 150],
          relativeImagePath: 'a.png');
      const frame = FrameElement(
          id: 'f', zOrder: 0, geometryData: [110, 110, 190, 150], name: 'F');

      expect(scribbleVictims([image, frame], scribble, excludeId: 'x'), isEmpty);
    });

    test('a locked element never is', () {
      final locked = box('lock', const Rect.fromLTWH(110, 110, 60, 30), locked: true);

      expect(scribbleVictims([locked], scribble, excludeId: 'x'), isEmpty);
    });

    test('the scribble itself is never one of its own victims', () {
      final self = stroke(trace([(110, 110), (190, 150)]), id: 'self');

      expect(scribbleVictims([self], scribble, excludeId: 'self'), isEmpty);
    });

    test('a pixel-eraser stroke is not content', () {
      const eraser = FreehandElement(
          id: 'e',
          zOrder: 0,
          points: [StrokePoint(x: 120, y: 120, t: 0), StrokePoint(x: 180, y: 150, t: 10)],
          color: 0,
          size: 8,
          isEraser: true);

      expect(scribbleVictims([eraser], scribble, excludeId: 'x'), isEmpty);
    });
  });
}
