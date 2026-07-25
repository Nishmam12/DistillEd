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

  group('inlinePlacement', () {
    // A viewport looking at the middle of an infinite canvas.
    const visible = Rect.fromLTWH(200, 400, 1000, 800);

    test('the image is centred in the visible area, not tucked in a corner',
        () {
      final r = inlinePlacement(const Size(4000, 3000), visible);
      expect(r.center, visible.center);
      expect(r.width, closeTo(500, 1e-9));
      expect(r.height, closeTo(375, 1e-9));
    });

    test('it lands where the user is looking, not at the scene origin', () {
      final r = inlinePlacement(const Size(4000, 3000), visible);
      expect(visible.contains(r.center), isTrue);
      expect(r.left, greaterThan(visible.left));
      expect(r.right, lessThan(visible.right));
      expect(r.top, greaterThan(visible.top));
      expect(r.bottom, lessThan(visible.bottom));
    });

    test('in page mode it stays on the sheet when the view overhangs it', () {
      // Page mode centres a page smaller than the canvas, so the visible area
      // runs off the paper on both sides — content out there is clipped away.
      const page = Rect.fromLTWH(0, 0, 600, 900);
      const overhanging = Rect.fromLTRB(-120, -80, 720, 980);

      final r = inlinePlacement(const Size(4000, 3000), overhanging,
          page: page);

      expect(page.contains(r.topLeft), isTrue);
      expect(page.contains(r.bottomRight), isTrue);
      expect(r.center, page.center);
    });

    test('page mode centres on the visible slice when zoomed in', () {
      // Zoomed in on the lower half of the sheet: the image belongs there, not
      // at the middle of a page the user cannot currently see.
      const page = Rect.fromLTWH(0, 0, 600, 900);
      const lowerHalf = Rect.fromLTWH(0, 450, 600, 450);

      final r = inlinePlacement(const Size(4000, 3000), lowerHalf, page: page);

      expect(r.center, lowerHalf.center);
      expect(page.contains(r.center), isTrue);
    });

    test('a view scrolled clear off the page falls back to the page centre',
        () {
      const page = Rect.fromLTWH(0, 0, 600, 900);
      const elsewhere = Rect.fromLTWH(5000, 5000, 800, 800);

      final r = inlinePlacement(const Size(4000, 3000), elsewhere, page: page);

      expect(r.center, page.center,
          reason: 'off-page is clipped away; the page is at least findable');
    });

    test('a small image keeps its own size and is still centred', () {
      final r = inlinePlacement(const Size(40, 30), visible);
      expect(r.size, const Size(40, 30));
      expect(r.center, visible.center);
    });

    test('an unmeasurable source yields nothing to place', () {
      expect(inlinePlacement(Size.zero, visible), Rect.zero);
      expect(inlinePlacement(const Size(100, 100), Rect.zero), Rect.zero);
    });
  });
}
