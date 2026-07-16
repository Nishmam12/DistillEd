// JSON (de)serialisation for [SceneElement]s, independent of Isar.
//
// Used wherever scene elements travel outside the page database: the element
// library (a JSON file) and the system clipboard (copy/paste). Enums are stored
// by `.name` so the format stays readable and resilient to index reordering.

import '../../domain/model/scene_element.dart';

class SceneElementCodec {
  SceneElementCodec._();

  static List<Map<String, dynamic>> encodeList(Iterable<SceneElement> els) =>
      [for (final e in els) encode(e)];

  static List<SceneElement> decodeList(Iterable<dynamic> json) => [
        for (final m in json) decode(Map<String, dynamic>.from(m as Map)),
      ];

  static Map<String, dynamic> encode(SceneElement e) {
    final base = <String, dynamic>{
      'id': e.id,
      'kind': e.kind.name,
      'zOrder': e.zOrder,
      'rotation': e.rotation,
      'opacity': e.opacity,
      'isLocked': e.isLocked,
      'groupId': e.groupId,
    };
    switch (e) {
      case FreehandElement():
        base.addAll({
          'points': [
            for (final p in e.points) ...[p.x, p.y, p.pressure],
          ],
          'pointSim': [for (final p in e.points) p.simulatePressure],
          // Capture timestamps (ms); -1 = unknown. Absent in JSON written
          // before this key existed — both decode to t=null.
          'pointT': [for (final p in e.points) p.t ?? -1],
          'color': e.color,
          'size': e.size,
          'isEraser': e.isEraser,
        });
      case SceneShapeElement():
        base.addAll({
          'shapeType': e.shapeType.name,
          'geometryData': e.geometryData,
          'color': e.color,
          'strokeWidth': e.strokeWidth,
          'hasFill': e.hasFill,
          'fillColor': e.fillColor,
          'seed': e.seed,
          'roughness': e.roughness,
          'startBindingId': e.startBindingId,
          'endBindingId': e.endBindingId,
          'fillStyle': e.fillStyle.name,
          'strokeStyle': e.strokeStyle.name,
          'edges': e.edges.name,
          'startArrowhead': e.startArrowhead.name,
          'endArrowhead': e.endArrowhead.name,
          'elbowed': e.elbowed,
        });
      case TextElement():
        base.addAll({
          'geometryData': e.geometryData,
          'text': e.text,
          'color': e.color,
          'fontSize': e.fontSize,
          'fontFamily': e.fontFamily,
          'isBold': e.isBold,
          'isItalic': e.isItalic,
          'align': e.align.name,
          'containerId': e.containerId,
        });
      case ImageElement():
        base.addAll({
          'geometryData': e.geometryData,
          'relativeImagePath': e.relativeImagePath,
          'sourceDescription': e.sourceDescription,
        });
      case FrameElement():
        base.addAll({
          'geometryData': e.geometryData,
          'name': e.name,
        });
    }
    return base;
  }

