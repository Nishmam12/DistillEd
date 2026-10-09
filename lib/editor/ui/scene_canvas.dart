// The unified canvas: raw input (palm-rejected) → viewport transform → layered
// painters. Renders committed [SceneElement]s, the live pen stroke, the shape
// preview, the laser trail, and the selection overlay. All mutations go through
// the per-page undo/redo history.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../domain/commands/scene_command.dart';
import '../../domain/geometry/scene_geometry.dart';
import '../../domain/geometry/scene_hit_test.dart';
import '../../domain/geometry/selection_bounds.dart';
import '../../domain/geometry/element_transformer.dart';
import '../../domain/model/scene_element.dart';
import '../../domain/services/eraser_service.dart';
import '../../domain/services/frame_service.dart';
import '../../domain/services/pixel_eraser_service.dart';
import '../../domain/services/snap_engine.dart';
import '../../domain/model/template_type.dart';
import '../../features/audio/presentation/audio_providers.dart';
import '../render/background_layer.dart';
import '../input/scene_pointer_listener.dart';
import '../render/freehand_path.dart';
import '../render/scene_active_stroke_layer.dart';
import '../render/scene_image_cache.dart';
import '../render/scene_laser_layer.dart';
import '../render/scene_preview_layer.dart';
import '../render/scene_static_layer.dart';
import '../render/selection_overlay_layer.dart';
import '../state/editor_tool_controller.dart';
import '../state/history_controller.dart';
import '../state/ink_gesture_providers.dart';
import '../state/scene_controller.dart';
import '../state/scene_image_cache_provider.dart';
import '../state/selection_controller.dart';
import '../state/viewport_controller.dart';
import '../tools/ink_gestures.dart';
import '../tools/shape_factory.dart';
import 'text_input_dialog.dart';
import '../../core/theme/app_colors.dart';

part 'scene_canvas_tools.dart';

const double _kSnapScreen = 8.0;
const int _kLaserFadeMs = 700;

enum _SelMode { none, move, resize, rotate, marquee }

class SceneCanvas extends ConsumerStatefulWidget {
  final int notebookId;
  final int pageId;
  final Color backgroundColor;
  final TemplateType templateType;

  /// When true the canvas is a single bounded page (matching the canvas aspect)
  /// with zoom limited to 50–300%; otherwise it is an infinite whiteboard.
  final bool pageMode;

  /// The page's size in page mode, when the owner keeps one that outlives this
  /// canvas. Null falls back to latching the first layout locally — fine for a
  /// canvas that is never rebuilt, but not for one keyed by page id.
  final Size? pageSize;

  const SceneCanvas({
    super.key,
    required this.notebookId,
    required this.pageId,
    this.backgroundColor = const Color(0xFFFFFDF7),
    this.templateType = TemplateType.blank,
    this.pageMode = false,
    this.pageSize,
  });

  @override
  ConsumerState<SceneCanvas> createState() => _SceneCanvasState();
}

