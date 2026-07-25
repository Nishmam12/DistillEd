// Active tool + pen/shape/text style for the unified canvas.
//
// `color`/`size`/`opacity` are the stroke colour / width / opacity shared by pen
// and shapes; the remaining fields style new shapes. Editing the style of an
// existing selected element comes with selection in Phase 4.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/scene_element.dart';

enum EditorTool { select, pen, shape, text, frame, eraser, laser, hand }

class EditorToolState {
  final EditorTool tool;
  final int color; // stroke / text colour, ARGB
  final double size; // stroke width
  final double opacity; // 0..1

  // Shape options.
  final ShapeType shapeType;
  final bool hasFill;
  final int fillColor;
  final FillStyle fillStyle;
  final StrokeStyle strokeStyle;
  final EdgeStyle edges;
  final double roughness;
  final Arrowhead startArrowhead;
  final Arrowhead endArrowhead;
  final bool elbowed;

  // Text options.
  final double fontSize;
  final String fontFamily;

  // Eraser: pixel (clears ink) vs element (removes whole elements).
  final bool eraserPixel;

  const EditorToolState({
    this.tool = EditorTool.pen,
    this.color = 0xFF1F2933,
    this.size = 4.0,
    this.opacity = 1.0,
    this.shapeType = ShapeType.rectangle,
    this.hasFill = false,
    this.fillColor = 0xFFFFE066,
    this.fillStyle = FillStyle.hachure,
    this.strokeStyle = StrokeStyle.solid,
    this.edges = EdgeStyle.sharp,
    this.roughness = 0.0,
    this.startArrowhead = Arrowhead.none,
    this.endArrowhead = Arrowhead.triangle,
    this.elbowed = false,
    this.fontSize = 20.0,
    this.fontFamily = 'Roboto',
    this.eraserPixel = false,
  });

  bool get isHand => tool == EditorTool.hand;

  EditorToolState copyWith({
    EditorTool? tool,
    int? color,
    double? size,
    double? opacity,
    ShapeType? shapeType,
    bool? hasFill,
    int? fillColor,
    FillStyle? fillStyle,
    StrokeStyle? strokeStyle,
    EdgeStyle? edges,
    double? roughness,
    Arrowhead? startArrowhead,
    Arrowhead? endArrowhead,
    bool? elbowed,
    double? fontSize,
    String? fontFamily,
    bool? eraserPixel,
  }) {
    return EditorToolState(
      tool: tool ?? this.tool,
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      shapeType: shapeType ?? this.shapeType,
      hasFill: hasFill ?? this.hasFill,
      fillColor: fillColor ?? this.fillColor,
      fillStyle: fillStyle ?? this.fillStyle,
      strokeStyle: strokeStyle ?? this.strokeStyle,
      edges: edges ?? this.edges,
      roughness: roughness ?? this.roughness,
      startArrowhead: startArrowhead ?? this.startArrowhead,
      endArrowhead: endArrowhead ?? this.endArrowhead,
      elbowed: elbowed ?? this.elbowed,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      eraserPixel: eraserPixel ?? this.eraserPixel,
    );
  }
}

class EditorToolController extends StateNotifier<EditorToolState> {
  EditorToolController() : super(const EditorToolState());

  void setTool(EditorTool tool) => state = state.copyWith(tool: tool);
  void setColor(int color) => state = state.copyWith(color: color);
  void setSize(double size) => state = state.copyWith(size: size);
  void setOpacity(double opacity) => state = state.copyWith(opacity: opacity);

  void setShapeType(ShapeType t) =>
      state = state.copyWith(tool: EditorTool.shape, shapeType: t);
  void setHasFill(bool v) => state = state.copyWith(hasFill: v);
  void setFillColor(int c) => state = state.copyWith(fillColor: c);
  void setFillStyle(FillStyle f) => state = state.copyWith(fillStyle: f);
  void setStrokeStyle(StrokeStyle s) => state = state.copyWith(strokeStyle: s);
  void setEdges(EdgeStyle e) => state = state.copyWith(edges: e);
  void setRoughness(double r) => state = state.copyWith(roughness: r);
  void setElbowed(bool v) => state = state.copyWith(elbowed: v);
  void setEndArrowhead(Arrowhead a) => state = state.copyWith(endArrowhead: a);
  void setStartArrowhead(Arrowhead a) =>
      state = state.copyWith(startArrowhead: a);
  void setFontSize(double s) => state = state.copyWith(fontSize: s);
  void setFontFamily(String f) => state = state.copyWith(fontFamily: f);
  void setEraserPixel(bool v) => state = state.copyWith(eraserPixel: v);
}

final editorToolProvider =
    StateNotifierProvider.autoDispose<EditorToolController, EditorToolState>(
  (ref) => EditorToolController(),
);
