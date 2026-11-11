// Parity tests for the ported palm rejection — mirror the 1.0.2
// RawPointerListener tests to prove behaviour is unchanged.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/editor/input/scene_pointer_listener.dart';
import 'package:margo/domain/model/stroke_point.dart';

void main() {
  late List<PointerDeviceKind> downs;
  late List<PointerDeviceKind> moves;
  late int cancels;
  late int ups;
  late List<Offset> pans;

  Future<void> pump(WidgetTester tester,
      {bool handTool = false, bool fingerPans = false}) async {
    downs = [];
    moves = [];
    cancels = 0;
    ups = 0;
    pans = [];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScenePointerListener(
          isHandTool: handTool,
          fingerPans: fingerPans,
          onViewportUpdate: (delta, _, _) => pans.add(delta),
          onStrokeCancel: () => cancels++,
          onPointerDown: (e, StrokePoint _) => downs.add(e.kind),
          onPointerMove: (e, StrokePoint _) => moves.add(e.kind),
          onPointerUp: (e, StrokePoint _) => ups++,
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

    testWidgets('a pinch never reports an up without a down', (tester) async {
      await pump(tester);
      final a = await tester.startGesture(const Offset(50, 50));
      final b = await tester.startGesture(const Offset(150, 50));
      await a.up();
      await b.up();

      expect(ups, 0);
    });

    testWidgets('a cancelled pointer cancels the stroke instead of committing',
        (tester) async {
      await pump(tester);
      final finger = await tester.startGesture(const Offset(50, 50));
      await finger.cancel();

      expect(ups, 0);
      expect(cancels, 1);
    });
  });

  group('drawing with a finger switched off', () {
    testWidgets('one finger scrolls instead of drawing', (tester) async {
      await pump(tester, fingerPans: true);
      final finger = await tester.startGesture(const Offset(100, 100),
          kind: PointerDeviceKind.touch);
      await finger.moveBy(const Offset(0, -40));
      await finger.up();

      expect(downs, isEmpty);
      expect(moves, isEmpty);
      expect(ups, 0);
      expect(pans, [const Offset(0, -40)]);
    });

    testWidgets('the pen still draws', (tester) async {
      await pump(tester, fingerPans: true);
      final pen = await tester.startGesture(const Offset(100, 100),
          kind: PointerDeviceKind.stylus);
      await pen.moveBy(const Offset(10, 0));
      await pen.up();

      expect(downs, [PointerDeviceKind.stylus]);
      expect(moves, [PointerDeviceKind.stylus]);
      expect(ups, 1);
      expect(pans, isEmpty);
    });

    testWidgets('a palm on the page while writing still neither draws nor '
        'scrolls', (tester) async {
      await pump(tester, fingerPans: true);
      final pen = await tester.startGesture(const Offset(100, 100),
          kind: PointerDeviceKind.stylus);
      final palm = await tester.startGesture(const Offset(50, 50),
          kind: PointerDeviceKind.touch);
      await palm.moveBy(const Offset(5, 5));
      await pen.moveBy(const Offset(5, 5));
      await pen.up();
      await palm.up();

      expect(downs, [PointerDeviceKind.stylus]);
      expect(pans, isEmpty);
    });

    testWidgets('by default a finger draws, as before', (tester) async {
      await pump(tester);
      final finger = await tester.startGesture(const Offset(100, 100),
          kind: PointerDeviceKind.touch);
      await finger.moveBy(const Offset(0, -40));
      await finger.up();

      expect(downs, [PointerDeviceKind.touch]);
      expect(pans, isEmpty);
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

  group('pressure', () {
    Future<StrokePoint> downPoint(
        WidgetTester tester, PointerDownEvent event) async {
      StrokePoint? seen;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScenePointerListener(
            onPointerDown: (_, p) => seen = p,
            onPointerMove: (_, _) {},
            onPointerUp: (_, _) {},
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.sendEventToBinding(event);
      await tester.sendEventToBinding(PointerUpEvent(
          pointer: event.pointer, position: event.position, kind: event.kind));
      return seen!;
    }

    testWidgets('a pen reporting exactly 0.5 is real pressure, not a guess',
        (tester) async {
      final p = await downPoint(
          tester,
          const PointerDownEvent(
              pointer: 1,
              position: Offset(100, 100),
              kind: PointerDeviceKind.stylus,
              pressure: 0.5,
              pressureMin: 0,
              pressureMax: 1));

      expect(p.simulatePressure, isFalse);
      expect(p.pressure, 0.5);
    });

    testWidgets('a pen pressing lightly keeps its own value', (tester) async {
      final p = await downPoint(
          tester,
          const PointerDownEvent(
              pointer: 1,
              position: Offset(100, 100),
              kind: PointerDeviceKind.stylus,
              pressure: 0.2,
              pressureMin: 0,
              pressureMax: 1));

      expect(p.simulatePressure, isFalse);
      expect(p.pressure, closeTo(0.2, 1e-9));
    });

    testWidgets('a finger is simulated whatever value it reports',
        (tester) async {
      final p = await downPoint(
          tester,
          const PointerDownEvent(
              pointer: 1,
              position: Offset(100, 100),
              pressure: 0.83,
              pressureMin: 0,
              pressureMax: 1));

      expect(p.simulatePressure, isTrue);
      expect(p.pressure, 0.5);
    });

    testWidgets('a pen with no pressure range is simulated', (tester) async {
      final p = await downPoint(
          tester,
          const PointerDownEvent(
              pointer: 1,
              position: Offset(100, 100),
              kind: PointerDeviceKind.stylus));

      expect(p.simulatePressure, isTrue);
    });
  });

  group('isEraserGesture', () {
    test('an upside-down pen erases', () {
      expect(
          isEraserGesture(const PointerDownEvent(
              kind: PointerDeviceKind.invertedStylus)),
          isTrue);
    });

    test('a pen with its side button held erases', () {
      expect(
          isEraserGesture(const PointerDownEvent(
              kind: PointerDeviceKind.stylus, buttons: kPrimaryStylusButton)),
          isTrue);
    });

    test('a plain pen, a finger and a right-click do not', () {
      expect(
          isEraserGesture(
              const PointerDownEvent(kind: PointerDeviceKind.stylus)),
          isFalse);
      expect(isEraserGesture(const PointerDownEvent()), isFalse);
      // The secondary mouse button shares the stylus button's bit.
      expect(
          isEraserGesture(const PointerDownEvent(
              kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton)),
          isFalse);
    });
  });
}
