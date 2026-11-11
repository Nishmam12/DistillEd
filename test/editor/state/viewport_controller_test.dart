import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/editor/state/viewport_controller.dart';

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

    test('manual zoom spans 50–300% in both modes', () {
      // Pinned as numbers, not as the constants the clamp reads, so widening
      // or narrowing the range has to be a deliberate edit here too.
      expect(ViewportController.infiniteMinZoom, 0.5);
      expect(ViewportController.infiniteMaxZoom, 3.0);
      expect(ViewportController.pageMinZoom, 0.5);
      expect(ViewportController.pageMaxZoom, 3.0);
    });

    test('page mode clamps zoom to the page range and centres a small page',
        () {
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
      // At the floor the page is still smaller than the viewport, so it is
      // centred.
      const z = ViewportController.pageMinZoom;
      expect(c.state.scrollX, closeTo((200 - 100 * z) / 2, 1e-9));
      expect(c.state.scrollY, closeTo((400 - 200 * z) / 2, 1e-9));
    });

    test('zooming out to 50% is allowed on the infinite canvas', () {
      // The old floor was 100%, so pinching out did nothing at all.
      final c = ViewportController();
      c.zoomAtPoint(0.5, const Offset(400, 300));
      expect(c.state.zoom, 0.5);
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

      test('a page zoomed past the fit keeps the same part on screen', () {
        // It used to keep the zoom, so half the canvas showed half as much:
        // the page looked as if it had zoomed in when the panel opened.
        final c = laidOut();
        c.zoomAtPoint(2.0, const Offset(500, 500));
        final before = c.state.visibleSceneRect(const Size(1000, 1000));

        c.configure(
          pageMode: true,
          pageSize: const Size(1000, 1000),
          viewportSize: const Size(560, 1000),
        );

        final after = c.state.visibleSceneRect(const Size(560, 1000));
        expect(c.state.zoom, closeTo(1.12, 1e-9));
        expect(after.left, closeTo(before.left, 1e-6));
        expect(after.right, closeTo(before.right, 1e-6));
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
        // The whole width of the page stays on screen, below the 50 % floor
        // that only manual zoom is held to.
        expect(c.state.zoom, closeTo(0.4, 1e-9));
      });

      test('closing the panel puts a zoomed page back exactly', () {
        final c = laidOut();
        c.zoomAtPoint(1.2, const Offset(300, 700));
        final before = c.state;

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

        expect(c.state.zoom, closeTo(before.zoom, 1e-9));
        expect(c.state.scrollX, closeTo(before.scrollX, 1e-9));
        expect(c.state.scrollY, closeTo(before.scrollY, 1e-9));
      });

      test('a view moved while the panel was open is scaled back, not reset',
          () {
        final c = laidOut();
        c.configure(
          pageMode: true,
          pageSize: const Size(1000, 1000),
          viewportSize: const Size(560, 1000),
        );
        c.zoomAtPoint(1.12, const Offset(0, 0));

        c.configure(
          pageMode: true,
          pageSize: const Size(1000, 1000),
          viewportSize: const Size(1000, 1000),
        );

        expect(c.state.zoom, closeTo(2.0, 1e-9));
      });

      test('a pinch below the auto-fitted zoom does not jump to the floor', () {
        final c = laidOut();
        c.configure(
          pageMode: true,
          pageSize: const Size(1000, 1000),
          viewportSize: const Size(400, 1000),
        );
        expect(c.state.zoom, closeTo(0.4, 1e-9));

        c.zoomAtPoint(0.39, const Offset(200, 500));
        expect(c.state.zoom, closeTo(0.4, 1e-9),
            reason: 'cannot go further out, but must not snap in to 50 %');
        c.zoomAtPoint(0.45, const Offset(200, 500));
        expect(c.state.zoom, closeTo(0.45, 1e-9));
      });

      test('fitZoom is 1.0 on the infinite canvas', () {
        final c = ViewportController();
        expect(c.fitZoom, 1.0);
      });
    });

    group('the infinite canvas when the AI panel docks', () {
      ViewportController laidOut() => ViewportController()
        ..configure(
          pageMode: false,
          pageSize: const Size(1000, 800),
          viewportSize: const Size(1000, 800),
        );

      void dock(ViewportController c) => c.configure(
            pageMode: false,
            pageSize: const Size(560, 800),
            viewportSize: const Size(560, 800),
          );

      void undock(ViewportController c) => c.configure(
            pageMode: false,
            pageSize: const Size(1000, 800),
            viewportSize: const Size(1000, 800),
          );

      test('zoomed out, it does not jump back to 100 %', () {
        final c = laidOut();
        c.zoomAtPoint(0.7, Offset.zero);
        dock(c);
        expect(c.state.zoom, lessThan(0.7));
      });

      test('keeps the same width of writing on screen', () {
        final c = laidOut();
        c.pan(const Offset(-300, -200));
        final before = c.state.visibleSceneRect(const Size(1000, 800));
        dock(c);
        final after = c.state.visibleSceneRect(const Size(560, 800));
        expect(after.left, closeTo(before.left, 1e-6));
        expect(after.top, closeTo(before.top, 1e-6));
        expect(after.right, closeTo(before.right, 1e-6));
      });

      test('closing the panel puts the view back exactly', () {
        final c = laidOut();
        c.zoomAtPoint(1.3, const Offset(400, 300));
        c.pan(const Offset(-50, -120));
        final before = c.state;
        dock(c);
        undock(c);
        expect(c.state.zoom, closeTo(before.zoom, 1e-9));
        expect(c.state.scrollX, closeTo(before.scrollX, 1e-9));
        expect(c.state.scrollY, closeTo(before.scrollY, 1e-9));
      });

      test('a keyboard shrinking only the height changes nothing', () {
        final c = laidOut();
        c.zoomAtPoint(1.3, const Offset(400, 300));
        final before = c.state;
        c.configure(
          pageMode: false,
          pageSize: const Size(1000, 450),
          viewportSize: const Size(1000, 450),
        );
        expect(c.state.zoom, closeTo(before.zoom, 1e-9));
        expect(c.state.scrollX, closeTo(before.scrollX, 1e-9));
        expect(c.state.scrollY, closeTo(before.scrollY, 1e-9));
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
