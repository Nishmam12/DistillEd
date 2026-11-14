import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/presentation/sidebar/floating_ai_panel.dart';

void main() {
  const area = Size(1000, 800);

  group('fitting the panel to the page area', () {
    test('a rect that fits is left alone', () {
      const r = Rect.fromLTWH(100, 100, 360, 500);
      expect(fitFloatingAiPanel(r, area), r);
    });

    test('dragged off an edge, it is pulled back inside', () {
      final r = fitFloatingAiPanel(
          const Rect.fromLTWH(900, -50, 360, 500), area);
      expect(r.left, area.width - 360 - kFloatingAiPanelMargin);
      expect(r.top, kFloatingAiPanelMargin);
      expect(r.size, const Size(360, 500));
    });

    test('size stays between the minimum and 90% of the area', () {
      final small = fitFloatingAiPanel(const Rect.fromLTWH(0, 0, 50, 50), area);
      expect(small.size, kFloatingAiPanelMinSize);
      final big =
          fitFloatingAiPanel(const Rect.fromLTWH(0, 0, 5000, 5000), area);
      expect(big.width, area.width * kFloatingAiPanelMaxShare);
      expect(big.height, area.height * kFloatingAiPanelMaxShare);
    });

    test('after a rotation to a narrower area it still fits', () {
      const wide = Rect.fromLTWH(600, 100, 360, 500);
      final r = fitFloatingAiPanel(wide, const Size(700, 1000));
      expect(r.right, lessThanOrEqualTo(700 - kFloatingAiPanelMargin));
      expect(r.size, const Size(360, 500));
    });

    test('the keyboard lifts it, and shortens it only if it must', () {
      const r = Rect.fromLTWH(100, 250, 360, 500);
      final lifted = fitFloatingAiPanel(r, area, keyboard: 200);
      expect(lifted.bottom, lessThanOrEqualTo(600 - kFloatingAiPanelMargin));
      expect(lifted.height, 500, reason: 'there was room to lift it whole');

      final squeezed = fitFloatingAiPanel(r, area, keyboard: 450);
      expect(squeezed.bottom, lessThanOrEqualTo(350));
      expect(squeezed.height, lessThan(500));
    });

    test('the default sits top right, clear of the zoom pill', () {
      final r = defaultFloatingAiPanelRect(area);
      expect(r.right, lessThan(area.width - 60));
      expect(r.top, lessThan(40));
      expect(fitFloatingAiPanel(r, area), r);
    });
  });

  group('the floating card', () {
    late List<Rect> saved;
    late int pageTaps;

    Future<void> pump(WidgetTester tester,
        {Rect? rect, double keyboard = 0}) async {
      tester.view.physicalSize = area;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
              size: area, viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('page'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => pageTaps++,
                ),
              ),
              Positioned.fill(
                child: FloatingAiPanel(
                  rect: rect,
                  onRectChanged: saved.add,
                  builder: (context, onMove, onMoveEnd) => Column(
                    children: [
                      GestureDetector(
                        key: const ValueKey('header'),
                        dragStartBehavior: DragStartBehavior.down,
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (d) => onMove(d.delta),
                        onPanEnd: (_) => onMoveEnd(),
                        child: const SizedBox(height: 48, width: 400),
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
    }

    Rect card(WidgetTester tester) =>
        tester.getRect(find.byKey(const ValueKey('floatingAiPanel')));

    setUp(() {
      saved = [];
      pageTaps = 0;
    });

    testWidgets('dragging the header moves it, and the end is remembered',
        (tester) async {
      await pump(tester, rect: const Rect.fromLTWH(100, 100, 360, 500));
      await tester.drag(
          find.byKey(const ValueKey('header')), const Offset(-60, 40));
      await tester.pump();
      expect(card(tester).topLeft, const Offset(40, 140));
      expect(saved.single, const Rect.fromLTWH(40, 140, 360, 500));
    });

    testWidgets('the corner resizes it', (tester) async {
      await pump(tester, rect: const Rect.fromLTWH(100, 100, 360, 500));
      await tester.drag(find.byKey(const ValueKey('floatingAiPanelResize')),
          const Offset(80, -100));
      await tester.pump();
      expect(card(tester).size, const Size(440, 400));
      expect(card(tester).topLeft, const Offset(100, 100));
      expect(saved.single.size, const Size(440, 400));
    });

    testWidgets('the page beside the card still takes touches',
        (tester) async {
      await pump(tester, rect: const Rect.fromLTWH(600, 100, 360, 500));
      await tester.tapAt(const Offset(200, 400));
      expect(pageTaps, 1);
      await tester.tapAt(const Offset(700, 400));
      expect(pageTaps, 1, reason: 'a touch on the card is the card\'s');
    });

    testWidgets('the keyboard lifts it, and it goes back when it closes',
        (tester) async {
      const at = Rect.fromLTWH(100, 250, 360, 500);
      await pump(tester, rect: at, keyboard: 300);
      expect(card(tester).bottom, lessThanOrEqualTo(500));
      expect(saved, isEmpty, reason: 'only where it is shown changes');
      await pump(tester, rect: at);
      expect(card(tester), at);
    });
  });
}
