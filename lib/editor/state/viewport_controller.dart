// Viewport for the unified canvas — ported from the proven 1.0.2
// `viewport_notifier.dart`. Transform model: screenX = scrollX + zoom * sceneX.
//
// Supports two layout modes (see [configure]): an infinite whiteboard and a
// single bounded page (pan clamped so the page stays in view / centred when
// it is smaller than the viewport). Manual zoom is bounded to 50–300% in both
// modes — the toolbar's zoom pill only ever zooms in/out within that range.
// A resize of the canvas (the AI panel docking) may take it lower, to keep the
// same writing on screen; see [ViewportController._resizeViewport].

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

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

  /// Space between pages in the continuous layout, in scene units.
  static const double pageGap = 32;

  ViewportController() : super(const ViewportState());

  // Current layout constraints. In infinite mode [_pageMode] is false and pan
  // is unconstrained; in page mode the page rect / viewport size drive clamping.
  bool _pageMode = false;

  /// Continuous layout: pages stacked top to bottom. The scene is still the
  /// current page's; the pages either side sit [pageGap] beyond its top and
  /// bottom edges, and may be scrolled to when [_pageAbove] / [_pageBelow].
  bool _continuous = false;
  bool _pageAbove = false;
  bool _pageBelow = false;
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

  bool get continuous => _continuous;

  /// The page size last configured (the page in scene units).
  Size get pageSize => _pageSize;

  /// Sets the active layout mode and the page / viewport geometry used for
  /// clamping, then re-applies constraints to the current state. Called by the
  /// canvas whenever the mode or its size changes.
  void configure({
    required bool pageMode,
    required Size pageSize,
    required Size viewportSize,
    bool continuous = false,
  }) {
    continuous = continuous && pageMode;
    final changed = _pageMode != pageMode ||
        _continuous != continuous ||
        _pageSize != pageSize ||
        _viewportSize != viewportSize;
    if (!changed) return;

    // Only the window onto the scene changed (the AI panel docked or closed,
    // the window was resized): keep the same writing on screen. On the
    // infinite canvas the "page" is just the canvas size, so it is ignored.
    final onlyResized = _pageMode == pageMode &&
        _continuous == continuous &&
        (!pageMode || _pageSize == pageSize) &&
        !_viewportSize.isEmpty &&
        !viewportSize.isEmpty;
    if (onlyResized) {
      _pageSize = pageSize;
      _resizeViewport(viewportSize);
      return;
    }
    _restorePoint = null;

    // Whether the whole page fitted on screen *before* this change, judged
    // against the old geometry — see the re-fit below.
    final wasWhole = state.zoom <= fitZoom + 1e-6;

    _pageMode = pageMode;
    _continuous = continuous;
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
    // Continuous: the page's width fills the window, and it is read by
    // scrolling down, like a document.
    if (_continuous) return _viewportSize.width / _pageSize.width;
    return math.min(_viewportSize.width / _pageSize.width,
        _viewportSize.height / _pageSize.height);
  }

  /// Continuous layout: whether there is a page above and below the current
  /// one to scroll to. Only re-applies the bounds; the view does not move
  /// unless it is now out of them.
  void setNeighbours({required bool above, required bool below}) {
    if (_pageAbove == above && _pageBelow == below) return;
    _pageAbove = above;
    _pageBelow = below;
    state = _constrain(state);
  }

  /// Continuous layout: the current page became the next one ([direction]
  /// 1) or the previous one (-1). Shifts the view by exactly one page and
  /// gap, so the same writing stays where it was on screen while the scene
  /// changes to the new page's.
  void shiftPage(int direction, {required bool above, required bool below}) {
    _restorePoint = null;
    _pageAbove = above;
    _pageBelow = below;
    final step = (_pageSize.height + pageGap) * state.zoom;
    state = _constrain(
        state.copyWith(scrollY: state.scrollY + direction * step));
  }

  /// Continuous layout: which page the middle of the window is on, relative
  /// to the current one: -1 above, 1 below, 0 the current page. Over the gap
  /// it counts as the nearer page, so pages switch half way across it.
  int pageAtMiddle() {
    if (!_continuous || _pageSize.isEmpty || _viewportSize.isEmpty) return 0;
    final y = (_viewportSize.height / 2 - state.scrollY) / state.zoom;
    if (_pageBelow && y > _pageSize.height + pageGap / 2) return 1;
    if (_pageAbove && y < -pageGap / 2) return -1;
    return 0;
  }

  /// The view to put back when the canvas returns to the size it had before it
  /// was last narrowed, so closing the AI panel undoes opening it exactly.
  /// Dropped as soon as the user moves the view themselves: after that the
  /// view they made is the one to keep, scaled back up by [_resizeViewport].
  ({Size size, ViewportState view})? _restorePoint;

  /// How far a resize may scale the view down. Well below the 50 % manual
  /// floor on purpose: keeping the same writing on screen in a canvas a third
  /// as wide needs a third of the zoom, and clamping it at 50 % is what used
  /// to cut the right-hand side off.
  static const double resizeMinZoom = 0.1;

  /// Keeps what was on screen on screen when the canvas changes size: zoom
  /// follows the change in width, and the scene point at the top-left corner
  /// stays there. A change in height alone (a keyboard, a split-screen
  /// divider) changes neither. Going back to the size recorded in
  /// [_restorePoint] restores that view exactly.
  void _resizeViewport(Size to) {
    final from = _viewportSize;
    final before = state;
    _viewportSize = to;

    final restore = _restorePoint;
    if (restore != null && restore.size == to) {
      _restorePoint = null;
      state = _constrain(restore.view);
      return;
    }
    _restorePoint ??= (size: from, view: before);

    final widthRatio = from.width > 0 ? to.width / from.width : 1.0;
    final zoom = (before.zoom * widthRatio).clamp(resizeMinZoom, _maxZoom);
    final k = zoom / before.zoom;
    state = _constrain(ViewportState(
      scrollX: before.scrollX * k,
      scrollY: before.scrollY * k,
      zoom: zoom,
    ));
  }

  void pan(Offset delta) {
    if (delta != Offset.zero) _restorePoint = null;
    state = _constrain(state.copyWith(
      scrollX: state.scrollX + delta.dx,
      scrollY: state.scrollY + delta.dy,
    ));
  }

  /// Zoom toward [focalScreen] (screen coords): the scene point under the focal
  /// stays put on screen.
  ///
  /// A view a resize left below [minZoom] may stay there or zoom in, but not
  /// zoom out further — and must not snap up to the floor on the first pinch.
  void zoomAtPoint(double newZoom, Offset focalScreen) {
    if (newZoom != state.zoom) _restorePoint = null;
    final floor = math.min(_minZoom, state.zoom);
    final clamped = newZoom.clamp(floor, _maxZoom);
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
    _restorePoint = null;
    final z = 1.0.clamp(_minZoom, _maxZoom);
    state = _constrain(const ViewportState().copyWith(zoom: z));
  }

  /// In page mode, keeps the page within the viewport: centred on any axis
  /// where the scaled page is smaller than the viewport, otherwise clamped so
  /// its edges cannot be dragged inside the viewport edges. No-op when infinite.
  ViewportState _constrain(ViewportState s) {
    if (!_pageMode || _pageSize.isEmpty || _viewportSize.isEmpty) return s;

    final pageW = _pageSize.width * s.zoom;

    final double sx = pageW <= _viewportSize.width
        ? (_viewportSize.width - pageW) / 2
        : s.scrollX.clamp(_viewportSize.width - pageW, 0.0);
    // Continuous: the scrollable column runs from the top of the page above
    // to the bottom of the page below, where there are such pages.
    final top = _continuous && _pageAbove ? -(_pageSize.height + pageGap) : 0.0;
    final bottom = _continuous && _pageBelow
        ? 2 * _pageSize.height + pageGap
        : _pageSize.height;
    final columnH = (bottom - top) * s.zoom;
    final double sy = columnH <= _viewportSize.height
        ? (_viewportSize.height - columnH) / 2 - top * s.zoom
        : s.scrollY.clamp(_viewportSize.height - bottom * s.zoom, -top * s.zoom);

    return s.copyWith(scrollX: sx, scrollY: sy);
  }
}

final viewportProvider =
    StateNotifierProvider.autoDispose<ViewportController, ViewportState>(
  (ref) => ViewportController(),
);
