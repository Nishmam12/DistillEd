import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/editor/import/ocr_layout.dart';

void main() {
  /// A recognised line spanning the given box.
  OcrBox box(String text, double l, double t, double r, double b) =>
      (text: text, bounds: Rect.fromLTRB(l, t, r, b));

  group('layOutOcrBoxes', () {
    // Horizontal placement is taken from the recogniser exactly. Vertically the
    // result is the *text's own* line box centred on where the line was found —
    // the OCR box's height is only a locator, since for slanted handwriting its
    // axis-aligned height far exceeds the letters.
    test('a box maps into the picture rect proportionally', () {
      // Source 1000x1000, picture drawn at 100x100 from (0,0): 10x shrink.
      final placed = layOutOcrBoxes(
        boxes: [box('hello', 100, 200, 600, 300)],
        sourcePixels: const Size(1000, 1000),
        target: const Rect.fromLTWH(0, 0, 100, 100),
      );

      expect(placed.single.bounds.left, closeTo(10, 1e-9));
      expect(placed.single.bounds.right, closeTo(60, 1e-9));
      expect(placed.single.bounds.center.dy, closeTo(25, 1e-9));
    });

    test("the picture's position is carried through", () {
      final placed = layOutOcrBoxes(
        boxes: [box('hi', 0, 0, 100, 100)],
        sourcePixels: const Size(100, 100),
        target: const Rect.fromLTWH(500, 300, 100, 100),
      );
      expect(placed.single.bounds.left, closeTo(500, 1e-9));
      expect(placed.single.bounds.right, closeTo(600, 1e-9));
      expect(placed.single.bounds.center.dy, closeTo(350, 1e-9));
    });

    test('a picture resized out of its aspect ratio still maps correctly', () {
      // The user stretched the image after importing it; each axis scales on
      // its own, so the text stretches with the picture it belongs to.
      final placed = layOutOcrBoxes(
        boxes: [box('wide', 0, 0, 50, 50)],
        sourcePixels: const Size(100, 100),
        target: const Rect.fromLTWH(0, 0, 400, 100),
      );
      expect(placed.single.bounds.left, closeTo(0, 1e-9));
      expect(placed.single.bounds.right, closeTo(200, 1e-9));
      expect(placed.single.bounds.center.dy, closeTo(25, 1e-9));
    });

    test('a tall box does not produce giant text', () {
      // The device bug: ML Kit reports an axis-aligned box per line, so a line
      // of slanting handwriting gets a box far taller than its letters. Sizing
      // off height alone rendered lines several times too big, which then
      // wrapped because they no longer fitted the width.
      const long = 'fiction, no-fiction, academics etc.)';
      final placed = layOutOcrBoxes(
        boxes: [box(long, 0, 0, 400, 300)], // 400 wide, absurdly 300 tall
        sourcePixels: const Size(1000, 1000),
        target: const Rect.fromLTWH(0, 0, 1000, 1000),
      );

      final line = placed.single;
      expect(line.fontSize, lessThan(300 * kOcrFontHeightRatio),
          reason: 'height alone would have given 240');
      expect(estimateTextWidth(line.text, line.fontSize),
          lessThanOrEqualTo(400 + 1e-6),
          reason: 'the line must fit the width of the box it came from');
      expect(line.bounds.height, closeTo(line.fontSize * kOcrLineHeightRatio, 1e-9));
    });

    test('a wide, short box is limited by height instead', () {
      // The other way round: plenty of width, so height is the binding limit
      // and the text is not blown up to fill the box.
      final placed = layOutOcrBoxes(
        boxes: [box('hi', 0, 0, 900, 20)],
        sourcePixels: const Size(1000, 1000),
        target: const Rect.fromLTWH(0, 0, 1000, 1000),
      );
      expect(placed.single.fontSize, closeTo(20 * kOcrFontHeightRatio, 1e-9));
    });

    test('a supplied measurer is what decides the width fit', () {
      // Production passes a real text measurer; the default is only an
      // estimate. Doubling the reported width must halve the chosen size.
      List<PlacedText> withMeasurer(MeasureText m) => layOutOcrBoxes(
            boxes: [box('abcd', 0, 0, 400, 400)],
            sourcePixels: const Size(1000, 1000),
            target: const Rect.fromLTWH(0, 0, 1000, 1000),
            measureWidth: m,
          );

      final normal = withMeasurer((t, s) => t.length * s * 0.5);
      final wide = withMeasurer((t, s) => t.length * s);
      expect(wide.single.fontSize, closeTo(normal.single.fontSize / 2, 1e-9));
    });

    test('font size tracks the line height', () {
      final placed = layOutOcrBoxes(
        boxes: [box('tall', 0, 0, 100, 50)],
        sourcePixels: const Size(100, 100),
        target: const Rect.fromLTWH(0, 0, 100, 100),
      );
      // 50px tall box, drawn 1:1, sized just under so it doesn't overflow.
      expect(placed.single.fontSize, closeTo(50 * kOcrFontHeightRatio, 1e-9));
    });

    test('a hairline box is floored at the minimum readable size', () {
      final placed = layOutOcrBoxes(
        boxes: [box('tiny', 0, 0, 10, 1)],
        sourcePixels: const Size(1000, 1000),
        target: const Rect.fromLTWH(0, 0, 1000, 1000),
      );
      expect(placed.single.fontSize, kOcrMinFontSize);
    });

    test('blank and whitespace-only lines are dropped', () {
      final placed = layOutOcrBoxes(
        boxes: [
          box('', 0, 0, 10, 10),
          box('   ', 0, 20, 10, 30),
          box('real', 0, 40, 10, 50),
        ],
        sourcePixels: const Size(100, 100),
        target: const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(placed, hasLength(1));
      expect(placed.single.text, 'real');
    });

    test('surrounding whitespace is trimmed off the text', () {
      final placed = layOutOcrBoxes(
        boxes: [box('  padded  ', 0, 0, 10, 10)],
        sourcePixels: const Size(100, 100),
        target: const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(placed.single.text, 'padded');
    });

    test('reading order is preserved', () {
      final placed = layOutOcrBoxes(
        boxes: [
          box('first', 0, 0, 10, 10),
          box('second', 0, 20, 10, 30),
          box('third', 0, 40, 10, 50),
        ],
        sourcePixels: const Size(100, 100),
        target: const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(placed.map((p) => p.text), ['first', 'second', 'third']);
    });

    test('a degenerate box is skipped rather than inverted', () {
      final placed = layOutOcrBoxes(
        boxes: [box('flat', 10, 10, 10, 10)],
        sourcePixels: const Size(100, 100),
        target: const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(placed, isEmpty);
    });

    test('nothing to map onto yields nothing', () {
      const one = [(text: 'x', bounds: Rect.fromLTRB(0, 0, 1, 1))];
      expect(
          layOutOcrBoxes(
              boxes: one,
              sourcePixels: Size.zero,
              target: const Rect.fromLTWH(0, 0, 100, 100)),
          isEmpty);
      expect(
          layOutOcrBoxes(
              boxes: one,
              sourcePixels: const Size(100, 100),
              target: Rect.zero),
          isEmpty);
    });
  });
}
