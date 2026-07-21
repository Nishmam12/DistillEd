// The unified canvas: raw input (palm-rejected) → viewport transform → layered
// painters. Renders committed [SceneElement]s, the live pen stroke, the shape
// preview, the laser trail, and the selection overlay. All mutations go through
// the per-page undo/redo history.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../features/editor/domain/models/template_type.dart';
import '../../features/editor/presentation/canvas/layers/background_layer.dart';
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
import '../state/scene_controller.dart';
import '../state/scene_image_cache_provider.dart';
import '../state/selection_controller.dart';
import '../state/viewport_controller.dart';
import '../tools/shape_factory.dart';

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
        _commitStroke(tool);
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
    _selMode = _SelMode.none;
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

  // ---- eraser ---------------------------------------------------------------

  double _eraserRadius(EditorToolState tool) => math.max(8.0, tool.size);

  void _onEraserDown(EditorToolState tool, StrokePoint p) {
    if (tool.eraserPixel) {
      _active.value = [_scenePoint(p)];
      return;
    }
    final scene = _toScene(p);
    _lastErase = scene;
    _eraserPending.value = EraserService.hitAlongSegment(
      a: scene,
      b: scene,
      radius: _eraserRadius(tool),
      elements: ref.read(sceneControllerProvider(_key)),
    );
  }

  void _onEraserMove(EditorToolState tool, StrokePoint p) {
    if (tool.eraserPixel) {
      if (_active.value.isNotEmpty) {
        _active.value = [..._active.value, _scenePoint(p)];
      }
      return;
    }
    final scene = _toScene(p);
    final hits = EraserService.hitAlongSegment(
      a: _lastErase,
      b: scene,
      radius: _eraserRadius(tool),
      elements: ref.read(sceneControllerProvider(_key)),
      skip: _eraserPending.value,
    );
    if (hits.isNotEmpty) {
      _eraserPending.value = {..._eraserPending.value, ...hits};
    }
    _lastErase = scene;
  }

  void _onEraserUp(EditorToolState tool) {
    if (tool.eraserPixel) {
      final points = _active.value;
      _active.value = const [];
      if (points.isEmpty) return;
      // True pixel erase: cut the previewed hole out of real geometry
      // (splitting strokes, converting cut shapes to strokes) as one undo
      // step — no clear-blend overlay element is committed anymore. The
      // outline is built exactly like the preview so the cut matches it.
      final eraserPath =
          FreehandPath.build(points, tool.size, isComplete: true);
      if (eraserPath == null) return;
      final result = ScenePixelEraserService.erase(
        eraserPath: eraserPath,
        elements: ref.read(sceneControllerProvider(_key)),
      );
      if (result.isEmpty) return;
      _history.push(
          PixelEraseCommand(removed: result.removed, added: result.added));
      return;
    }
    final ids = _eraserPending.value;
    _eraserPending.value = const {};
    if (ids.isEmpty) return;
    final removed = ref
        .read(sceneControllerProvider(_key))
        .where((e) => ids.contains(e.id))
        .toList();
    if (removed.isNotEmpty) _history.push(RemoveElementsCommand(removed));
  }

  // ---- laser ----------------------------------------------------------------

  void _addLaser(Offset scene) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _laser.value = [..._laser.value, LaserPoint(scene, now)];
    if (!_ticker.isActive) _ticker.start();
  }

  void _onLaserTick(Duration _) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final pruned = [
      for (final p in _laser.value)
        if (now - p.addedMs <= _kLaserFadeMs) p
    ];
    _laser.value = pruned;
    if (pruned.isEmpty) _ticker.stop();
  }

  // ---- selection gestures ---------------------------------------------------

  void _onSelectDown(StrokePoint p) {
    final scene = _toScene(p);
    final screen = Offset(p.x, p.y);
    final vp = ref.read(viewportProvider);
    final selected = _selectedElements();

    if (selected.isNotEmpty) {
      final box = SelectionBounds.union(selected)!;
      final rotateScreen =
          vp.toViewport(box.topCenter) - const Offset(0, kRotateGap);
      if ((screen - rotateScreen).distance <= kHandleHitRadius) {
        _beginGesture(_SelMode.rotate, box, scene, selected);
        return;
      }
      for (final entry in SelectionBounds.handlePoints(box).entries) {
        if ((screen - vp.toViewport(entry.value)).distance <=
            kHandleHitRadius) {
          _activeHandle = entry.key;
          _beginGesture(_SelMode.resize, box, scene, selected);
          return;
        }
      }
    }

    final shift = HardwareKeyboard.instance.isShiftPressed;
    final all = ref.read(sceneControllerProvider(_key));
    final hitId = SceneHitTest.topmostAt(scene, all);
    final selCtl = ref.read(selectionProvider.notifier);

    if (hitId != null) {
      final group = _groupIds(hitId, all);
      final current = ref.read(selectionProvider);
      if (shift) {
        selCtl.selectMany({...current, ...group});
      } else if (!current.contains(hitId)) {
        selCtl.selectMany(group);
      }
      _beginGesture(_SelMode.move, SelectionBounds.union(_selectedElements())!,
          scene, _selectedElements());
      return;
    }

    if (selected.isNotEmpty) {
      final box = SelectionBounds.union(selected)!;
      if (box.contains(scene)) {
        _beginGesture(_SelMode.move, box, scene, selected);
        return;
      }
    }

    if (!shift) selCtl.clear();
    _selMode = _SelMode.marquee;
    _gestureStartScene = scene;
    _marquee.value = Rect.fromPoints(scene, scene);
  }

  void _beginGesture(
      _SelMode mode, Rect box, Offset scene, List<SceneElement> originals) {
    _selMode = mode;
    _selBoxStart = box;
    _gestureStartScene = scene;
    // Moving a frame drags the elements it contains along with it.
    _selOriginals =
        mode == _SelMode.move ? _expandMoveTargets(originals) : originals;
    _didTransform = false;
  }

  /// Expands [selected] to include the members of any selected frame, so a move
  /// gesture carries the frame's contents.
  List<SceneElement> _expandMoveTargets(List<SceneElement> selected) {
    if (!selected.any((e) => e is FrameElement)) return selected;
    final all = ref.read(sceneControllerProvider(_key));
    final ids =
        FrameService.expandWithMembers(selected.map((e) => e.id).toSet(), all);
    return all.where((e) => ids.contains(e.id)).toList();
  }

  void _onSelectMove(StrokePoint p) {
    final scene = _toScene(p);
    switch (_selMode) {
      case _SelMode.move:
        _applyMove(scene);
      case _SelMode.resize:
        _applyResize(scene);
      case _SelMode.rotate:
        _applyRotate(scene);
      case _SelMode.marquee:
        _marquee.value = Rect.fromPoints(_gestureStartScene, scene);
      case _SelMode.none:
        break;
    }
  }

  void _applyMove(Offset scene) {
    final delta = scene - _gestureStartScene;
    final movingBox = _selBoxStart.shift(delta);
    final zoom = ref.read(viewportProvider).zoom;
    final selIds = _selOriginals.map((e) => e.id).toSet();
    final targets = [
      for (final e in ref.read(sceneControllerProvider(_key)))
        if (!selIds.contains(e.id)) SceneGeometry.worldAabb(e),
    ];
    final snap = SnapEngine.snap(movingBox, targets, _kSnapScreen / zoom);
    final finalDelta = delta + snap.adjust;
    _guides.value = [for (final g in snap.guides) (g.a, g.b)];
    _didTransform = true;
    _scene.updateMany([
      for (final e in _selOriginals) SceneTransformer.translate(e, finalDelta)
    ]);
  }

  void _applyResize(Offset scene) {
    final r = SelectionBounds.resize(
      _selBoxStart,
      _activeHandle!,
      scene,
      aspect: HardwareKeyboard.instance.isShiftPressed,
      fromCenter: HardwareKeyboard.instance.isAltPressed,
    );
    _didTransform = true;
    _scene.updateMany([
      for (final e in _selOriginals)
        SceneTransformer.scaleAbout(e, r.sx, r.sy, r.anchor)
    ]);
  }

  void _applyRotate(Offset scene) {
    final center = _selBoxStart.center;
    final start = _gestureStartScene - center;
    final cur = scene - center;
    final angle = math.atan2(cur.dy, cur.dx) - math.atan2(start.dy, start.dx);
    _didTransform = true;
    _scene.updateMany([
      for (final e in _selOriginals)
        SceneTransformer.rotateAbout(e, angle, center)
    ]);
  }

  void _onSelectUp(StrokePoint p) {
    if (_selMode == _SelMode.marquee) {
      final rect = _marquee.value;
      _marquee.value = null;
      if (rect != null) {
        final all = ref.read(sceneControllerProvider(_key));
        final ids = SceneHitTest.within(rect, all);
        final expanded = <String>{};
        for (final id in ids) {
          expanded.addAll(_groupIds(id, all));
        }
        ref.read(selectionProvider.notifier).selectMany(expanded);
      }
    } else if (_didTransform &&
        (_selMode == _SelMode.move ||
            _selMode == _SelMode.resize ||
            _selMode == _SelMode.rotate)) {
      // Snapshot the same set we transformed (move may include frame members
      // beyond the selection), so undo/redo round-trips them too.
      final ids = _selOriginals.map((e) => e.id).toSet();
      final after = ref
          .read(sceneControllerProvider(_key))
          .where((e) => ids.contains(e.id))
          .toList();
      _history.pushApplied(
          UpdateElementsCommand(before: _selOriginals, after: after));
    }
    _selMode = _SelMode.none;
    _activeHandle = null;
    _selOriginals = const [];
    _didTransform = false;
    _guides.value = const [];
  }

  Set<String> _groupIds(String id, List<SceneElement> all) {
    final el = all.firstWhere((e) => e.id == id);
    if (el.groupId.isEmpty) return {id};
    return all.where((e) => e.groupId == el.groupId).map((e) => e.id).toSet();
  }

  // ---- commit (pen / shape / text) ------------------------------------------

  void _commitStroke(EditorToolState tool) {
    final points = _active.value;
    _active.value = const [];
    if (points.isEmpty) return;
    _history.push(AddElementsCommand([
      FreehandElement(
        id: _newId(),
        zOrder: _scene.nextZOrder(),
        points: points,
        color: tool.color,
        size: tool.size,
        opacity: tool.opacity,
      )
    ]));
  }

  void _commitShape(EditorToolState tool, Offset end) {
    final start = _shapeStart;
    _shapeStart = null;
    _preview.value = null;
    if (start == null) return;
    if ((end - start).distance < 2) return;
    _history.push(AddElementsCommand([
      ShapeFactory.build(
        tool: tool,
        start: start,
        current: end,
        id: _newId(),
        zOrder: _scene.nextZOrder(),
        seed: _shapeSeed,
      )
    ]));
  }

  // ---- frame ----------------------------------------------------------------

  SceneShapeElement _framePreview(Offset a, Offset b) => SceneShapeElement(
        id: '_preview',
        zOrder: 0,
        shapeType: ShapeType.rectangle,
        geometryData: [a.dx, a.dy, b.dx, b.dy],
        color: 0xFF8A93A6,
        strokeWidth: 1.5,
        strokeStyle: StrokeStyle.dashed,
      );

  void _commitFrame(Offset end) {
    final start = _shapeStart;
    _shapeStart = null;
    _preview.value = null;
    if (start == null) return;
    final rect = Rect.fromPoints(start, end);
    if (rect.width < 8 || rect.height < 8) return;
    final count = ref
            .read(sceneControllerProvider(_key))
            .whereType<FrameElement>()
            .length +
        1;
    _history.push(AddElementsCommand([
      FrameElement(
        id: _newId(),
        zOrder: _scene.nextZOrder(),
        geometryData: [rect.left, rect.top, rect.right, rect.bottom],
        name: 'Frame $count',
      )
    ]));
  }

  Future<void> _createText(Offset scene) async {
    final tool = ref.read(editorToolProvider);
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add text'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Type text…'),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Add')),
          ],
        );
      },
    );
    if (text == null || text.trim().isEmpty) return;
    if (!mounted) return;
    final w = math.max(120.0, text.trim().length * tool.fontSize * 0.6);
    _history.push(AddElementsCommand([
      TextElement(
        id: _newId(),
        zOrder: _scene.nextZOrder(),
        geometryData: [
          scene.dx,
          scene.dy,
          scene.dx + w,
          scene.dy + tool.fontSize * 1.6
        ],
        text: text.trim(),
        color: tool.color,
        fontSize: tool.fontSize,
        opacity: tool.opacity,
      )
    ]));
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final viewport = ref.watch(viewportProvider);
    final tool = ref.watch(editorToolProvider);
    final elements = ref.watch(sceneControllerProvider(_key));
    final selectedIds = ref.watch(selectionProvider);

    // Kick off decoding of any referenced images (idempotent / deduped).
    _imageCache.ensure([
      for (final e in elements)
        if (e is ImageElement) e.relativeImagePath,
    ]);

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
                            builder: (_, __) =>
                                ValueListenableBuilder<Set<String>>(
                              valueListenable: _eraserPending,
                              builder: (_, hidden, ___) => CustomPaint(
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
                            builder: (_, points, __) => CustomPaint(
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
                            builder: (_, preview, __) => CustomPaint(
                              painter: ScenePreviewLayer(preview),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                        RepaintBoundary(
                          child: ValueListenableBuilder<List<LaserPoint>>(
                            valueListenable: _laser,
                            builder: (_, pts, __) => CustomPaint(
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
                    builder: (_, marqueeScene, __) =>
                        ValueListenableBuilder<List<(Offset, Offset)>>(
                      valueListenable: _guides,
                      builder: (_, guidesScene, __) => CustomPaint(
                        painter: SelectionOverlayLayer(
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
