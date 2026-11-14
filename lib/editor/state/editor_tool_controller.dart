// Active tool + pen/shape/text style for the unified canvas.
//
// `color`/`size`/`opacity` are the PEN's colour / width / opacity. The colour
// and opacity also style new shapes (one universal colour); shapes and the
// eraser have their own width ([EditorToolState.shapeSize], [eraserSize]) so
// a wide eraser never leaves a fat pen behind. Each pen kind remembers its own
// last pen ([EditorToolState.penMemory]), so switching kind never turns a
// ballpoint into a yellow 18 px one.

import 'package:flutter_riverpod/legacy.dart';

import '../../domain/model/scene_element.dart';
import 'pen_presets.dart';

enum EditorTool { select, pen, shape, text, frame, eraser, laser, hand, tape }

class EditorToolState {
  final EditorTool tool;
  final int color; // stroke / text colour, ARGB
  final double size; // pen stroke width
  final double opacity; // 0..1

  /// Outline width for new shapes.
  final double shapeSize;

  /// Eraser width (pixel eraser) and hit radius floor (stroke eraser).
  final double eraserSize;

  /// Colour of new revision tape.
  final int tapeColor;

  /// The last pen used of each kind. Read by [EditorToolController.setPenKind]
  /// and [EditorToolController.usePen].
  final Map<PenKind, PenStyle> penMemory;

  /// Which pen the pen tool draws with.
  final PenKind penKind;

  // Shape options.
  final ShapeType shapeType;
  final bool hasFill;
  final int fillColor;
  final FillStyle fillStyle;
  final StrokeStyle strokeStyle;
  final EdgeStyle edges;
  final Arrowhead startArrowhead;
  final Arrowhead endArrowhead;
  final bool elbowed;

  // Text options.
  final double fontSize;
  final String fontFamily;

  // Eraser: pixel (clears ink) vs element (removes whole elements).
  final bool eraserPixel;

  // Select tool: drag a free-form loop round things instead of a rectangle.
  final bool selectLasso;

  // Whether the active tool's floating options panel is showing. Distinct
  // from which tool is active: the panel opens (briefly) when a tool is
  // picked and closes the instant the user starts drawing — see
  // [EditorToolController.setTool] and [EditorToolController.closePanel].
  final bool panelOpen;

  const EditorToolState({
    this.tool = EditorTool.pen,
    this.color = 0xFF1F2933,
    this.size = 2.0,
    this.opacity = 1.0,
    this.shapeSize = 2.0,
    this.eraserSize = 12.0,
    this.tapeColor = kDefaultTapeColor,
    this.penMemory = const {},
    this.penKind = PenKind.ballpoint,
    this.shapeType = ShapeType.rectangle,
    this.hasFill = false,
    this.fillColor = 0xFFFFE066,
    this.fillStyle = FillStyle.hachure,
    this.strokeStyle = StrokeStyle.solid,
    this.edges = EdgeStyle.sharp,
    this.startArrowhead = Arrowhead.none,
    this.endArrowhead = Arrowhead.triangle,
    this.elbowed = false,
    this.fontSize = 20.0,
    this.fontFamily = 'Roboto',
    this.eraserPixel = false,
    this.selectLasso = false,
    this.panelOpen = true,
  });

  bool get isHand => tool == EditorTool.hand;

  EditorToolState copyWith({
    EditorTool? tool,
    int? color,
    double? size,
    double? opacity,
    double? shapeSize,
    double? eraserSize,
    int? tapeColor,
    Map<PenKind, PenStyle>? penMemory,
    PenKind? penKind,
    ShapeType? shapeType,
    bool? hasFill,
    int? fillColor,
    FillStyle? fillStyle,
    StrokeStyle? strokeStyle,
    EdgeStyle? edges,
    Arrowhead? startArrowhead,
    Arrowhead? endArrowhead,
    bool? elbowed,
    double? fontSize,
    String? fontFamily,
    bool? eraserPixel,
    bool? selectLasso,
    bool? panelOpen,
  }) {
    return EditorToolState(
      tool: tool ?? this.tool,
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      shapeSize: shapeSize ?? this.shapeSize,
      eraserSize: eraserSize ?? this.eraserSize,
      tapeColor: tapeColor ?? this.tapeColor,
      penMemory: penMemory ?? this.penMemory,
      penKind: penKind ?? this.penKind,
      shapeType: shapeType ?? this.shapeType,
      hasFill: hasFill ?? this.hasFill,
      fillColor: fillColor ?? this.fillColor,
      fillStyle: fillStyle ?? this.fillStyle,
      strokeStyle: strokeStyle ?? this.strokeStyle,
      edges: edges ?? this.edges,
      startArrowhead: startArrowhead ?? this.startArrowhead,
      endArrowhead: endArrowhead ?? this.endArrowhead,
      elbowed: elbowed ?? this.elbowed,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      eraserPixel: eraserPixel ?? this.eraserPixel,
      selectLasso: selectLasso ?? this.selectLasso,
      panelOpen: panelOpen ?? this.panelOpen,
    );
  }
}