  static SceneElement decode(Map<String, dynamic> m) {
    final kind = _enumByName(SceneElementKind.values, m['kind'] as String?,
        SceneElementKind.freehand);
    final id = m['id'] as String;
    final zOrder = (m['zOrder'] as num).toInt();
    final rotation = _d(m['rotation']);
    final opacity = _d(m['opacity'], 1.0);
    final isLocked = m['isLocked'] as bool? ?? false;
    final groupId = m['groupId'] as String? ?? '';
    final geometry = _doubles(m['geometryData']);

    switch (kind) {
      case SceneElementKind.freehand:
        return FreehandElement(
          id: id,
          zOrder: zOrder,
          rotation: rotation,
          opacity: opacity,
          isLocked: isLocked,
          groupId: groupId,
          points: _points(m['points'], m['pointSim'], m['pointT']),
          color: (m['color'] as num).toInt(),
          size: _d(m['size'], 1.0),
          isEraser: m['isEraser'] as bool? ?? false,
        );
      case SceneElementKind.shape:
        return SceneShapeElement(
          id: id,
          zOrder: zOrder,
          rotation: rotation,
          opacity: opacity,
          isLocked: isLocked,
          groupId: groupId,
          shapeType:
              _enumByName(ShapeType.values, m['shapeType'] as String?, ShapeType.rectangle),
          geometryData: geometry,
          color: (m['color'] as num).toInt(),
          strokeWidth: _d(m['strokeWidth'], 1.0),
          hasFill: m['hasFill'] as bool? ?? false,
          fillColor: (m['fillColor'] as num?)?.toInt() ?? 0,
          seed: (m['seed'] as num?)?.toInt() ?? 0,
          roughness: _d(m['roughness']),
          startBindingId: m['startBindingId'] as String? ?? '',
          endBindingId: m['endBindingId'] as String? ?? '',
          fillStyle: _enumByName(FillStyle.values, m['fillStyle'] as String?, FillStyle.hachure),
          strokeStyle:
              _enumByName(StrokeStyle.values, m['strokeStyle'] as String?, StrokeStyle.solid),
          edges: _enumByName(EdgeStyle.values, m['edges'] as String?, EdgeStyle.sharp),
          startArrowhead:
              _enumByName(Arrowhead.values, m['startArrowhead'] as String?, Arrowhead.none),
          endArrowhead:
              _enumByName(Arrowhead.values, m['endArrowhead'] as String?, Arrowhead.triangle),
          elbowed: m['elbowed'] as bool? ?? false,
        );
      case SceneElementKind.text:
        return TextElement(
          id: id,
          zOrder: zOrder,
          rotation: rotation,
          opacity: opacity,
          isLocked: isLocked,
          groupId: groupId,
          geometryData: geometry,
          text: m['text'] as String? ?? '',
          color: (m['color'] as num).toInt(),
          fontSize: _d(m['fontSize'], 16.0),
          fontFamily: m['fontFamily'] as String? ?? 'Roboto',
          isBold: m['isBold'] as bool? ?? false,
          isItalic: m['isItalic'] as bool? ?? false,
          align: _enumByName(TextAlignKind.values, m['align'] as String?, TextAlignKind.left),
          containerId: m['containerId'] as String? ?? '',
        );
      case SceneElementKind.image:
        return ImageElement(
          id: id,
          zOrder: zOrder,
          rotation: rotation,
          opacity: opacity,
          isLocked: isLocked,
          groupId: groupId,
          geometryData: geometry,
          relativeImagePath: m['relativeImagePath'] as String? ?? '',
          sourceDescription: m['sourceDescription'] as String? ?? '',
        );
      case SceneElementKind.frame:
        return FrameElement(
          id: id,
          zOrder: zOrder,
          rotation: rotation,
          opacity: opacity,
          isLocked: isLocked,
          groupId: groupId,
          geometryData: geometry,
          name: m['name'] as String? ?? 'Frame',
        );
    }
  }

  static List<StrokePoint> _points(dynamic flat, dynamic sim, dynamic tRaw) {
    final p = _doubles(flat);
    final s = (sim is List) ? sim.map((e) => e == true).toList() : const <bool>[];
    final t = (tRaw is List)
        ? [for (final e in tRaw) (e is num) ? e.toInt() : -1]
        : const <int>[];
    final out = <StrokePoint>[];
    for (int i = 0; i + 2 < p.length; i += 3) {
      final idx = i ~/ 3;
      final tv = idx < t.length ? t[idx] : -1;
      out.add(StrokePoint(
        x: p[i],
        y: p[i + 1],
        pressure: p[i + 2],
        simulatePressure: idx < s.length ? s[idx] : false,
        t: tv < 0 ? null : tv,
      ));
    }
    return out;
  }

  static List<double> _doubles(dynamic v) =>
      v is List ? [for (final e in v) (e as num).toDouble()] : <double>[];

  static double _d(dynamic v, [double fallback = 0.0]) =>
      v is num ? v.toDouble() : fallback;

  static T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
