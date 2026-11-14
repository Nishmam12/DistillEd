// The unified canvas: raw input (palm-rejected) → viewport transform → layered
// painters. Renders committed [SceneElement]s, the live pen stroke, the shape
// preview, the laser trail, and the selection overlay. All mutations go through
// the per-page undo/redo history.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../domain/commands/scene_command.dart';
import '../../domain/geometry/element_bounds.dart';
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
import '../render/background_layer.dart';
import '../input/scene_pointer_listener.dart';
import '../render/freehand_path.dart';
import '../render/scene_active_stroke_layer.dart';
import '../render/scene_element_painter.dart';
import '../render/scene_image_cache.dart';
import '../render/scene_laser_layer.dart';
import '../render/scene_preview_layer.dart';
import '../render/scene_static_layer.dart';
import '../render/selection_overlay_layer.dart';
import '../state/editor_tool_controller.dart';
import '../state/history_controller.dart';
import '../state/inline_text_request.dart';
import '../state/ink_gesture_providers.dart';
import '../state/scene_controller.dart';
import '../state/scene_image_cache_provider.dart';
import '../state/selection_controller.dart';
import '../state/viewport_controller.dart';
import '../tools/ink_gestures.dart';
import '../tools/shape_factory.dart';
import 'inline_text_editor.dart';
import 'text_input_dialog.dart' show SceneTextResult;
import '../../core/theme/app_colors.dart';

part 'scene_canvas_tools.dart';

const double _kSnapScreen = 8.0;
const int _kLaserFadeMs = 700;

enum _SelMode { none, move, resize, rotate, marquee }

/// Thinnest tape laid, in scene units: a quick stroke along a line of writing
/// still covers it.
const double kTapeMinThickness = 24;

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

  /// Stamps a new stroke with how far into a running lecture recording it
  /// began, given its first point's time (null when the point has none). Null,
  /// or a null answer, leaves the stroke unstamped. Supplied by the screen so
  /// the canvas engine does not depend on the audio feature.
  final ({int recordingId, int audioOffsetMs})? Function(int? firstPointMs)?
      stampStroke;

  const SceneCanvas({
    super.key,
    required this.notebookId,
    required this.pageId,
    this.backgroundColor = const Color(0xFFFFFDF7),
    this.templateType = TemplateType.blank,
    this.pageMode = false,
    this.pageSize,
    this.stampStroke,
  });

  @override
  ConsumerState<SceneCanvas> createState() => _SceneCanvasState();
}