class EditorToolController extends StateNotifier<EditorToolState> {
  EditorToolController() : super(const EditorToolState());

  /// Applies [pen], remembered from last time, unless the user has already
  /// changed something: a pen picked in the first moments must not be replaced
  /// by the remembered one when it finishes loading.
  void restorePen(PenStyle pen) {
    if (!_untouched) return;
    state = _drawingWith(state, pen);
  }

  /// Fills in the remembered pen of each kind, loaded from storage. What the
  /// user has already used this session wins over what was stored. Loading it
  /// does not count as the user changing something, whichever of the two
  /// loads finishes first.
  void restorePenMemory(Map<PenKind, PenStyle> pens) {
    if (pens.isEmpty) return;
    final wasUntouched = _untouched;
    state = state.copyWith(penMemory: {...pens, ...state.penMemory});
    if (wasUntouched) _loadedOnly = state;
  }

  /// The state after nothing but [restorePenMemory] ran, if that happened.
  EditorToolState? _loadedOnly;

  bool get _untouched =>
      identical(state, const EditorToolState()) ||
      identical(state, _loadedOnly);

  /// [s] drawing with [pen]: kind, colour, width, opacity. Shape fill follows
  /// the colour, as with [setColor].
  static EditorToolState _drawingWith(EditorToolState s, PenStyle pen) =>
      s.copyWith(
        penKind: pen.kind,
        color: pen.color,
        fillColor: pen.color,
        size: pen.size,
        opacity: pen.opacity,
      );

  /// [EditorToolState.penMemory] with the pen in use filed under its kind, for
  /// when the user moves to another kind and back.
  Map<PenKind, PenStyle> _rememberCurrent() =>
      {...state.penMemory, state.penKind: PenStyle.of(state)};

  /// Selects [tool]. Picking a *different* tool (re)opens its options panel —
  /// each tool gets a brief look at its own settings before the panel closes
  /// again. Re-tapping the tool that's already active instead toggles the
  /// panel, so tapping it again after it auto-closed brings it back.
  void setTool(EditorTool tool) {
    state = tool == state.tool
        ? state.copyWith(panelOpen: !state.panelOpen)
        : state.copyWith(tool: tool, panelOpen: true);
  }

  /// Switches to [tool] without opening its options panel: for the app moving
  /// the user between tools (into Select to place a picture, and back), where
  /// a panel sliding in would be noise.
  void useTool(EditorTool tool) =>
      state = state.copyWith(tool: tool, panelOpen: false);

  /// Hides the options panel without changing the active tool. Called the
  /// moment a canvas gesture begins (draw, erase, shape drag, …) so the panel
  /// never lingers over what the user is making.
  void closePanel() {
    if (!state.panelOpen) return;
    state = state.copyWith(panelOpen: false);
  }

  /// The one universal drawing colour: sets both the stroke colour (pen +
  /// shape outlines) and the shape fill colour together, so there is a single
  /// "current colour" for the whole app rather than a separate control per
  /// tool.
  void setColor(int color) =>
      state = state.copyWith(color: color, fillColor: color);
  /// The PEN's width. Shapes and the eraser have their own: [setShapeSize],
  /// [setEraserSize].
  void setSize(double size) => state = state.copyWith(size: size);
  void setOpacity(double opacity) => state = state.copyWith(opacity: opacity);
  void setShapeSize(double size) => state = state.copyWith(shapeSize: size);
  void setEraserSize(double size) => state = state.copyWith(eraserSize: size);
  void setTapeColor(int argb) => state = state.copyWith(tapeColor: argb);

