// Unified scene element model for InkFlow 2.0.
//
// Excalidraw treats every drawable (freehand ink, shape, text, image) as one
// element type sharing transform, z-order, opacity and lock state. InkFlow 2.0
// adopts the same: selection, transform, snapping, grouping, z-order and
// alignment all operate on [SceneElement], so they behave identically across
// ink and shapes.
//
// This is the in-memory model. On-disk persistence lives in
// `data/persistence/scene_element_record.dart`; conversion to/from the legacy
// Stroke / ShapeElement / ImportedContent formats lives in
// `data/migration/legacy_adapters.dart`.

import 'dart:ui';

import 'shape_type.dart';
import 'stroke_point.dart';
import 'element_style.dart';

export 'shape_type.dart' show ShapeType;
export 'stroke_point.dart' show StrokePoint;
export 'element_style.dart';

/// Discriminates the [SceneElement] subtype for flat persistence.
///
/// Append-only — the index is stored by Isar (`@enumerated`). Never reorder.
enum SceneElementKind { freehand, shape, text, image, frame }

/// Base type for everything drawable on a page. Immutable; mutate via copyWith.
sealed class SceneElement {
  /// Stable string id, preserved across edits and persistence.
  final String id;

  /// Paint order within the page; higher draws on top.
  final int zOrder;

  /// Rotation in radians, clockwise about the element centre.
  final double rotation;

  /// 0.0–1.0.
  final double opacity;

  /// Locked elements are not selected/transformed by normal gestures
  /// (e.g. a PDF background).
  final bool isLocked;

  /// Non-empty when this element belongs to a group; all elements sharing a
  /// groupId select and transform together.
  final String groupId;

  const SceneElement({
    required this.id,
    required this.zOrder,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.isLocked = false,
    this.groupId = '',
  });

  SceneElementKind get kind;
}

/// Freehand ink (the former [Stroke] / `.ink` content).
final class FreehandElement extends SceneElement {
  final List<StrokePoint> points;
  final int color; // ARGB int
  final double size;
  final bool isEraser;

  /// The lecture recording this stroke was drawn during, or null if there was
  /// none. Paired with [audioOffsetMs] to seek audio from a tapped stroke.
  final int? recordingId;

  /// How far into [recordingId] this stroke began, in milliseconds.
  ///
  /// An offset rather than a timestamp on purpose: StrokePoint.t is a monotonic
  /// engine clock whose epoch resets each launch, so it cannot be compared with
  /// a persisted recording. See `features/audio/domain/lecture_recording.dart`.
  final int? audioOffsetMs;

  const FreehandElement({
    required super.id,
    required super.zOrder,
    required this.points,
    required this.color,
    required this.size,
    this.isEraser = false,
    this.recordingId,
    this.audioOffsetMs,
    super.rotation,
    super.opacity,
    super.isLocked,
    super.groupId,
  });

  /// Whether tapping this stroke can seek audio.
  bool get hasAudio => recordingId != null && audioOffsetMs != null;

  @override
  SceneElementKind get kind => SceneElementKind.freehand;

  FreehandElement copyWith({
    String? id,
    int? zOrder,
    double? rotation,
    double? opacity,
    bool? isLocked,
    String? groupId,
    List<StrokePoint>? points,
    int? color,
    double? size,
    bool? isEraser,
    int? recordingId,
    int? audioOffsetMs,
  }) {
    return FreehandElement(
      id: id ?? this.id,
      zOrder: zOrder ?? this.zOrder,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      isLocked: isLocked ?? this.isLocked,
      groupId: groupId ?? this.groupId,
      points: points ?? this.points,
      color: color ?? this.color,
      size: size ?? this.size,
      isEraser: isEraser ?? this.isEraser,
      recordingId: recordingId ?? this.recordingId,
      audioOffsetMs: audioOffsetMs ?? this.audioOffsetMs,
    );
  }
}

/// Vector shape (rectangle, ellipse, diamond, line, arrow, triangle, polygon).
/// Text and image shapes from the legacy model become [TextElement] /
/// [ImageElement] instead, so this never carries ShapeType.textBox/svgImage.
final class SceneShapeElement extends SceneElement {
  final ShapeType shapeType;