class _SceneCanvasState extends ConsumerState<SceneCanvas>
    with SingleTickerProviderStateMixin {
  final ActiveStroke _active = ActiveStroke();
  final ValueNotifier<SceneShapeElement?> _preview = ValueNotifier(null);
  final ValueNotifier<Rect?> _marquee = ValueNotifier(null);

  /// The free-form lasso loop being drawn (scene points), or null when the
  /// select tool is dragging a rectangle.
  final ValueNotifier<List<Offset>?> _lasso = ValueNotifier(null);
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

  // Whether the gesture in progress erases whatever tool is selected: the pen
  // is upside down, or its side button was held when it touched down. Latched
  // at pointer-down so the whole gesture is one thing.
  bool _eraserGesture = false;

  // Selection gesture state.
  _SelMode _selMode = _SelMode.none;
  HandlePos? _activeHandle;
  Rect _selBoxStart = Rect.zero;
  Offset _gestureStartScene = Offset.zero;
  List<SceneElement> _selOriginals = const [];
  List<Rect> _snapTargets = const [];
  bool _didTransform = false;

  /// The locked element (a PDF page) under a select-tool touch that hit
  /// nothing else. Selected if the touch turns out to be a tap; see
  /// [_onSelectDown].
  String? _lockedUnderTap;

  // Last viewport configuration pushed to the controller, to avoid redundant
  // post-frame updates.
  Size? _configuredSize;
  bool? _configuredPageMode;

  // The page's own size in page mode, latched from the first layout and held
  // for as long as the mode lasts. See [_syncViewportConfig] for why it cannot
  // simply track the canvas.
  Size? _pageSize;

  // ---- typing on the page ----
  /// The text being typed on the page, or null.
  InlineTextSession? _inline;

  /// A fresh key per session, so each one starts with its own field.
  GlobalKey<InlineTextEditorState> _inlineKey = GlobalKey();

  /// A pointer went down on the page while typing: its lift commits the text
  /// (unless it turns into a pinch, which keeps the text open).
  bool _tapToCommit = false;

  /// How far the page was scrolled up to keep the text above the keyboard;
  /// given back when the text closes.
  double _liftedBy = 0;

  /// The editor is going away with the canvas (page switch, editor closed).
  bool _closing = false;

  /// The last tap on a text with the lasso, for double-tap to edit.
  String? _lastTextTapId;
  DateTime? _lastTextTapAt;

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
    // So the first pencil stroke already has its grain.
    FreehandPath.warmUp();
  }

  /// Opens [session] (with a fresh field) or, with null, closes the field.
  /// Here rather than in the tools extension, which may not call [setState].
  void _setInline(InlineTextSession? session) {
    setState(() {
      if (session != null) _inlineKey = GlobalKey();
      _inline = session;
    });
  }

  @override
  void deactivate() {
    // Leaving the page with text still open keeps what was typed. The tree is
    // locked here, so the commit itself is pushed a moment later (see
    // [_pushInline]); closing the editor commits earlier, as the route pops.
    if (_inline != null) {
      _closing = true;
      _inlineKey.currentState?.commit();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _active.dispose();
    _preview.dispose();
    _marquee.dispose();
    _lasso.dispose();
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

  /// The tool this gesture acts as: the selected one, or the eraser when the
  /// pen itself asked for it (see [_eraserGesture]).
  EditorToolState _gestureTool() {
    final tool = ref.read(editorToolProvider);
    return _eraserGesture && tool.tool != EditorTool.eraser
        ? tool.copyWith(tool: EditorTool.eraser)
        : tool;
  }

  /// Two fingers tapped together undo; three redo — the convention in
  /// Goodnotes, Notability and Procreate.
  void _onMultiFingerTap(int fingers) {
    final history = ref.read(historyProvider(_key));
    final ctl = ref.read(historyProvider(_key).notifier);
    if (fingers == 2 && history.canUndo) {
      ctl.undo();
    } else if (fingers == 3 && history.canRedo) {
      ctl.redo();
    } else {
      return;
    }
    unawaited(HapticFeedback.lightImpact());
  }

  /// The first time a pen touches the page while a finger still draws, offers
  /// once to let a finger scroll instead.
  void _maybeOfferFingerScroll(PointerEvent event) {
    if (event.kind != PointerDeviceKind.stylus &&
        event.kind != PointerDeviceKind.invertedStylus) {
      return;
    }
    final settings = ref.read(settingsProvider);
    if (!settings.loaded || settings.stylusTipShown || !settings.fingerDraws) {
      return;
    }
    final notifier = ref.read(settingsProvider.notifier);
    unawaited(notifier.markStylusTipShown());
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      content: const Text(
          'Writing with a pen? Let one finger scroll the page instead of drawing.'),
      action: SnackBarAction(
        label: 'Turn on',
        onPressed: () => unawaited(notifier.setFingerDraws(false)),
      ),
    ));
  }

  void _onDown(PointerEvent event, StrokePoint p) {
    _maybeOfferFingerScroll(event);
    // Typing on the page: a touch elsewhere on it finishes the text and does
    // nothing else.
    if (_inline != null) {
      _tapToCommit = true;
      return;
    }
    _eraserGesture = isEraserGesture(event);
    final tool = _gestureTool();
    // The tool's options panel is only ever meant to be seen briefly after
    // picking the tool — the moment the user actually starts using it on the
    // page, the panel should get out of the way.
    ref.read(editorToolProvider.notifier).closePanel();
    switch (tool.tool) {
      case EditorTool.select:
        _onSelectDown(p);
      case EditorTool.pen:
        _active.begin(_scenePoint(p),
            color: tool.color,
            size: tool.size,
            opacity: tool.opacity,
            kind: tool.penKind);
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
      case EditorTool.tape:
        _shapeStart = _toScene(p);
        _preview.value = null;
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
    if (_tapToCommit) return;
    final tool = _gestureTool();
    switch (tool.tool) {
      case EditorTool.select:
        _onSelectMove(p);
      case EditorTool.pen:
        _active.add(_scenePoint(p));
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
      case EditorTool.tape:
        if (_shapeStart != null) {
          _preview.value = _tapePreview(tool, _shapeStart!, _toScene(p));
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
    if (_tapToCommit) {
      _tapToCommit = false;
      _inlineKey.currentState?.commit();
      return;
    }
    final tool = _gestureTool();
    _eraserGesture = false;
    switch (tool.tool) {
      case EditorTool.select:
        _onSelectUp(p);
      case EditorTool.pen:
        _commitStroke(tool, upMs: p.t);
      case EditorTool.shape:
        _commitShape(tool, _toScene(p));
      case EditorTool.frame:
        _commitFrame(_toScene(p));
      case EditorTool.tape:
        _commitTape(tool, _toScene(p));
      case EditorTool.eraser:
        _onEraserUp(tool);
      case EditorTool.text:
        _beginNewText(_toScene(p));
      case EditorTool.laser:
      case EditorTool.hand:
        break;
    }
  }

  void _cancel() {
    // A pinch or pan while typing keeps the text open.
    _tapToCommit = false;
    _active.clear();
    _eraserGesture = false;
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
    final fingerDraws =
        ref.watch(settingsProvider.select((s) => s.fingerDraws));

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

    // Typing: a tool change finishes the text; "Edit text" in the selection
    // bar opens an existing one here.
    ref.listen(editorToolProvider.select((t) => t.tool),
        (_, _) => _inlineKey.currentState?.commit());
    ref.listen(inlineTextEditRequestProvider(_key), (_, id) {
      if (id == null) return;
      Future.microtask(() {
        if (mounted) {
          ref.read(inlineTextEditRequestProvider(_key).notifier).state = null;
        }
      });
      final el = ref
          .read(sceneControllerProvider(_key))
          .where((e) => e.id == id)
          .firstOrNull;
      if (el is TextElement) _beginEdit(el);
    });
    final inline = _inline;
    // Rebuild when the keyboard opens or closes, to keep the text above it.
    if (inline != null) MediaQuery.viewInsetsOf(context);

    return LayoutBuilder(builder: (context, constraints) {
      final canvasSize = constraints.biggest;
      _syncViewportConfig(canvasSize);
      // The page keeps the size it was laid out at, not whatever the canvas has
      // shrunk to (see [_syncViewportConfig]); null means infinite whiteboard.
      final Rect? pageRect = widget.pageMode
          ? (Offset.zero & (widget.pageSize ?? _pageSize ?? canvasSize))
          : null;

      final canvas = ScenePointerListener(
        isHandTool: tool.isHand,
        fingerPans: !fingerDraws,
        onMultiFingerTap: _onMultiFingerTap,
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
                                  // The text being edited is drawn by its
                                  // field, not twice.
                                  hiddenIds: inline?.editing == null
                                      ? hidden
                                      : {...hidden, inline!.editing!.id},
                                  imageResolver: _imageCache.get,
                                  imageEpoch: _imageCache.version,
                                ),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                        ),
                        RepaintBoundary(
                          child: CustomPaint(
                            painter: SceneActiveStrokeLayer(_active),
                            size: Size.infinite,
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
                        ValueListenableBuilder<List<Offset>?>(
                      valueListenable: _lasso,
                      builder: (_, loop, _) =>
                          ValueListenableBuilder<List<(Offset, Offset)>>(
                        valueListenable: _guides,
                        builder: (_, guidesScene, _) => CustomPaint(
                          painter: SelectionOverlayLayer(
                            accent: context.colors.accent,
                            surface: context.colors.surface,
                            boxScreen: boxScreen,
                            handleScreen: handleScreen,
                            rotateScreen: rotateScreen,
                            marqueeScreen: marqueeScene == null || loop != null
                                ? null
                                : viewport.toViewportRect(marqueeScene),
                            lassoScreen: loop == null
                                ? const []
                                : [for (final p in loop) viewport.toViewport(p)],
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
              ),
            ],
          ),
        ),
      );
      if (inline == null) return canvas;
      return Stack(
        fit: StackFit.expand,
        children: [
          canvas,
          Positioned.fill(
            // Closing the editor with text open keeps it: committed as the
            // route pops, while this page's undo history still exists.
            child: PopScope(
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) _inlineKey.currentState?.commit();
              },
              child: InlineTextEditor(
                key: _inlineKey,
                session: inline,
                viewport: viewport,
                onCommit: _commitInline,
                onCancel: _endInline,
                onFieldRect: _keepInlineVisible,
              ),
            ),
          ),
        ],
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