  /// Switches to the pen tool drawing with [pen] (a saved pen, or the one
  /// remembered from last time). The pen it replaces is remembered under its
  /// kind.
  void usePen(PenStyle pen) => state = _drawingWith(
        state.copyWith(tool: EditorTool.pen, penMemory: _rememberCurrent()),
        pen,
      );

  /// Picks which pen the pen tool draws with (and makes the pen the tool).
  /// Another kind comes back as it was last used, or as its starter pen; the
  /// one being left is remembered. Picking the kind already in use changes
  /// nothing but the tool.
  void setPenKind(PenKind kind) {
    if (kind == state.penKind) {
      state = state.copyWith(tool: EditorTool.pen);
      return;
    }
    final memory = _rememberCurrent();
    state = _drawingWith(
      state.copyWith(tool: EditorTool.pen, penMemory: memory),
      memory[kind] ?? defaultPenFor(kind),
    );
  }

  void setShapeType(ShapeType t) =>
      state = state.copyWith(tool: EditorTool.shape, shapeType: t);

  /// Selects the arrow shape (an arrowhead-tipped line — set the arrowhead
  /// style to "none" for a plain line) as a first-class tool of its own,
  /// rather than one chip buried in the shape-type picker. Mirrors
  /// [setTool]'s open/toggle semantics: switching into it (re)opens the
  /// shape options panel; tapping it again while already active toggles the
  /// panel shut/open instead.
  void selectArrowTool() {
    final alreadyArrow =
        state.tool == EditorTool.shape && state.shapeType == ShapeType.arrow;
    state = alreadyArrow
        ? state.copyWith(panelOpen: !state.panelOpen)
        : state.copyWith(
            tool: EditorTool.shape,
            shapeType: ShapeType.arrow,
            panelOpen: true,
          );
  }

  void setHasFill(bool v) => state = state.copyWith(hasFill: v);
  void setFillStyle(FillStyle f) => state = state.copyWith(fillStyle: f);
  void setStrokeStyle(StrokeStyle s) => state = state.copyWith(strokeStyle: s);
  void setEdges(EdgeStyle e) => state = state.copyWith(edges: e);
  void setElbowed(bool v) => state = state.copyWith(elbowed: v);
  void setEndArrowhead(Arrowhead a) => state = state.copyWith(endArrowhead: a);
  void setFontSize(double s) => state = state.copyWith(fontSize: s);
  void setFontFamily(String f) => state = state.copyWith(fontFamily: f);
  void setEraserPixel(bool v) => state = state.copyWith(eraserPixel: v);
  void setSelectLasso(bool v) => state = state.copyWith(selectLasso: v);
}

/// The tool state for the open editor. Opens with the pen used last time, and
/// saves the pen (type, colour, size, opacity) whenever it changes — not on
/// tool switches, which change nothing worth remembering — and the last pen of
/// each kind whenever that changes.
final editorToolProvider =
    StateNotifierProvider.autoDispose<EditorToolController, EditorToolState>(
  (ref) {
    final prefs = ref.watch(penPreferencesProvider);
    final controller = EditorToolController();
    var lastPen = PenStyle.of(const EditorToolState());
    var lastMemory = const EditorToolState().penMemory;

    prefs.loadCurrent().then((saved) {
      if (saved == null || !controller.mounted) return;
      final pen = withoutOldDefault(saved);
      lastPen = pen; // restoring it is not a change worth saving
      controller.restorePen(pen);
    });
    prefs.loadByKind().then((pens) {
      if (!controller.mounted) return;
      // The listener below saves this once more; harmless, and simpler than
      // reaching into the controller's state from here.
      controller.restorePenMemory(
          {for (final e in pens.entries) e.key: withoutOldDefault(e.value)});
    });

    controller.addListener((state) {
      final pen = PenStyle.of(state);
      if (pen != lastPen) {
        lastPen = pen;
        prefs.saveCurrent(pen);
      }
      if (!identical(state.penMemory, lastMemory)) {
        lastMemory = state.penMemory;
        prefs.saveByKind(state.penMemory);
      }
    }, fireImmediately: false);
    return controller;
  },
);
