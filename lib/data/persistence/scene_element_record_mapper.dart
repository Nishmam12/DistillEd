// Pure conversion between the in-memory [SceneElement] model and the flat Isar
// [SceneElementRecord]. No Isar runtime dependency, so it is unit-testable
// without the native Isar core.

import '../../domain/model/scene_element.dart';
import 'scene_element_record.dart';

class SceneElementRecordMapper {
  SceneElementRecordMapper._();

  static SceneElementRecord toRecord(
    SceneElement element, {
    required int notebookId,
    required int pageId,
  }) {
    final r = SceneElementRecord()
      ..notebookId = notebookId
      ..pageId = pageId
      ..elementId = element.id
      ..kind = element.kind
      ..zOrder = element.zOrder
      ..rotation = element.rotation
      ..opacity = element.opacity
      ..isLocked = element.isLocked
      ..groupId = element.groupId;

    switch (element) {
      case FreehandElement():
        r.color = element.color;
        r.strokeWidth = element.size;
        r.isEraser = element.isEraser;
        final pts = <double>[];
        final sim = <bool>[];
        final t = <int>[];
        for (final p in element.points) {
          pts..add(p.x)..add(p.y)..add(p.pressure);
          sim.add(p.simulatePressure);
          t.add(p.t ?? -1); // -1 = unknown; see SceneElementRecord.pointT
        }
        r.points = pts;
        r.pointSim = sim;
        r.pointT = t;
      case SceneShapeElement():
        r.shapeType = element.shapeType;
        r.geometryData = List<double>.from(element.geometryData);
        r.color = element.color;
        r.strokeWidth = element.strokeWidth;
        r.hasFill = element.hasFill;
        r.fillColor = element.fillColor;
        r.seed = element.seed;
        r.roughness = element.roughness;
        r.startBindingId = element.startBindingId;
        r.endBindingId = element.endBindingId;
        r.fillStyle = element.fillStyle;
        r.strokeStyle = element.strokeStyle;
        r.edges = element.edges;
        r.startArrowhead = element.startArrowhead;
        r.endArrowhead = element.endArrowhead;
        r.elbowed = element.elbowed;
      case TextElement():
        r.geometryData = List<double>.from(element.geometryData);
        r.text = element.text;
        r.color = element.color;
        r.fontSize = element.fontSize;
        r.fontFamily = element.fontFamily;
        r.isBold = element.isBold;
        r.isItalic = element.isItalic;
        r.textAlign = element.align;
        r.containerId = element.containerId;
      case ImageElement():
        r.geometryData = List<double>.from(element.geometryData);
        r.relativeImagePath = element.relativeImagePath;
        r.sourceDescription = element.sourceDescription;
      case FrameElement():
        r.geometryData = List<double>.from(element.geometryData);
        r.text = element.name; // frame name reuses the text slot
    }
    return r;
  }

  static SceneElement fromRecord(SceneElementRecord r) {
    switch (r.kind) {
      case SceneElementKind.freehand:
        final points = <StrokePoint>[];
        for (int i = 0; i + 2 < r.points.length; i += 3) {
          final idx = i ~/ 3;
          final t = idx < r.pointT.length ? r.pointT[idx] : -1;
          points.add(StrokePoint(
            x: r.points[i],
            y: r.points[i + 1],
            pressure: r.points[i + 2],
            simulatePressure:
                idx < r.pointSim.length ? r.pointSim[idx] : false,
            t: t < 0 ? null : t,
          ));
        }
        return FreehandElement(
          id: r.elementId,
          zOrder: r.zOrder,
          rotation: r.rotation,
          opacity: r.opacity,
          isLocked: r.isLocked,
          groupId: r.groupId,
          points: points,
          color: r.color,
          size: r.strokeWidth,
          isEraser: r.isEraser,
        );
      case SceneElementKind.shape:
        return SceneShapeElement(
          id: r.elementId,
          zOrder: r.zOrder,
          rotation: r.rotation,
          opacity: r.opacity,
          isLocked: r.isLocked,
          groupId: r.groupId,
          shapeType: r.shapeType,
          geometryData: List<double>.from(r.geometryData),
          color: r.color,
          strokeWidth: r.strokeWidth,
          hasFill: r.hasFill,
          fillColor: r.fillColor,
          seed: r.seed,
          roughness: r.roughness,
          startBindingId: r.startBindingId,
          endBindingId: r.endBindingId,
          fillStyle: r.fillStyle,
          strokeStyle: r.strokeStyle,
          edges: r.edges,
          startArrowhead: r.startArrowhead,
          endArrowhead: r.endArrowhead,
          elbowed: r.elbowed,
        );
      case SceneElementKind.text:
        return TextElement(
          id: r.elementId,
          zOrder: r.zOrder,
          rotation: r.rotation,
          opacity: r.opacity,
          isLocked: r.isLocked,
          groupId: r.groupId,
          geometryData: List<double>.from(r.geometryData),
          text: r.text,
          color: r.color,
          fontSize: r.fontSize,
          fontFamily: r.fontFamily,
          isBold: r.isBold,
          isItalic: r.isItalic,
          align: r.textAlign,
          containerId: r.containerId,
        );
      case SceneElementKind.image:
        return ImageElement(
          id: r.elementId,
          zOrder: r.zOrder,
          rotation: r.rotation,
          opacity: r.opacity,
          isLocked: r.isLocked,
          groupId: r.groupId,
          geometryData: List<double>.from(r.geometryData),
          relativeImagePath: r.relativeImagePath,
          sourceDescription: r.sourceDescription,
        );
      case SceneElementKind.frame:
        return FrameElement(
          id: r.elementId,
          zOrder: r.zOrder,
          rotation: r.rotation,
          opacity: r.opacity,
          isLocked: r.isLocked,
          groupId: r.groupId,
          geometryData: List<double>.from(r.geometryData),
          name: r.text,
        );
    }
  }
}