  /// Interpreted per [shapeType] (see legacy ShapeElement docs):
  /// line/arrow [x0,y0,x1,y1(,+arrow pts)]; circle/rect [l,t,r,b];
  /// triangle/polygon/diamond [x0,y0,x1,y1,...].
  final List<double> geometryData;

  final int color; // stroke colour, ARGB
  final double strokeWidth;
  final bool hasFill;
  final int fillColor; // ARGB
  final int seed; // stable rough-render seed
  final double roughness; // 0 = crisp
  final String startBindingId;
  final String endBindingId;

  // Styling (defaults preserve the legacy look: hachure fill, solid stroke,
  // sharp corners, plain end-triangle arrows).
  final FillStyle fillStyle;
  final StrokeStyle strokeStyle;
  final EdgeStyle edges;
  final Arrowhead startArrowhead;
  final Arrowhead endArrowhead;
  final bool elbowed; // right-angle arrow routing

  const SceneShapeElement({
    required super.id,
    required super.zOrder,
    required this.shapeType,
    required this.geometryData,
    required this.color,
    required this.strokeWidth,
    this.hasFill = false,
    this.fillColor = 0,
    this.seed = 0,
    this.roughness = 0.0,
    this.startBindingId = '',
    this.endBindingId = '',
    this.fillStyle = FillStyle.hachure,
    this.strokeStyle = StrokeStyle.solid,
    this.edges = EdgeStyle.sharp,
    this.startArrowhead = Arrowhead.none,
    this.endArrowhead = Arrowhead.triangle,
    this.elbowed = false,
    super.rotation,
    super.opacity,
    super.isLocked,
    super.groupId,
  });

  @override
  SceneElementKind get kind => SceneElementKind.shape;

  SceneShapeElement copyWith({
    String? id,
    int? zOrder,
    double? rotation,
    double? opacity,
    bool? isLocked,
    ShapeType? shapeType,
    List<double>? geometryData,
    int? color,
    double? strokeWidth,
    bool? hasFill,
    int? fillColor,
    int? seed,
    double? roughness,
    String? startBindingId,
    String? endBindingId,
    FillStyle? fillStyle,
    StrokeStyle? strokeStyle,
    EdgeStyle? edges,
    Arrowhead? startArrowhead,
    Arrowhead? endArrowhead,
    bool? elbowed,
    String? groupId,
  }) {
    return SceneShapeElement(
      id: id ?? this.id,
      zOrder: zOrder ?? this.zOrder,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      isLocked: isLocked ?? this.isLocked,
      groupId: groupId ?? this.groupId,
      shapeType: shapeType ?? this.shapeType,
      geometryData: geometryData ?? List<double>.from(this.geometryData),
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      hasFill: hasFill ?? this.hasFill,
      fillColor: fillColor ?? this.fillColor,
      seed: seed ?? this.seed,
      roughness: roughness ?? this.roughness,
      startBindingId: startBindingId ?? this.startBindingId,
      endBindingId: endBindingId ?? this.endBindingId,
      fillStyle: fillStyle ?? this.fillStyle,
      strokeStyle: strokeStyle ?? this.strokeStyle,
      edges: edges ?? this.edges,
      startArrowhead: startArrowhead ?? this.startArrowhead,
      endArrowhead: endArrowhead ?? this.endArrowhead,
      elbowed: elbowed ?? this.elbowed,
    );
  }
}

/// Standalone or container-bound text (the former ShapeType.textBox).
final class TextElement extends SceneElement {
  /// Bounding box [left, top, right, bottom].
  final List<double> geometryData;
  final String text;
  final int color; // ARGB
  final double fontSize;
  final String fontFamily;
  final bool isBold;
  final bool isItalic;
  final TextAlignKind align;

  /// When non-empty, this text is bound to (centred in) the shape with this id.
  final String containerId;

