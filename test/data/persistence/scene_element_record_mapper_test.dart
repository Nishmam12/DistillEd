import 'package:flutter_test/flutter_test.dart';
import 'package:margo/data/persistence/scene_element_record_mapper.dart';
import 'package:margo/domain/model/scene_element.dart';

void main() {
  group('SceneElementRecordMapper round-trips', () {
    test('link survives, and a fresh record reads as no link', () {
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
        link: 'notebook:3',
      );
      for (final e in [f, t]) {
        final r =
            SceneElementRecordMapper.toRecord(e, notebookId: 1, pageId: 2);
        expect(r.linkTarget, e.link);
        expect(SceneElementRecordMapper.fromRecord(r).link, e.link);
      }
      final plain = SceneElementRecordMapper.toRecord(
          const FrameElement(id: 'x', zOrder: 0, geometryData: [0, 0, 1, 1]),
          notebookId: 1,
          pageId: 2);
      expect(SceneElementRecordMapper.fromRecord(plain).link, '');
    });

    test('freehand preserves points, pressure and per-point sim', () {
      const e = FreehandElement(
        id: 'f1',
        zOrder: 5,
        color: 0xFF112233,
        size: 3.5,
        opacity: 0.8,
        isEraser: true,
        points: [
          StrokePoint(x: 1, y: 2, pressure: 0.4, simulatePressure: true),
          StrokePoint(x: 3, y: 4, pressure: 0.9),
        ],
      );

      final record =
          SceneElementRecordMapper.toRecord(e, notebookId: 7, pageId: 11);
      expect(record.kind, SceneElementKind.freehand);
      expect(record.pageId, 11);
      expect(record.notebookId, 7);

      final back = SceneElementRecordMapper.fromRecord(record);
      expect(back, isA<FreehandElement>());
      final f = back as FreehandElement;
      expect(f.id, 'f1');
      expect(f.zOrder, 5);
      expect(f.color, 0xFF112233);
      expect(f.size, 3.5);
      expect(f.opacity, 0.8);
      expect(f.isEraser, true);
      expect(f.points.length, 2);
      expect(f.points[0].x, 1);
      expect(f.points[0].y, 2);
      expect(f.points[0].pressure, 0.4);
      expect(f.points[0].simulatePressure, true);
      expect(f.points[1].pressure, 0.9);
      expect(f.points[1].simulatePressure, false);
    });

    test('freehand keeps which pen drew it', () {
      for (final kind in PenKind.values) {
        final e = FreehandElement(
          id: 'p',
          zOrder: 0,
          color: 0xFF000000,
          size: 4,
          penKind: kind,
          points: const [StrokePoint(x: 0, y: 0), StrokePoint(x: 5, y: 5)],
        );
        final back = SceneElementRecordMapper.fromRecord(
                SceneElementRecordMapper.toRecord(e, notebookId: 1, pageId: 1))
            as FreehandElement;
        expect(back.penKind, kind);
      }
    });

    test('a stroke stored before pen types existed reads back as ballpoint', () {
      const e = FreehandElement(
        id: 'old',
        zOrder: 0,
        color: 0xFF000000,
        size: 4,
        points: [StrokePoint(x: 0, y: 0)],
      );
      final record =
          SceneElementRecordMapper.toRecord(e, notebookId: 1, pageId: 1);
      expect(record.penKind, PenKind.ballpoint);
    });

    test('freehand preserves per-point capture timestamps (t), mixed with null',
        () {
      const e = FreehandElement(
        id: 'f2',
        zOrder: 0,
        color: 0xFF000000,
        size: 2,
        points: [
          StrokePoint(x: 0, y: 0, t: 1000),
          StrokePoint(x: 1, y: 1, t: 1016),
          StrokePoint(x: 2, y: 2), // no timestamp (legacy / synthesized later)
        ],
      );

      final record =
          SceneElementRecordMapper.toRecord(e, notebookId: 1, pageId: 1);
      // -1 encodes "unknown" in the flat record.
      expect(record.pointT, [1000, 1016, -1]);

      final back = SceneElementRecordMapper.fromRecord(record) as FreehandElement;
      expect(back.points[0].t, 1000);
      expect(back.points[1].t, 1016);
      expect(back.points[2].t, isNull);
    });

    test('freehand rows written before pointT existed decode with t = null', () {
      const e = FreehandElement(
        id: 'f3',
        zOrder: 0,
        color: 0xFF000000,
        size: 2,
        points: [StrokePoint(x: 0, y: 0, t: 999)],
      );
      final record =
          SceneElementRecordMapper.toRecord(e, notebookId: 1, pageId: 1)
            ..pointT = const []; // simulate a pre-migration row
      final back = SceneElementRecordMapper.fromRecord(record) as FreehandElement;
      expect(back.points.single.t, isNull);
    });

    test('shape preserves geometry, seed, roughness and bindings', () {
      const e = SceneShapeElement(
        id: 's1',
        zOrder: 2,
        rotation: 0.5,
        shapeType: ShapeType.diamond,
        geometryData: [0, 0, 10, 0, 10, 10, 0, 10],
        color: 0xFF445566,
        strokeWidth: 2,
        hasFill: true,
        fillColor: 0xFF778899,
        seed: 99,
        roughness: 1.2,
        startBindingId: 'a',
        endBindingId: 'b',
      );

      final back = SceneElementRecordMapper.fromRecord(
          SceneElementRecordMapper.toRecord(e, notebookId: 1, pageId: 1));
      final s = back as SceneShapeElement;
      expect(s.shapeType, ShapeType.diamond);
      expect(s.geometryData, [0, 0, 10, 0, 10, 10, 0, 10]);
      expect(s.rotation, 0.5);
      expect(s.hasFill, true);
      expect(s.fillColor, 0xFF778899);
      expect(s.seed, 99);
      expect(s.roughness, 1.2);
      expect(s.startBindingId, 'a');
      expect(s.endBindingId, 'b');
    });

    test('text and image survive the round-trip', () {
      const t = TextElement(
        id: 't1',
        zOrder: 1,
        geometryData: [5, 5, 105, 45],
        text: 'hello',
        color: 0xFF000000,
        fontSize: 20,
        fontFamily: 'Roboto',
        isBold: true,
      );
      const i = ImageElement(
        id: 'i1',
        zOrder: 0,
        geometryData: [0, 0, 100, 100],
        relativeImagePath: 'imports/x.png',
        sourceDescription: 'doc.pdf — p1',
        isLocked: true,
      );

      final tBack = SceneElementRecordMapper.fromRecord(
          SceneElementRecordMapper.toRecord(t, notebookId: 1, pageId: 1))
          as TextElement;
      expect(tBack.text, 'hello');
      expect(tBack.fontSize, 20);
      expect(tBack.isBold, true);
      expect(tBack.geometryData, [5, 5, 105, 45]);

      final iBack = SceneElementRecordMapper.fromRecord(
          SceneElementRecordMapper.toRecord(i, notebookId: 1, pageId: 1))
          as ImageElement;
      expect(iBack.relativeImagePath, 'imports/x.png');
      expect(iBack.sourceDescription, 'doc.pdf — p1');
      expect(iBack.isLocked, true);
      expect(iBack.geometryData, [0, 0, 100, 100]);
    });

    test('frame preserves name and bounds', () {
      const f = FrameElement(
        id: 'fr1',
        zOrder: 3,
        geometryData: [10, 20, 110, 220],
        name: 'Diagram',
      );

      final record =
          SceneElementRecordMapper.toRecord(f, notebookId: 1, pageId: 1);
      expect(record.kind, SceneElementKind.frame);

      final back =
          SceneElementRecordMapper.fromRecord(record) as FrameElement;
      expect(back.id, 'fr1');
      expect(back.zOrder, 3);
      expect(back.name, 'Diagram');
      expect(back.geometryData, [10, 20, 110, 220]);
    });

    test('tape keeps its place, colour and whether it is lifted', () {
      for (final revealed in [false, true]) {
        final t = TapeElement(
          id: 'tp',
          zOrder: 4,
          geometryData: const [5, 6, 205, 30],
          color: 0xFF8FB8DE,
          revealed: revealed,
          isLocked: true,
        );
        final record =
            SceneElementRecordMapper.toRecord(t, notebookId: 1, pageId: 1);
        expect(record.kind, SceneElementKind.tape);
        expect(record.tapeRevealed, revealed);

        final back =
            SceneElementRecordMapper.fromRecord(record) as TapeElement;
        expect(back.geometryData, [5, 6, 205, 30]);
        expect(back.color, 0xFF8FB8DE);
        expect(back.revealed, revealed);
        expect(back.isLocked, isTrue);
      }
    });

    test('a row from before tape has the column unset, read as covered', () {
      // What a record written by an older build looks like for every other
      // kind: the new column at its default.
      final r = SceneElementRecordMapper.toRecord(
          const FrameElement(id: 'f', zOrder: 0, geometryData: [0, 0, 1, 1]),
          notebookId: 1,
          pageId: 1);
      expect(r.tapeRevealed, isFalse);
    });
  });
}
