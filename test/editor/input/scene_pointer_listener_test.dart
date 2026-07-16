// Parity tests for the ported palm rejection — mirror the 1.0.2
// RawPointerListener tests to prove behaviour is unchanged.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/editor/input/scene_pointer_listener.dart';
import 'package:inkflow/features/editor/domain/models/stroke_point.dart';

void main() {
  late List<PointerDeviceKind> downs;
  late List<PointerDeviceKind> moves;
  late int cancels;

  Future<void> pump(WidgetTester tester, {bool handTool = false}) async {
    downs = [];
    moves = [];
    cancels = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScenePointerListener(
          isHandTool: handTool,
          onStrokeCancel: () => cancels++,
          onPointerDown: (e, StrokePoint _) => downs.add(e.kind),
          onPointerMove: (e, StrokePoint _) => moves.add(e.kind),
          onPointerUp: (e, StrokePoint _) {},
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  group('ScenePointerListener palm rejection (parity)', () {
    testWidgets('rejects a touch while the stylus is down', (tester) async {
      await pump(tester);
      final pen = await tester.startGesture(const Offset(100, 100),
          kind: PointerDeviceKind.stylus);
      final palm = await tester.startGesture(const Offset(50, 50),
          kind: PointerDeviceKind.touch);
      await palm.moveBy(const Offset(5, 5));
      await pen.moveBy(const Offset(5, 5));
      await pen.up();
      await palm.up();

      expect(downs, [PointerDeviceKind.stylus]);
      expect(moves, everyElement(PointerDeviceKind.stylus));
      expect(cancels, 0);
    });

    testWidgets('rejects a palm that lands BEFORE the pen (retroactive)',
        (tester) async {
      await pump(tester);
      final palm = await tester.startGesture(const Offset(50, 50),
          kind: PointerDeviceKind.touch);
      final pen = await tester.startGesture(const Offset(100, 100),
          kind: PointerDeviceKind.stylus);
      await palm.moveBy(const Offset(5, 5));
      await pen.moveBy(const Offset(5, 5));
      await pen.up();
      await palm.up();

      expect(cancels, 1);
      expect(downs, [PointerDeviceKind.touch, PointerDeviceKind.stylus]);
      expect(moves, [PointerDeviceKind.stylus]);
    });

    testWidgets('rejects a touch in the grace window after the pen lifts',
        (tester) async {
      await pump(tester);
      final pen = await tester.startGesture(const Offset(100, 100),
          kind: PointerDeviceKind.stylus);
      await pen.up();
      final palm = await tester.startGesture(const Offset(50, 50),
          kind: PointerDeviceKind.touch);
      await palm.up();

      expect(downs, [PointerDeviceKind.stylus]);
    });

    testWidgets('a lone finger still draws when no stylus is involved',
        (tester) async {
      await pump(tester);
      final finger = await tester.startGesture(const Offset(50, 50),
          kind: PointerDeviceKind.touch);
      await finger.moveBy(const Offset(5, 5));
      await finger.up();

      expect(downs, [PointerDeviceKind.touch]);
      expect(moves, [PointerDeviceKind.touch]);
      expect(cancels, 0);
    });
  });

  group('ScenePointerListener point extraction', () {
    testWidgets('emitted points carry the capture timestamp t', (tester) async {
      final points = <StrokePoint>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScenePointerListener(
            onPointerDown: (e, p) => points.add(p),
            onPointerMove: (e, p) => points.add(p),
            onPointerUp: (e, p) {},
            child: const SizedBox.expand(),
          ),
        ),
      );

      final finger = await tester.startGesture(const Offset(10, 10),
          kind: PointerDeviceKind.touch);
      await finger.moveBy(const Offset(5, 5));
      await finger.up();

      expect(points, isNotEmpty);
      // Handwriting recognition needs per-point timing; the exact clock origin
      // is irrelevant (deltas only), but t must be present and non-decreasing.
      expect(points.map((p) => p.t), everyElement(isNotNull));
      for (int i = 1; i < points.length; i++) {
        expect(points[i].t!, greaterThanOrEqualTo(points[i - 1].t!));
      }
    });
  });
}
