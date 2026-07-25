import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/editor/state/viewport_controller.dart';

void main() {
  group('ViewportState transforms', () {
    test('toScene and toViewport are inverses', () {
      const v = ViewportState(scrollX: 50, scrollY: -20, zoom: 2);
      final scene = v.toScene(const Offset(150, 80));
      final back = v.toViewport(scene);
      expect(back.dx, closeTo(150, 1e-9));
      expect(back.dy, closeTo(80, 1e-9));
    });
  });

  group('ViewportController', () {
    test('pan accumulates deltas', () {
      final c = ViewportController();
      c.pan(const Offset(10, 5));
      c.pan(const Offset(-3, 2));
      expect(c.state.scrollX, 7);
      expect(c.state.scrollY, 7);
    });

    test('zoomAtPoint keeps the focal scene point fixed on screen', () {
      final c = ViewportController();
      const focal = Offset(200, 150);
      final sceneBefore = c.state.toScene(focal);
      c.zoomAtPoint(1.5, focal);
      final sceneAfter = c.state.toScene(focal);
      expect(c.state.zoom, 1.5);
      expect(sceneAfter.dx, closeTo(sceneBefore.dx, 1e-9));
      expect(sceneAfter.dy, closeTo(sceneBefore.dy, 1e-9));
    });

    test('zoom clamps to infinite-mode [minZoom, maxZoom] by default', () {
      final c = ViewportController();
      c.zoomAtPoint(99, Offset.zero);
      expect(c.state.zoom, ViewportController.infiniteMaxZoom);
      c.zoomAtPoint(0.0001, Offset.zero);
      expect(c.state.zoom, ViewportController.infiniteMinZoom);
    });

    test('page mode clamps zoom to 100–200% and centres a small page', () {
      final c = ViewportController();
      c.configure(
        pageMode: true,
        pageSize: const Size(100, 200),
        viewportSize: const Size(200, 400),
      );
      // Zoom is limited to the page range.
      c.zoomAtPoint(99, const Offset(100, 200));
      expect(c.state.zoom, ViewportController.pageMaxZoom);
      c.zoomAtPoint(0.0001, const Offset(100, 200));
      expect(c.state.zoom, ViewportController.pageMinZoom);
      // At the 100% floor the page is still smaller than the viewport, so it
      // is centred.
      expect(c.state.scrollX, closeTo((200 - 100 * 1.0) / 2, 1e-9));
      expect(c.state.scrollY, closeTo((400 - 200 * 1.0) / 2, 1e-9));
    });

    group('re-fitting when the viewport narrows', () {
      /// A page laid out full-width, as on first layout.
      ViewportController laidOut() => ViewportController()
        ..configure(
          pageMode: true,
          pageSize: const Size(1000, 1000),
          viewportSize: const Size(1000, 1000),
        );

      test('a page that fitted still fits after the AI panel docks', () {
        // The device bug: the panel halved the canvas and the right-hand side
        // of the page — writing included — slid off screen.
        final c = laidOut();
        expect(c.state.zoom, 1.0);

        c.configure(
          pageMode: true,
          pageSize: const Size(1000, 1000),
          viewportSize: const Size(560, 1000),
        );

        expect(c.state.zoom, closeTo(0.56, 1e-9));
        expect(1000 * c.state.zoom, lessThanOrEqualTo(560.0));
      });

      test('closing the panel restores the fit', () {
        final c = laidOut();
        c.configure(
          pageMode: true,
          pageSize: const Size(1000, 1000),
          viewportSize: const Size(560, 1000),
        );
        c.configure(
          pageMode: true,
          pageSize: const Size(1000, 1000),
          viewportSize: const Size(1000, 1000),
        );
        expect(c.state.zoom, closeTo(1.0, 1e-9));
      });

      test('a user zoomed in past the fit keeps their zoom', () {
        final c = laidOut();
        c.zoomAtPoint(2.0, const Offset(500, 500));

        c.configure(
          pageMode: true,
          pageSize: const Size(1000, 1000),
          viewportSize: const Size(560, 1000),
        );

        expect(c.state.zoom, 2.0,
            reason: 'they are inspecting detail, not reading the whole page');
      });

      test('the page size is what the canvas reports, not the viewport', () {
        // Latching happens in the canvas; the controller must honour a page
        // larger than the viewport rather than assuming they match.
        final c = laidOut();
        c.configure(
          pageMode: true,
          pageSize: const Size(1000, 1000),
          viewportSize: const Size(400, 500),
        );
        expect(c.fitZoom, closeTo(0.4, 1e-9));
        // 0.4 is below the auto-fit's own legibility floor (well below the
        // page-mode manual-zoom floor, which this safety net ignores), so
        // zoom clamps there and the page is pannable rather than shrunk past
        // legibility.
        expect(c.state.zoom, ViewportController.autoFitMinZoom);
      });

      test('fitZoom is 1.0 on the infinite canvas', () {
        final c = ViewportController();
        expect(c.fitZoom, 1.0);
      });
    });

    test('reset returns to identity', () {
      final c = ViewportController();
      c.pan(const Offset(40, 40));
      c.zoomAtPoint(3, const Offset(10, 10));
      c.reset();
      expect(c.state.scrollX, 0);
      expect(c.state.scrollY, 0);
      expect(c.state.zoom, 1.0);
    });
  });
}
