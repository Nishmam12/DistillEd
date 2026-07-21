import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/editor/import/fit_image_rect.dart';

void main() {
  group('scaledToFit', () {
    test('a wider-than-target source is limited by width', () {
      expect(scaledToFit(const Size(400, 100), const Size(200, 200)),
          const Size(200, 50));
    });

    test('a taller-than-target source is limited by height', () {
      expect(scaledToFit(const Size(100, 400), const Size(200, 200)),
          const Size(50, 200));
    });

    test('aspect ratio survives', () {
      final fitted = scaledToFit(const Size(1600, 900), const Size(400, 400));
      expect(fitted.width / fitted.height, closeTo(1600 / 900, 1e-9));
    });

    test('a small source is scaled UP to fill', () {
      // A page import is meant to fill its sheet; leaving a small PDF page at
      // its pixel size would sit as a stamp in the corner.
      expect(scaledToFit(const Size(10, 10), const Size(200, 200)),
          const Size(200, 200));
    });

    test('an exact fit is left alone', () {
      expect(scaledToFit(const Size(200, 200), const Size(200, 200)),
          const Size(200, 200));
    });

    test('degenerate inputs yield nothing to place', () {
      expect(scaledToFit(const Size(0, 100), const Size(200, 200)), Size.zero);
      expect(scaledToFit(const Size(100, 0), const Size(200, 200)), Size.zero);
      expect(scaledToFit(const Size(100, 100), const Size(0, 200)), Size.zero);
      expect(scaledToFit(const Size(100, 100), const Size(200, -1)), Size.zero);
    });
  });

  group('fitCentred', () {
    test('a portrait page in a landscape sheet is centred horizontally', () {
      // An A4-ish page dropped on a tablet-shaped sheet.
      final r = fitCentred(
          const Size(1000, 1414), const Rect.fromLTWH(0, 0, 1400, 1000));

      expect(r.height, closeTo(1000, 1e-9), reason: 'height is the limit');
      expect(r.width, closeTo(1000 * 1000 / 1414, 1e-9));
      expect(r.center.dx, closeTo(700, 1e-9));
      expect(r.center.dy, closeTo(500, 1e-9));
    });

    test('a landscape page in a portrait sheet is centred vertically', () {
      final r = fitCentred(
          const Size(1414, 1000), const Rect.fromLTWH(0, 0, 1000, 1400));

      expect(r.width, closeTo(1000, 1e-9));
      expect(r.center.dy, closeTo(700, 1e-9));
    });

    test('the target need not start at the origin', () {
      final r = fitCentred(
          const Size(100, 100), const Rect.fromLTWH(50, 200, 400, 400));
      expect(r, const Rect.fromLTWH(50, 200, 400, 400));
    });

    test('a margin insets every side', () {
      final r = fitCentred(const Size(100, 100), const Rect.fromLTWH(0, 0, 200, 200),
          margin: 20);
      expect(r, const Rect.fromLTWH(20, 20, 160, 160));
    });

    test('a margin too thick to leave room yields nothing', () {
      expect(
          fitCentred(const Size(100, 100), const Rect.fromLTWH(0, 0, 100, 100),
              margin: 60),
          Rect.zero);
    });

    test('a degenerate source yields nothing rather than an inverted rect', () {
      final r =
          fitCentred(Size.zero, const Rect.fromLTWH(0, 0, 200, 200));
      expect(r, Rect.zero);
      expect(r.isEmpty, isTrue);
    });
  });

  group('inlineSize', () {
    test('a large photo is capped to the requested fraction of the view', () {
      // 4000px wide photo, 1000x800 of scene visible, half-view cap.
      final s = inlineSize(const Size(4000, 3000), const Size(1000, 800));
      expect(s.width, closeTo(500, 1e-9));
      expect(s.height, closeTo(375, 1e-9));
    });

    test('a small image is NOT blown up', () {
      // Unlike a page import: an inline figure upscaled to half the viewport
      // is just blurry.
      expect(inlineSize(const Size(40, 30), const Size(1000, 800)),
          const Size(40, 30));
    });

    test('the fraction is honoured', () {
      final quarter =
          inlineSize(const Size(4000, 4000), const Size(1000, 1000), fraction: 0.25);
      expect(quarter.width, closeTo(250, 1e-9));
    });

    test('aspect ratio survives the cap', () {
      final s = inlineSize(const Size(1600, 900), const Size(1000, 1000));
      expect(s.width / s.height, closeTo(1600 / 900, 1e-9));
    });

    test('nothing visible means nothing to place', () {
      expect(inlineSize(const Size(100, 100), Size.zero), Size.zero);
    });
  });
}
