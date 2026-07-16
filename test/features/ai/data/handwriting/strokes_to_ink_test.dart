import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/features/editor/domain/models/stroke.dart';
import 'package:inkflow/features/ai/data/handwriting/handwriting_recognition_service.dart';

void main() {
  Stroke stroke(String id, List<StrokePoint> pts, {bool isEraser = false}) =>
      Stroke(id: id, color: 0xFF000000, size: 4, isEraser: isEraser, points: pts);

  group('HandwritingRecognitionService.strokesToInk', () {
    test('filters out eraser strokes and empty strokes', () {
      final ink = HandwritingRecognitionService.strokesToInk([
        stroke('e', [const StrokePoint(x: 0, y: 0)], isEraser: true),
        stroke('empty', []),
        stroke('real', [const StrokePoint(x: 1, y: 1)]),
      ]);
      expect(ink.strokes, hasLength(1));
      expect(ink.strokes.single.points.single.x, 1);
    });

    test('legacy strokes (no t) are synthesized: 10 ms/point, 300 ms gap', () {
      final ink = HandwritingRecognitionService.strokesToInk([
        stroke('a', const [
          StrokePoint(x: 0, y: 0),
          StrokePoint(x: 1, y: 0),
          StrokePoint(x: 2, y: 0),
        ]),
        stroke('b', const [
          StrokePoint(x: 0, y: 5),
          StrokePoint(x: 1, y: 5),
        ]),
      ]);

      expect(ink.strokes[0].points.map((p) => p.t), [0, 10, 20]);
      // Second stroke starts 300 ms after the first ends (t=20).
      expect(ink.strokes[1].points.map((p) => p.t), [320, 330]);
    });

    test('real timestamps keep their internal deltas but are rebased', () {
      // Simulates monotonic-since-boot timestamps (huge absolute values).
      final ink = HandwritingRecognitionService.strokesToInk([
        stroke('a', const [
          StrokePoint(x: 0, y: 0, t: 8000000),
          StrokePoint(x: 1, y: 0, t: 8000016),
          StrokePoint(x: 2, y: 0, t: 8000040),
        ]),
      ]);

      expect(ink.strokes.single.points.map((p) => p.t), [0, 16, 40]);
    });

    test('a stroke with ANY missing t is fully synthesized', () {
      final ink = HandwritingRecognitionService.strokesToInk([
        stroke('mixed', const [
          StrokePoint(x: 0, y: 0, t: 5000),
          StrokePoint(x: 1, y: 0), // pre-t pixel-erase split point
          StrokePoint(x: 2, y: 0, t: 5030),
        ]),
      ]);

      expect(ink.strokes.single.points.map((p) => p.t), [0, 10, 20]);
    });

    test('timeline stays monotonic when real and legacy strokes mix', () {
      final ink = HandwritingRecognitionService.strokesToInk([
        // Legacy stroke first (synthetic clock near 0)…
        stroke('legacy', const [
          StrokePoint(x: 0, y: 0),
          StrokePoint(x: 1, y: 0),
        ]),
        // …then a real-timestamped stroke captured hours after boot.
        stroke('real', const [
          StrokePoint(x: 0, y: 5, t: 9000000),
          StrokePoint(x: 1, y: 5, t: 9000020),
        ]),
        // …then another legacy stroke.
        stroke('legacy2', const [StrokePoint(x: 0, y: 9)]),
      ]);

      final all = [
        for (final s in ink.strokes)
          for (final p in s.points) p.t,
      ];
      expect(all, [0, 10, 310, 330, 630]);
      // Strictly non-decreasing — no wild gaps or time travel.
      for (int i = 1; i < all.length; i++) {
        expect(all[i], greaterThanOrEqualTo(all[i - 1]));
      }
    });

    test('non-monotonic real timestamps are clamped, never decreasing', () {
      final ink = HandwritingRecognitionService.strokesToInk([
        stroke('weird', const [
          StrokePoint(x: 0, y: 0, t: 1000),
          StrokePoint(x: 1, y: 0, t: 990), // goes backwards (defensive case)
          StrokePoint(x: 2, y: 0, t: 1020),
        ]),
      ]);

      expect(ink.strokes.single.points.map((p) => p.t), [0, 0, 20]);
    });
  });

  group('HandwritingRecognitionService.elementsToInk (editor 2.0)', () {
    test('converts freehand elements identically to the stroke path, '
        'skipping erasers and non-ink elements', () {
      const points = [
        StrokePoint(x: 0, y: 0, t: 5000),
        StrokePoint(x: 1, y: 0, t: 5016),
      ];
      final fromElements = HandwritingRecognitionService.elementsToInk(const [
        FreehandElement(
            id: 'ink', zOrder: 0, color: 0xFF000000, size: 4, points: points),
        FreehandElement(
            id: 'eraser',
            zOrder: 1,
            color: 0,
            size: 20,
            isEraser: true,
            points: points),
        TextElement(
            id: 't',
            zOrder: 2,
            geometryData: [0, 0, 10, 10],
            text: 'typed',
            color: 0xFF000000),
      ]);
      final fromStrokes = HandwritingRecognitionService.strokesToInk([
        stroke('ink', points),
      ]);

      expect(fromElements.strokes, hasLength(1));
      expect(
        fromElements.strokes.single.points.map((p) => (p.x, p.y, p.t)),
        fromStrokes.strokes.single.points.map((p) => (p.x, p.y, p.t)),
      );
    });
  });
}
