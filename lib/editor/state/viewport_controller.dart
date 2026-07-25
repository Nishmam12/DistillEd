// Viewport for the unified canvas — ported from the proven 1.0.2
// `viewport_notifier.dart`. Transform model: screenX = scrollX + zoom * sceneX.
//
// Supports two layout modes (see [configure]): an infinite whiteboard and a
// single bounded page (pan clamped so the page stays in view / centred when
// it is smaller than the viewport). Zoom is bounded to 50–300% in both modes
// — the toolbar's zoom pill only ever zooms in/out within that range, never
// past it.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ViewportState {
  final double scrollX;
  final double scrollY;
  final double zoom;

  const ViewportState({
    this.scrollX = 0.0,
    this.scrollY = 0.0,
    this.zoom = 1.0,
  });

  ViewportState copyWith({double? scrollX, double? scrollY, double? zoom}) {
    return ViewportState(
      scrollX: scrollX ?? this.scrollX,
      scrollY: scrollY ?? this.scrollY,
      zoom: zoom ?? this.zoom,
    );
  }

  /// Canvas transform: maps scene (x, y) → screen (x, y).
  Matrix4 toMatrix4() {
    final m = Matrix4.identity();
    m.setEntry(0, 0, zoom); // scale X
    m.setEntry(1, 1, zoom); // scale Y
    m.setEntry(0, 3, scrollX); // translate X
    m.setEntry(1, 3, scrollY); // translate Y
    return m;
  }

  /// Screen-space point → scene coordinates.
  Offset toScene(Offset screen) => Offset(
        (screen.dx - scrollX) / zoom,
        (screen.dy - scrollY) / zoom,
      );

  /// Scene-space point → screen coordinates (inverse of [toScene]).
  Offset toViewport(Offset scene) => Offset(
        scene.dx * zoom + scrollX,
        scene.dy * zoom + scrollY,
      );

  Rect toViewportRect(Rect scene) =>
      Rect.fromPoints(toViewport(scene.topLeft), toViewport(scene.bottomRight));

  /// The slice of the scene currently on screen, given the canvas's [viewport]
  /// size. Used to keep work the user asked for (e.g. an inserted AI note)
  /// inside what they can actually see, rather than somewhere they'd have to
  /// zoom out to find.
  Rect visibleSceneRect(Size viewport) => Rect.fromPoints(
        toScene(Offset.zero),
        toScene(Offset(viewport.width, viewport.height)),
      );
}

class ViewportController extends StateNotifier<ViewportState> {
  // Zoom is bounded to 50–300% in both modes: 50% pulls back far enough to see
  // a whole page's worth of work at once, and 300% is the ceiling (past that
  // ink and text start to look soft and the extra magnification isn't useful
  // for note-taking).
  static const double infiniteMinZoom = 0.5;
  static const double infiniteMaxZoom = 3.0;
  static const double pageMinZoom = 0.5;
  static const double pageMaxZoom = 3.0;

  // The floor for the auto re-fit safety net in [configure] — so a viewport
  // cramped enough that fitting the whole page would shrink it past legibility
  // still clamps to *something* readable. It coincides with the manual floor
  // now that that is also 50%; it is kept separate because the two answer
  // different questions (what a user may ask for vs. how far an automatic
  // re-fit may shrink the page on their behalf).
  static const double autoFitMinZoom = 0.5;

  ViewportController() : super(const ViewportState());

  // Current layout constraints. In infinite mode [_pageMode] is false and pan
  // is unconstrained; in page mode the page rect / viewport size drive clamping.
  bool _pageMode = false;
  Size _pageSize = Size.zero;
  Size _viewportSize = Size.zero;
  double _minZoom = infiniteMinZoom;
  double _maxZoom = infiniteMaxZoom;

  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;

  /// The canvas size last reported by [configure] — `Size.zero` until the
  /// canvas has laid out once. Pair with [ViewportState.visibleSceneRect] to
  /// find what's currently on screen in scene coordinates.
  Size get viewportSize => _viewportSize;