class _SceneCanvasState extends ConsumerState<SceneCanvas>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<List<StrokePoint>> _active = ValueNotifier(const []);
  final ValueNotifier<SceneShapeElement?> _preview = ValueNotifier(null);
  final ValueNotifier<Rect?> _marquee = ValueNotifier(null);
  final ValueNotifier<List<(Offset, Offset)>> _guides = ValueNotifier(const []);
  final ValueNotifier<Set<String>> _eraserPending = ValueNotifier(const {});
  final ValueNotifier<List<LaserPoint>> _laser = ValueNotifier(const []);

  late final Ticker _ticker;
  late final SceneImageCache _imageCache;

  List<SceneElement>? _imageScanFor;
  List<String> _imagePaths = const [];

  Offset? _shapeStart;
  int _shapeSeed = 0;
  int _seq = 0;
  Offset _lastErase = Offset.zero;

  // Selection gesture state.
  _SelMode _selMode = _SelMode.none;
  HandlePos? _activeHandle;
  Rect _selBoxStart = Rect.zero;
  Offset _gestureStartScene = Offset.zero;
  List<SceneElement> _selOriginals = const [];
  List<Rect> _snapTargets = const [];
  bool _didTransform = false;

  // Last viewport configuration pushed to the controller, to avoid redundant
  // post-frame updates.
  Size? _configuredSize;
  bool? _configuredPageMode;

  // The page's own size in page mode, latched from the first layout and held
  // for as long as the mode lasts. See [_syncViewportConfig] for why it cannot
  // simply track the canvas.
  Size? _pageSize;

  ScenePageKey get _key =>
      (notebookId: widget.notebookId, pageId: widget.pageId);

  HistoryController get _history => ref.read(historyProvider(_key).notifier);
  SceneController get _scene =>
      ref.read(sceneControllerProvider(_key).notifier);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onLaserTick);
    _imageCache = ref.read(sceneImageCacheProvider);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _active.dispose();
    _preview.dispose();
    _marquee.dispose();
    _guides.dispose();
    _eraserPending.dispose();
    _laser.dispose();
    super.dispose();
  }

  // ---- coordinate helpers ---------------------------------------------------

  Offset _toScene(StrokePoint screen) =>
      ref.read(viewportProvider).toScene(Offset(screen.x, screen.y));

  StrokePoint _scenePoint(StrokePoint screen) {
    final s = _toScene(screen);
    return screen.copyWith(x: s.dx, y: s.dy);
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  List<SceneElement> _selectedElements() {
    final ids = ref.read(selectionProvider);
    return ref
        .read(sceneControllerProvider(_key))
        .where((e) => ids.contains(e.id))
        .toList();
  }

  // ---- pointer routing ------------------------------------------------------

  void _onDown(PointerEvent _, StrokePoint p) {
    final tool = ref.read(editorToolProvider);
    // The tool's options panel is only ever meant to be seen briefly after
    // picking the tool — the moment the user actually starts using it on the
    // page, the panel should get out of the way.
    ref.read(editorToolProvider.notifier).closePanel();
    switch (tool.tool) {
      case EditorTool.select:
        _onSelectDown(p);
      case EditorTool.pen:
        _active.value = [_scenePoint(p)];
      case EditorTool.shape:
        _shapeStart = _toScene(p);
        _shapeSeed = math.Random().nextInt(0x7fffffff);
        _preview.value = ShapeFactory.build(
            tool: tool,
            start: _shapeStart!,
            current: _shapeStart!,
            id: '_preview',
            zOrder: 0,
            seed: _shapeSeed);
      case EditorTool.frame:
        _shapeStart = _toScene(p);
        _preview.value = _framePreview(_shapeStart!, _shapeStart!);
      case EditorTool.eraser:
        _onEraserDown(tool, p);
      case EditorTool.laser:
        _addLaser(_toScene(p));
      case EditorTool.text:
      case EditorTool.hand:
        break;
    }
  }

  void _onMove(PointerEvent _, StrokePoint p) {
    final tool = ref.read(editorToolProvider);
    switch (tool.tool) {
      case EditorTool.select:
        _onSelectMove(p);
      case EditorTool.pen:
        if (_active.value.isNotEmpty) {
          _active.value = [..._active.value, _scenePoint(p)];
        }
      case EditorTool.shape:
        if (_shapeStart != null) {
          _preview.value = ShapeFactory.build(
              tool: tool,
              start: _shapeStart!,
              current: _toScene(p),
              id: '_preview',
              zOrder: 0,
              seed: _shapeSeed);
        }
      case EditorTool.frame:
        if (_shapeStart != null) {
          _preview.value = _framePreview(_shapeStart!, _toScene(p));
        }
      case EditorTool.eraser:
        _onEraserMove(tool, p);
      case EditorTool.laser:
        _addLaser(_toScene(p));
      case EditorTool.text:
      case EditorTool.hand:
        break;
    }
  }

  void _onUp(PointerEvent _, StrokePoint p) {
    final tool = ref.read(editorToolProvider);
    switch (tool.tool) {
      case EditorTool.select:
        _onSelectUp(p);
      case EditorTool.pen:
        _commitStroke(tool, upMs: p.t);
      case EditorTool.shape:
        _commitShape(tool, _toScene(p));
      case EditorTool.frame:
        _commitFrame(_toScene(p));
      case EditorTool.eraser:
        _onEraserUp(tool);
      case EditorTool.text:
        _createText(_toScene(p));
      case EditorTool.laser:
      case EditorTool.hand:
        break;
    }
  }

  void _cancel() {
    _active.value = const [];
    _preview.value = null;
    _shapeStart = null;
    _marquee.value = null;
    _guides.value = const [];
    _eraserPending.value = const {};
    // A transform already applied in memory (never persisted) must not stay on
    // screen without a history entry: put the originals back.
    if (_didTransform && _selOriginals.isNotEmpty) {
      _scene.updateInMemory(_selOriginals);
    }
    _selMode = _SelMode.none;
    _activeHandle = null;
    _selOriginals = const [];
    _didTransform = false;
  }

  void _onViewportUpdate(Offset panDelta, Offset focal, double scaleDelta) {
    final vp = ref.read(viewportProvider.notifier);
    vp.pan(panDelta);
    if (scaleDelta != 1.0) {
      vp.zoomAtPoint(ref.read(viewportProvider).zoom * scaleDelta, focal);
    }
  }

  /// Pushes the current page geometry / mode to the viewport controller once
  /// per change (after layout, so the canvas size is known).
  ///
  /// In page mode the page takes its size from [SceneCanvas.pageSize], or from
  /// the *first* layout here — so it fills the view at 100% — and then keeps
  /// it. The canvas is only a window onto that sheet: it shrinks whenever the
  /// AI panel docks beside it, and a page that tracked the canvas would shrink
  /// with it, cutting the right-hand side off existing writing, since the page
  /// rect is also what the scene is clipped to. Holding the sheet and reporting
  /// the smaller canvas as the viewport instead lets the controller re-fit the
  /// zoom and keep the whole page visible.
  void _syncViewportConfig(Size size) {
    if (size.isEmpty) return;
    if (_configuredSize == size && _configuredPageMode == widget.pageMode) {
      return;
    }
    if (_configuredPageMode != widget.pageMode) _pageSize = null;
    _configuredSize = size;
    _configuredPageMode = widget.pageMode;

    final page =
        widget.pageMode ? (widget.pageSize ?? (_pageSize ??= size)) : size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(viewportProvider.notifier).configure(
            pageMode: widget.pageMode,
            pageSize: page,
            viewportSize: size,
          );
    });
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final viewport = ref.watch(viewportProvider);
    final tool = ref.watch(editorToolProvider);
    final elements = ref.watch(sceneControllerProvider(_key));
    final selectedIds = ref.watch(selectionProvider);

    // Kick off decoding of any referenced images (idempotent / deduped). The
    // path scan only reruns when the element list changes, not on every pan
    // frame; a changed path set also gives earlier failures another chance.
    if (!identical(elements, _imageScanFor)) {
      _imageScanFor = elements;
      final paths = [
        for (final e in elements)
          if (e is ImageElement) e.relativeImagePath,
      ];
      if (!listEquals(paths, _imagePaths)) _imageCache.retryFailed();
      _imagePaths = paths;
    }
    _imageCache.ensure(_imagePaths);

    Rect? boxScreen;
    List<Offset> handleScreen = const [];
    Offset? rotateScreen;
    if (tool.tool == EditorTool.select && _selMode != _SelMode.marquee) {
      final selected =
          elements.where((e) => selectedIds.contains(e.id)).toList();
      final box = SelectionBounds.union(selected);
      if (box != null) {
        boxScreen = viewport.toViewportRect(box);
        handleScreen = [
          for (final p in SelectionBounds.handlePoints(box).values)
            viewport.toViewport(p)
        ];
        rotateScreen = boxScreen.topCenter - const Offset(0, kRotateGap);
      }
    }

    final eraserPixelActive =
        tool.tool == EditorTool.eraser && tool.eraserPixel;
    final activeColor = eraserPixelActive ? 0xFF9AA0A6 : tool.color;
    final activeOpacity = eraserPixelActive ? 0.4 : tool.opacity;

    return LayoutBuilder(builder: (context, constraints) {
      final canvasSize = constraints.biggest;
      _syncViewportConfig(canvasSize);
      // The page keeps the size it was laid out at, not whatever the canvas has
      // shrunk to (see [_syncViewportConfig]); null means infinite whiteboard.
      final Rect? pageRect = widget.pageMode
          ? (Offset.zero & (widget.pageSize ?? _pageSize ?? canvasSize))
          : null;

      return ScenePointerListener(
        isHandTool: tool.isHand,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onStrokeCancel: _cancel,
        onViewportUpdate: _onViewportUpdate,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: BackgroundLayer(
                    backgroundColor: widget.backgroundColor,
                    // The canvas backdrop is chrome; the page itself is content.
                    deskColor: context.colors.bgPrimary,
                    templateType: widget.templateType,
                    scrollX: viewport.scrollX,
                    scrollY: viewport.scrollY,
                    zoom: viewport.zoom,
                    pageRect: pageRect,
                  ),
                  size: Size.infinite,
                ),
              ),
              _clipToPageScreen(
                  pageRect == null ? null : viewport.toViewportRect(pageRect),
                  Transform(
                    transform: viewport.toMatrix4(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _imageCache,
                            builder: (_, _) =>
                                ValueListenableBuilder<Set<String>>(
                              valueListenable: _eraserPending,
                              builder: (_, hidden, _) => CustomPaint(
                                painter: SceneStaticLayer(
                                  elements: elements,
                                  hiddenIds: hidden,
                                  imageResolver: _imageCache.get,
                                  imageEpoch: _imageCache.version,
                                ),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                        ),
                        RepaintBoundary(
                          child: ValueListenableBuilder<List<StrokePoint>>(
                            valueListenable: _active,
                            builder: (_, points, _) => CustomPaint(
                              painter: SceneActiveStrokeLayer(
                                points: points,
                                color: activeColor,
                                size: tool.size,
                                opacity: activeOpacity,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                        RepaintBoundary(
                          child: ValueListenableBuilder<SceneShapeElement?>(
                            valueListenable: _preview,
                            builder: (_, preview, _) => CustomPaint(
                              painter: ScenePreviewLayer(preview),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                        RepaintBoundary(
                          child: ValueListenableBuilder<List<LaserPoint>>(
                            valueListenable: _laser,
                            builder: (_, pts, _) => CustomPaint(
                              painter: SceneLaserLayer(
                                points: pts,
                                nowMs: DateTime.now().millisecondsSinceEpoch,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<Rect?>(
                    valueListenable: _marquee,
                    builder: (_, marqueeScene, _) =>
                        ValueListenableBuilder<List<(Offset, Offset)>>(
                      valueListenable: _guides,
                      builder: (_, guidesScene, _) => CustomPaint(
                        painter: SelectionOverlayLayer(
                          accent: context.colors.accent,
                          surface: context.colors.surface,
                          boxScreen: boxScreen,
                          handleScreen: handleScreen,
                          rotateScreen: rotateScreen,
                          marqueeScreen: marqueeScene == null
                              ? null
                              : viewport.toViewportRect(marqueeScene),
                          guides: [
                            for (final (a, b) in guidesScene)
                              (viewport.toViewport(a), viewport.toViewport(b))
                          ],
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Clips [child] to the page's on-screen rect when in page mode; returns it
  /// unchanged on the infinite canvas.
  Widget _clipToPageScreen(Rect? pageScreen, Widget child) {
    if (pageScreen == null) return child;
    return ClipRect(clipper: _RectClipper(pageScreen), child: child);
  }
}

/// Clips to a fixed screen-space rectangle (used to keep drawn content inside
/// the page in single-page mode).
class _RectClipper extends CustomClipper<Rect> {
  final Rect rect;
  const _RectClipper(this.rect);

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_RectClipper oldClipper) => rect != oldClipper.rect;
}
