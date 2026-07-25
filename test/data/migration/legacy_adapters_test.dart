import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/data/migration/legacy_adapters.dart';
import 'package:inkflow/data/migration/legacy_page_data.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/data/migration/legacy_models/imported_content.dart';
import 'package:inkflow/data/migration/legacy_models/shape_element.dart';
import 'package:inkflow/data/migration/legacy_models/stroke.dart';

/// Builds a legacy ShapeElement of [type] with every required field set.
ShapeElement _shape(
  ShapeType type, {
  String id = 's',
  List<double>? geometry,
  int color = 0xFF000000,
  double strokeWidth = 2,
  bool hasFill = false,
  int fillColor = 0,
  double rotation = 0,
  int zOrder = 0,
  int seed = 0,
  double roughness = 0,
  String startBinding = '',
  String endBinding = '',
  String text = '',
  String svg = '',
}) {
  return ShapeElement()
    ..id = id
    ..type = type
    ..color = color
    ..strokeWidth = strokeWidth
    ..hasFill = hasFill
    ..fillColor = fillColor
    ..opacity = 1.0
    ..geometryData = geometry ?? [0, 0, 10, 10]
    ..rotation = rotation
    ..text = text
    ..fontSize = 16
    ..fontFamily = 'Roboto'
    ..isBold = false
    ..isItalic = false
    ..svgRelativePath = svg
    ..zOrder = zOrder
    ..seed = seed
    ..roughness = roughness
    ..startBindingId = startBinding
    ..endBindingId = endBinding;
}

void main() {
  group('.ink stroke parse + adapt fidelity', () {
    test('preserves coords, pressure, per-point sim, opacity defaults', () {
      const json = '''
      [
        {"id":"100","color":4278190080,"size":2.0,"opacity":0.5,"isEraser":false,
         "points":[{"x":1,"y":2,"p":0.3,"sim":true},{"x":3,"y":4,"p":0.7}]},
        {"id":"200","color":4294901760,"size":4.0,"isEraser":true,
         "points":[{"x":0,"y":0}]}
      ]''';
      final strokes = (jsonDecode(json) as List)
          .map((m) => Stroke.fromMap(m as Map<String, dynamic>))
          .toList();

      final a = LegacyAdapters.freehandFromStroke(strokes[0], zOrder: 0);
      expect(a.id, '100');
      expect(a.color, 4278190080);
      expect(a.size, 2.0);
      expect(a.opacity, 0.5);
      expect(a.isEraser, false);
      expect(a.points[0].pressure, 0.3);
      expect(a.points[0].simulatePressure, true);
      expect(a.points[1].pressure, 0.7);
      expect(a.points[1].simulatePressure, false);

      final b = LegacyAdapters.freehandFromStroke(strokes[1], zOrder: 1);
      expect(b.opacity, 1.0); // defaulted when absent
      expect(b.isEraser, true);
      expect(b.points[0].pressure, 0.5); // defaulted when absent
    });
  });

  group('ShapeElement conversion', () {
    test('textBox becomes a TextElement', () {
      final e = LegacyAdapters.fromShapeElement(
          _shape(ShapeType.textBox, id: 't', text: 'hi', geometry: [1, 2, 3, 4]),
          zOrder: 0);
      expect(e, isA<TextElement>());
      expect((e as TextElement).text, 'hi');
      expect(e.geometryData, [1, 2, 3, 4]);
    });

    test('svgImage becomes an ImageElement', () {
      final e = LegacyAdapters.fromShapeElement(
          _shape(ShapeType.svgImage, id: 'v', svg: 'imports/a.svg'),
          zOrder: 0);
      expect(e, isA<ImageElement>());
      expect((e as ImageElement).relativeImagePath, 'imports/a.svg');
    });

    test('geometric shapes keep type/geometry/seed/roughness/bindings', () {
      final arrow = LegacyAdapters.fromShapeElement(
          _shape(ShapeType.arrow,
              id: 'a',
              geometry: [0, 0, 10, 10, 8, 9, 9, 8],
              startBinding: 'x',
              endBinding: 'y',
              seed: 7,
              roughness: 1.1),
          zOrder: 0) as SceneShapeElement;
      expect(arrow.shapeType, ShapeType.arrow);
      expect(arrow.geometryData, [0, 0, 10, 10, 8, 9, 9, 8]);
      expect(arrow.startBindingId, 'x');
      expect(arrow.endBindingId, 'y');
      expect(arrow.seed, 7);
      expect(arrow.roughness, 1.1);

      // diamond (enum index 8) must survive — guards the Isar enum-order contract
      final diamond = LegacyAdapters.fromShapeElement(
          _shape(ShapeType.diamond, id: 'd'), zOrder: 0) as SceneShapeElement;
      expect(diamond.shapeType, ShapeType.diamond);
    });
  });

  group('ImportedContent conversion', () {
    test('freeImage becomes an unlocked image with l,t,r,b bounds', () {
      final c = ImportedContent.freeImage(
        id: 'fi',
        relativeImagePath: 'imports/p.png',
        sourceDescription: 'pic',
        x: 5,
        y: 6,
        width: 20,
        height: 10,
      );
      final e = LegacyAdapters.imageFromImportedContent(c, zOrder: 3);
      expect(e.relativeImagePath, 'imports/p.png');
      expect(e.isLocked, false);
      expect(e.geometryData, [5, 6, 25, 16]);
      expect(e.zOrder, 3);
    });

    test('pdfBackground becomes a locked image at the back', () {
      final c = ImportedContent.pdfBackground(
        id: 'pb',
        relativeImagePath: 'imports/bg.png',
        sourceDescription: 'doc.pdf — p1',
      );
      final e = LegacyAdapters.imageFromImportedContent(c, zOrder: 0);
      expect(e.isLocked, true);
      expect(e.relativeImagePath, 'imports/bg.png');
      expect(e.sourceDescription, 'doc.pdf — p1');
    });
  });

  group('pageToSceneElements z-order fidelity', () {
    test('imported sits at back; strokes+shapes interleave by render key', () {
      final page = LegacyPageData(
        notebookId: 1,
        pageId: 1,
        imported: [
          ImportedContent.pdfBackground(
              id: 'pdf', relativeImagePath: 'bg.png', sourceDescription: ''),
          ImportedContent.freeImage(
              id: 'img',
              relativeImagePath: 'p.png',
              sourceDescription: '',
              x: 10,
              y: 10,
              width: 30,
              height: 20),
        ],
        strokes: [
          const Stroke(id: '100', color: 0xFF000000, size: 2, points: []),
          const Stroke(id: '300', color: 0xFF000000, size: 2, points: []),
        ],
        shapes: [
          _shape(ShapeType.rectangle, id: 'rect', zOrder: 0),
          _shape(ShapeType.circle, id: 'circ', zOrder: 1),
        ],
      );

      final out = LegacyAdapters.pageToSceneElements(page);
      expect(out.map((e) => e.id).toList(),
          ['pdf', 'img', 'rect', '100', '300', 'circ']);
      // zOrder is sequential 0..N matching list order
      for (var i = 0; i < out.length; i++) {
        expect(out[i].zOrder, i);
      }
      expect(out[0], isA<ImageElement>());
      expect((out[0] as ImageElement).isLocked, true); // pdf background
      expect(out[3], isA<FreehandElement>());
      expect(out[5], isA<SceneShapeElement>());
    });
  });
}