  /// Sets the active layout mode and the page / viewport geometry used for
  /// clamping, then re-applies constraints to the current state. Called by the
  /// canvas whenever the mode or its size changes.
  void configure({
    required bool pageMode,
    required Size pageSize,
    required Size viewportSize,
  }) {
    final changed = _pageMode != pageMode ||
        _pageSize != pageSize ||
        _viewportSize != viewportSize;
    if (!changed) return;

    // Whether the whole page fitted on screen *before* this change, judged
    // against the old geometry — see the re-fit below.
    final wasWhole = state.zoom <= fitZoom + 1e-6;

    _pageMode = pageMode;
    _pageSize = pageSize;
    _viewportSize = viewportSize;
    _minZoom = pageMode ? pageMinZoom : infiniteMinZoom;
    _maxZoom = pageMode ? pageMaxZoom : infiniteMaxZoom;

    // Re-fit when the viewport changes shape under a page that was fully
    // visible — docking the AI panel beside the canvas halves the width, and
    // without this the page keeps its size while the window around it shrinks,
    // so content slides off screen. A user who had deliberately zoomed past the
    // fit is left alone: they are inspecting detail, not reading the page.
    //
    // This re-fit is a clipping-prevention safety net, not a user zoom action,
    // so it stays free to go below [_minZoom] — otherwise a page could end up
    // wider than a narrowed viewport and slide off screen again, the exact bug
    // it exists to fix. Manual zoom (pinch / the zoom pill, via [zoomAtPoint])
    // is the only thing bounded to [_minZoom, _maxZoom].
    final target = wasWhole ? fitZoom : state.zoom;
    final z = wasWhole
        ? target.clamp(autoFitMinZoom, _maxZoom)
        : target.clamp(_minZoom, _maxZoom);
    state = _constrain(state.copyWith(zoom: z));
  }

  /// The largest zoom at which the whole page still fits the viewport. 1.0 in
  /// infinite mode, or before the canvas has reported its geometry — nothing is
  /// bounded there, so there is nothing to fit.
  double get fitZoom {
    if (!_pageMode || _pageSize.isEmpty || _viewportSize.isEmpty) return 1.0;
    return math.min(_viewportSize.width / _pageSize.width,
        _viewportSize.height / _pageSize.height);
  }

  void pan(Offset delta) {
    state = _constrain(state.copyWith(
      scrollX: state.scrollX + delta.dx,
      scrollY: state.scrollY + delta.dy,
    ));
  }

  /// Zoom toward [focalScreen] (screen coords): the scene point under the focal
  /// stays put on screen.
  void zoomAtPoint(double newZoom, Offset focalScreen) {
    final clamped = newZoom.clamp(_minZoom, _maxZoom);
    final sceneX = (focalScreen.dx - state.scrollX) / state.zoom;
    final sceneY = (focalScreen.dy - state.scrollY) / state.zoom;
    state = _constrain(state.copyWith(
      zoom: clamped,
      scrollX: focalScreen.dx - clamped * sceneX,
      scrollY: focalScreen.dy - clamped * sceneY,
    ));
  }

  /// Resets to a neutral view: identity in infinite mode, page centred at 100%
  /// (clamped into range) in page mode.
  void reset() {
    final z = 1.0.clamp(_minZoom, _maxZoom);
    state = _constrain(const ViewportState().copyWith(zoom: z));
  }

  /// In page mode, keeps the page within the viewport: centred on any axis
  /// where the scaled page is smaller than the viewport, otherwise clamped so
  /// its edges cannot be dragged inside the viewport edges. No-op when infinite.
  ViewportState _constrain(ViewportState s) {
    if (!_pageMode || _pageSize.isEmpty || _viewportSize.isEmpty) return s;

    final pageW = _pageSize.width * s.zoom;
    final pageH = _pageSize.height * s.zoom;

    final double sx = pageW <= _viewportSize.width
        ? (_viewportSize.width - pageW) / 2
        : s.scrollX.clamp(_viewportSize.width - pageW, 0.0);
    final double sy = pageH <= _viewportSize.height
        ? (_viewportSize.height - pageH) / 2
        : s.scrollY.clamp(_viewportSize.height - pageH, 0.0);

    return s.copyWith(scrollX: sx, scrollY: sy);
  }
}

final viewportProvider =
    StateNotifierProvider.autoDispose<ViewportController, ViewportState>(
  (ref) => ViewportController(),
);
