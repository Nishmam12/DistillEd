// Unified on-disk representation of a scene element (InkFlow 2.0).
//
// One Isar row per element, indexed by [pageId], replacing the legacy split
// storage (per-page `.ink` JSON + embedded NotePage.shapes/importedContents).
// Per-row storage enables incremental autosave (write only changed elements).
//
// This is a *superset* schema: each row carries only the fields relevant to its
// [kind]; the rest stay at their defaults. Conversion to/from the in-memory
// [SceneElement] model lives in `data/migration/legacy_adapters.dart`.

import 'package:isar/isar.dart';

import '../../domain/model/scene_element.dart';

part 'scene_element_record.g.dart';

@collection
class SceneElementRecord {
  Id id = Isar.autoIncrement; // Isar row id (not the element id)

  @Index()
  late int pageId; // FK → NotePage.id

  @Index()
  late int notebookId;

  /// Stable element id (preserved from the legacy Stroke/Shape/Import id).
  late String elementId;

  @enumerated
  late SceneElementKind kind;

  late int zOrder;
  double rotation = 0.0;
  double opacity = 1.0;
  bool isLocked = false;
  String groupId = '';

  // Stroke/shape colour (ARGB) and width/size (freehand reuses these).
  int color = 0xFF000000;
  double strokeWidth = 1.0;

  // --- freehand only ---
  List<double> points = const []; // [x, y, pressure, ...]
  List<bool> pointSim = const []; // per-point simulatePressure
  // Per-point capture timestamp in ms (StrokePoint.t); -1 encodes "unknown".
  // Empty for rows written before this field existed — both decode to t=null,
  // and handwriting recognition synthesizes timing for those strokes.
  List<int> pointT = const [];
  bool isEraser = false;

  /// Lecture-recording link (Tier 4.12). Null on strokes drawn with no
  /// recording running, and on every row written before these fields existed.
  int? recordingId;
  int? audioOffsetMs;

  // --- shape only ---
  @enumerated
  ShapeType shapeType = ShapeType.rectangle; // ignored unless kind == shape
  List<double> geometryData = const [];
  bool hasFill = false;
  int fillColor = 0;
  int seed = 0;
  double roughness = 0.0;
  String startBindingId = '';
  String endBindingId = '';
  @enumerated
  FillStyle fillStyle = FillStyle.hachure;
  @enumerated
  StrokeStyle strokeStyle = StrokeStyle.solid;
  @enumerated
  EdgeStyle edges = EdgeStyle.sharp;
  @enumerated
  Arrowhead startArrowhead = Arrowhead.none;
  @enumerated
  Arrowhead endArrowhead = Arrowhead.triangle;
  bool elbowed = false;

  // --- text only ---
  String text = '';
  double fontSize = 16.0;
  String fontFamily = 'Roboto';
  bool isBold = false;
  bool isItalic = false;
  @enumerated
  TextAlignKind textAlign = TextAlignKind.left;
  String containerId = '';

  // --- image only ---
  String relativeImagePath = '';
  String sourceDescription = '';
}

/// Single-row collection gating one-time data migrations.
@collection
class AppMeta {
  Id id = 0; // singleton row
  int schemaVersion = 0;
}
