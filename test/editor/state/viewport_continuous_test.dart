import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/domain/model/page_size.dart';
import 'package:margo/editor/state/viewport_controller.dart';

void main() {
  group('page sizes', () {
    test('real sizes are paper at 96 dpi; fit screen has none', () {
      expect(PageSizeKind.a4Portrait.size, const Size(794, 1123));
      expect(PageSizeKind.a4Landscape.size, const Size(1123, 794));
      expect(PageSizeKind.letterPortrait.size, const Size(816, 1056));
      expect(PageSizeKind.fitScreen.size, isNull);
    });

    test('stored indices never move, and unknown ones read as fit screen', () {
      expect(PageSizeKind.fitScreen.index, 0,
          reason: 'what every existing notebook has in the column');
      expect(PageSizeKind.a4Portrait.index, 1);
      expect(PageSizeKind.fromIndex(99), PageSizeKind.fitScreen);
      expect(PageSizeKind.fromIndex(-1), PageSizeKind.fitScreen);
      expect(PageSizeKind.newNotebookDefault, PageSizeKind.a4Portrait);
    });
  });

  group('continuous viewport', () {
    const page = Size(794, 1123);
    const window = Size(1000, 800);
    const gap = ViewportController.pageGap;

    ViewportController continuous({bool above = false, bool below = false}) {
      final c = ViewportController()
        ..configure(
            pageMode: true,
            pageSize: page,
            viewportSize: window,
            continuous: true);
      c.setNeighbours(above: above, below: below);
      return c;
    }

    test('opens fitted to the page width, like a document', () {
      final c = continuous();
      expect(c.state.zoom, closeTo(window.width / page.width, 1e-9));
    });

    test('single page still fits the whole page', () {
      final c = ViewportController()
        ..configure(pageMode: true, pageSize: page, viewportSize: window);
      expect(c.state.zoom, closeTo(window.height / page.height, 1e-9));
    });

    test('scrolls past the bottom only when there is a page below', () {
      final alone = continuous();
      alone.pan(const Offset(0, -100000));
      final z = alone.state.zoom;
      expect(alone.state.scrollY, closeTo(window.height - page.height * z, 1e-6));

      final more = continuous(below: true);
      more.pan(const Offset(0, -100000));
      expect(more.state.scrollY,
          closeTo(window.height - (2 * page.height + gap) * z, 1e-6));
    });

    test('the page in the middle of the window is reported', () {
      final c = continuous(above: true, below: true);
      expect(c.pageAtMiddle(), 0);
      c.pan(Offset(0, -(page.height * c.state.zoom)));
      expect(c.pageAtMiddle(), 1);
      c.pan(Offset(0, 2 * page.height * c.state.zoom + 200));
      expect(c.pageAtMiddle(), -1);
    });

    test('a page step moves the view by one page, so nothing jumps', () {
      final c = continuous(below: true);
      c.pan(Offset(0, -(page.height * c.state.zoom)));
      // A point on the next page, in the old page's scene.
      final onNext = Offset(100, page.height + gap + 50);
      final before = c.state.toViewport(onNext);

      c.shiftPage(1, above: true, below: false);
      // The same point in the new page's own scene.
      final after = c.state.toViewport(const Offset(100, 50));
      expect((after - before).distance, lessThan(1e-6));
    });

    test('infinite mode is never continuous', () {
      final c = ViewportController()
        ..configure(
            pageMode: false,
            pageSize: window,
            viewportSize: window,
            continuous: true);
      expect(c.continuous, isFalse);
      expect(c.pageAtMiddle(), 0);
    });
  });
}
