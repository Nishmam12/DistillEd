import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/data/persistence/scene_element_codec.dart';
import 'package:margo/domain/model/scene_element.dart';

void main() {
  test('every element kind survives a JSON encode/decode round-trip', () {
    final elements = <SceneElement>[
      const FreehandElement(
        id: 'f',
        zOrder: 0,
        color: 0xFF112233,
        size: 2.5,
        opacity: 0.6,
        isEraser: true,
        points: [
          StrokePoint(x: 1, y: 2, pressure: 0.4, simulatePressure: true, t: 500),
          StrokePoint(x: 3, y: 4, pressure: 0.9),
        ],
      ),
      const SceneShapeElement(
        id: 's',
        zOrder: 1,
        rotation: 0.3,
        shapeType: ShapeType.diamond,
        geometryData: [0, 0, 10, 0, 10, 10, 0, 10],
        color: 0xFF445566,
        strokeWidth: 3,
        hasFill: true,
        fillColor: 0xFF778899,
        seed: 42,
        roughness: 1.5,
        fillStyle: FillStyle.crossHatch,
        strokeStyle: StrokeStyle.dashed,
        edges: EdgeStyle.round,
        startArrowhead: Arrowhead.dot,
        endArrowhead: Arrowhead.bar,
        elbowed: true,
        groupId: 'g1',
      ),
      const TextElement(
        id: 't',
        zOrder: 2,
        geometryData: [5, 5, 105, 45],
        text: 'hi <there> & "you"',
        color: 0xFF000000,
        fontSize: 18,
        isBold: true,
        align: TextAlignKind.center,
      ),
      const ImageElement(
        id: 'i',
        zOrder: 3,
        geometryData: [0, 0, 50, 50],
        relativeImagePath: 'notes/1/imports/x.png',
        sourceDescription: 'desc',
        isLocked: true,
      ),
      const FrameElement(
        id: 'fr',
        zOrder: 4,
        geometryData: [10, 10, 200, 200],
        name: 'My frame',
      ),
    ];

    // Round-trip through real JSON text, not just the maps.
    final json = jsonEncode(SceneElementCodec.encodeList(elements));
    final back = SceneElementCodec.decodeList(jsonDecode(json) as List);

    expect(back.length, elements.length);
    expect(back.map((e) => e.kind), elements.map((e) => e.kind));

    final f = back[0] as FreehandElement;
    expect(f.color, 0xFF112233);
    expect(f.isEraser, true);
    expect(f.points.length, 2);
    expect(f.points[0].simulatePressure, true);
    expect(f.points[0].t, 500); // capture timestamp survives
    expect(f.points[1].pressure, 0.9);
    expect(f.points[1].t, isNull); // absent timestamp stays null

    final s = back[1] as SceneShapeElement;
    expect(s.shapeType, ShapeType.diamond);
    expect(s.fillStyle, FillStyle.crossHatch);
    expect(s.strokeStyle, StrokeStyle.dashed);
    expect(s.edges, EdgeStyle.round);
    expect(s.startArrowhead, Arrowhead.dot);
    expect(s.endArrowhead, Arrowhead.bar);
    expect(s.elbowed, true);
    expect(s.groupId, 'g1');
    expect(s.rotation, 0.3);

    final t = back[2] as TextElement;
    expect(t.text, 'hi <there> & "you"');
    expect(t.align, TextAlignKind.center);
    expect(t.isBold, true);

    final i = back[3] as ImageElement;
    expect(i.relativeImagePath, 'notes/1/imports/x.png');
    expect(i.isLocked, true);

    final fr = back[4] as FrameElement;
    expect(fr.name, 'My frame');
    expect(fr.geometryData, [10, 10, 200, 200]);
  });

  test('freehand JSON written before pointT existed decodes with t = null', () {
    final el = SceneElementCodec.decode({
      'id': 'legacy',
      'kind': 'freehand',
      'zOrder': 0,
      'points': [1.0, 2.0, 0.5, 3.0, 4.0, 0.5], // two points, no pointT key
      'pointSim': [false, false],
      'color': 0xFF000000,
      'size': 2.0,
    });
    final f = el as FreehandElement;
    expect(f.points.length, 2);
    expect(f.points[0].t, isNull);
    expect(f.points[1].t, isNull);
  });

  test('the pen type survives JSON, and old JSON reads as ballpoint', () {
    const e = FreehandElement(
      id: 'h',
      zOrder: 0,
      color: 0xFFFFE066,
      size: 16,
      penKind: PenKind.highlighter,
      points: [StrokePoint(x: 0, y: 0), StrokePoint(x: 9, y: 0)],
    );
    final back = SceneElementCodec.decode(SceneElementCodec.encode(e))
        as FreehandElement;
    expect(back.penKind, PenKind.highlighter);

    final old = SceneElementCodec.decode({
      'id': 'legacy',
      'kind': 'freehand',
      'zOrder': 0,
      'points': [1.0, 2.0, 0.5],
      'pointSim': [false],
      'color': 0xFF000000,
      'size': 2.0,
    }) as FreehandElement;
    expect(old.penKind, PenKind.ballpoint);

    final unknown = SceneElementCodec.decode({
      'id': 'future',
      'kind': 'freehand',
      'zOrder': 0,
      'points': [1.0, 2.0, 0.5],
      'pointSim': [false],
      'color': 0xFF000000,
      'size': 2.0,
      'penKind': 'crayon',
    }) as FreehandElement;
    expect(unknown.penKind, PenKind.ballpoint,
        reason: 'a pen this build does not know draws as a plain pen');
  });

  test('tape survives the backup JSON, lifted or not', () {
    for (final revealed in [false, true]) {
      final t = TapeElement(
        id: 't',
        zOrder: 2,
        geometryData: const [0, 0, 100, 24],
        color: 0xFFE8A0A0,
        revealed: revealed,
      );
      final back = SceneElementCodec.decode(
              jsonDecode(jsonEncode(SceneElementCodec.encode(t)))
                  as Map<String, dynamic>)
          as TapeElement;
      expect(back.revealed, revealed);
      expect(back.color, 0xFFE8A0A0);
      expect(back.geometryData, [0, 0, 100, 24]);
    }
  });

  test('tape JSON missing colour and lifted reads as default, covered', () {
    final back = SceneElementCodec.decode({
      'id': 't',
      'kind': 'tape',
      'zOrder': 0,
      'geometryData': [0, 0, 10, 10],
    }) as TapeElement;
    expect(back.color, kDefaultTapeColor);
    expect(back.revealed, isFalse);
  });

  test('decode tolerates missing optional fields with defaults', () {
    final el = SceneElementCodec.decode({
      'id': 'x',
      'kind': 'shape',
      'zOrder': 0,
      'shapeType': 'rectangle',
      'geometryData': [0, 0, 10, 10],
      'color': 0xFF000000,
    });
    final s = el as SceneShapeElement;
    expect(s.strokeWidth, 1.0);
    expect(s.fillStyle, FillStyle.hachure);
    expect(s.opacity, 1.0);
  });

  test('an element link survives JSON, and old JSON reads as no link', () {
    const f = FreehandElement(
      id: 'f',
      zOrder: 0,
      color: 0xFF000000,
      size: 2,
      link: 'page:12',
      points: [StrokePoint(x: 0, y: 0), StrokePoint(x: 9, y: 0)],
    );
    const t = TextElement(
      id: 't',
      zOrder: 1,
      geometryData: [0, 0, 10, 10],
      text: 'x',
      color: 0xFF000000,
      fontSize: 18,
      link: 'url:https://example.com',
    );
    final back = SceneElementCodec.decodeList(
        jsonDecode(jsonEncode(SceneElementCodec.encodeList([f, t]))) as List);
    expect(back[0].link, 'page:12');
    expect(back[1].link, 'url:https://example.com');

    final old = SceneElementCodec.decode({
      'id': 'legacy',
      'kind': 'freehand',
      'zOrder': 0,
      'points': [1.0, 2.0, 0.5],
      'color': 0xFF000000,
      'size': 2.0,
    });
    expect(old.link, '');
  });
}