  const TextElement({
    required super.id,
    required super.zOrder,
    required this.geometryData,
    required this.text,
    required this.color,
    this.fontSize = 16.0,
    this.fontFamily = 'Roboto',
    this.isBold = false,
    this.isItalic = false,
    this.align = TextAlignKind.left,
    this.containerId = '',
    super.rotation,
    super.opacity,
    super.isLocked,
    super.groupId,
  });

  @override
  SceneElementKind get kind => SceneElementKind.text;

  TextElement copyWith({
    String? id,
    int? zOrder,
    double? rotation,
    double? opacity,
    bool? isLocked,
    List<double>? geometryData,
    String? text,
    int? color,
    double? fontSize,
    String? fontFamily,
    bool? isBold,
    bool? isItalic,
    TextAlignKind? align,
    String? containerId,
    String? groupId,
  }) {
    return TextElement(
      id: id ?? this.id,
      zOrder: zOrder ?? this.zOrder,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      isLocked: isLocked ?? this.isLocked,
      groupId: groupId ?? this.groupId,
      geometryData: geometryData ?? List<double>.from(this.geometryData),
      text: text ?? this.text,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      align: align ?? this.align,
      containerId: containerId ?? this.containerId,
    );
  }
}

/// Raster/vector image element (the former ImportedContent free image / PDF
/// background, and ShapeType.svgImage). A PDF background migrates as a locked
/// image sent to the back.
final class ImageElement extends SceneElement {
  /// Bounding box [left, top, right, bottom].
  final List<double> geometryData;

  /// Path relative to the app documents dir (never absolute).
  final String relativeImagePath;

  /// Carries the legacy ImportedContent description (free-form, display only).
  final String sourceDescription;

  const ImageElement({
    required super.id,
    required super.zOrder,
    required this.geometryData,
    required this.relativeImagePath,
    this.sourceDescription = '',
    super.rotation,
    super.opacity,
    super.isLocked,
    super.groupId,
  });

  @override
  SceneElementKind get kind => SceneElementKind.image;

  Rect get boundsRect => Rect.fromLTRB(
        geometryData[0],
        geometryData[1],
        geometryData[2],
        geometryData[3],
      );

  ImageElement copyWith({
    String? id,
    int? zOrder,
    double? rotation,
    double? opacity,
    bool? isLocked,
    List<double>? geometryData,
    String? relativeImagePath,
    String? sourceDescription,
    String? groupId,
  }) {
    return ImageElement(
      id: id ?? this.id,
      zOrder: zOrder ?? this.zOrder,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      isLocked: isLocked ?? this.isLocked,
      groupId: groupId ?? this.groupId,
      geometryData: geometryData ?? List<double>.from(this.geometryData),
      relativeImagePath: relativeImagePath ?? this.relativeImagePath,
      sourceDescription: sourceDescription ?? this.sourceDescription,
    );
  }
}

/// A named rectangular container. Membership is geometric: an element belongs to
/// a frame when its centre falls inside the frame (see `FrameService`). Moving a
/// frame moves its members; the frame clips its members when rendered. Frames
/// always sit behind their members in paint order.
final class FrameElement extends SceneElement {
  /// Bounding box [left, top, right, bottom].
  final List<double> geometryData;

  /// Display label shown above the frame.
  final String name;

  const FrameElement({
    required super.id,
    required super.zOrder,
    required this.geometryData,
    this.name = 'Frame',
    super.rotation,
    super.opacity,
    super.isLocked,
    super.groupId,
  });

  @override
  SceneElementKind get kind => SceneElementKind.frame;

  Rect get boundsRect => Rect.fromLTRB(
        geometryData[0],
        geometryData[1],
        geometryData[2],
        geometryData[3],
      );

  FrameElement copyWith({
    String? id,
    int? zOrder,
    double? rotation,
    double? opacity,
    bool? isLocked,
    List<double>? geometryData,
    String? name,
    String? groupId,
  }) {
    return FrameElement(
      id: id ?? this.id,
      zOrder: zOrder ?? this.zOrder,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      isLocked: isLocked ?? this.isLocked,
      groupId: groupId ?? this.groupId,
      geometryData: geometryData ?? List<double>.from(this.geometryData),
      name: name ?? this.name,
    );
  }
}
