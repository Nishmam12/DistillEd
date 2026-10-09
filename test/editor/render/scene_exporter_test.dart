import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/model/scene_element.dart';
import 'package:distill_ed/editor/render/scene_exporter.dart';

const _scene = <SceneElement>[
  SceneShapeElement(
    id: 'r',
    zOrder: 0,
    shapeType: ShapeType.rectangle,
    geometryData: [0, 0, 100, 100],
    color: 0xFF112233,
    strokeWidth: 2,
  ),
  TextElement(
    id: 't',
    zOrder: 1,
    geometryData: [10, 10, 90, 30],
    text: 'Hi',
    color: 0xFF000000,
    fontSize: 16,
  ),
  FreehandElement(
    id: 'f',
    zOrder: 2,
    color: 0xFF000000,
    size: 3,
    points: [
      StrokePoint(x: 5, y: 5, pressure: 0.5),
      StrokePoint(x: 25, y: 25, pressure: 0.5),
      StrokePoint(x: 45, y: 5, pressure: 0.5),
    ],
  ),
  FrameElement(
    id: 'fr',
    zOrder: 3,
    geometryData: [0, 0, 120, 120],
    name: 'Sketch',
  ),
];

void main() {
  test('contentBounds is the padded union, null when empty', () {
    expect(SceneExporter.contentBounds(const []), isNull);
    final b = SceneExporter.contentBounds(_scene, padding: 10)!;
    expect(b.left, -10);
    expect(b.top, -10);
    expect(b.right, 130); // frame extends to 120 + 10
    expect(b.bottom, 130);
  });

  test('toSvg emits a vector element per scene element', () {
    final svg = SceneExporter.toSvg(_scene);
    expect(svg, contains('<svg'));
    expect(svg, contains('viewBox='));
    expect(svg, contains('<rect')); // rectangle + frame
    expect(svg, contains('<text')); // text + frame label
    expect(svg, contains('Hi'));
    expect(svg, contains('Sketch'));
    expect(svg, contains('<polyline')); // freehand
    expect(svg, contains('#112233')); // stroke colour preserved
  });

  test('toSvg escapes XML-special characters in text', () {
    const els = [
      TextElement(
        id: 't',
        zOrder: 0,
        geometryData: [0, 0, 100, 20],
        text: 'a < b & "c"',
        color: 0xFF000000,
        fontSize: 12,
      ),
    ];
    final svg = SceneExporter.toSvg(els);
    expect(svg, contains('a &lt; b &amp; &quot;c&quot;'));
    expect(svg, isNot(contains('a < b &')));
  });

  testWidgets('toPng produces PNG bytes; toPdf produces a PDF', (tester) async {
    await tester.runAsync(() async {
      final png = await SceneExporter.toPng(_scene, scale: 1);
      expect(png, isNotNull);
      // PNG magic number.
      expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);

      final pdf = await SceneExporter.toPdf(_scene, scale: 1);
      expect(pdf, isNotNull);
      // "%PDF" header.
      expect(String.fromCharCodes(pdf!.sublist(0, 4)), '%PDF');
    });
  });

  group('toPng maxSide — size an image to what the model will use', () {
    // PNG stores width and height as big-endian 32-bit ints right after the
    // 8-byte signature and the IHDR chunk header: bytes 16–19 and 20–23.
    ({int w, int h}) size(Uint8List png) {
      final data = ByteData.sublistView(png);
      return (w: data.getUint32(16), h: data.getUint32(20));
    }

    const wide = <SceneElement>[
      FreehandElement(
        id: 'w',
        zOrder: 0,
        color: 0xFF000000,
        size: 3,
        points: [
          StrokePoint(x: 0, y: 0, pressure: 0.5),
          StrokePoint(x: 2000, y: 500, pressure: 0.5),
        ],
      ),
    ];

    testWidgets('a large scene is shrunk so its longer side fits', (tester) async {
      await tester.runAsync(() async {
        // 2000x500 of ink plus 24 padding a side is 2048x548 scene units, which
        // at the default 2x is 4096x1096 pixels — far more than the vision model
        // keeps, and all of it rendered, encoded, handed over and decoded.
        final full = size((await SceneExporter.toPng(wide))!);
        expect(full.w, 4096);

        final capped = size((await SceneExporter.toPng(wide, maxSide: 1024))!);
        expect(capped.w, lessThanOrEqualTo(1024));
        expect(capped.w, greaterThan(1000), reason: 'as big as the cap allows');
        // The shape is unchanged: 4096:1096 is 1024:274.
        expect(capped.h, closeTo(capped.w * full.h / full.w, 2));
      });
    });

    testWidgets('a small scene is never enlarged to reach the cap',
        (tester) async {
      await tester.runAsync(() async {
        final plain = size((await SceneExporter.toPng(_scene))!);
        final capped = size((await SceneExporter.toPng(_scene, maxSide: 4096))!);

        expect(capped, plain);
      });
    });

    testWidgets('without a cap nothing changes', (tester) async {
      await tester.runAsync(() async {
        final a = (await SceneExporter.toPng(_scene))!;
        final b = (await SceneExporter.toPng(_scene, maxSide: null))!;
        expect(size(a), size(b));
      });
    });
  });

  testWidgets('export of an empty scene returns null', (tester) async {
    await tester.runAsync(() async {
      expect(await SceneExporter.toPng(const []), isNull);
      expect(await SceneExporter.toPdf(const []), isNull);
    });
  });

  testWidgets('toPng renders a real bitmap when a resolver is supplied',
      (tester) async {
    await tester.runAsync(() async {
      // A real engine image via the supported picture.toImage path.
      final rec = PictureRecorder();
      Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 8, 8),
          Paint()..color = const Color(0xFF00FF00));
      final bitmap = await rec.endRecording().toImage(8, 8);

      const els = [
        ImageElement(
          id: 'i',
          zOrder: 0,
          geometryData: [0, 0, 50, 50],
          relativeImagePath: 'pic.png',
        ),
      ];
      final png = await SceneExporter.toPng(els,
          scale: 1, imageResolver: (p) => p == 'pic.png' ? bitmap : null);
      expect(png, isNotNull);
      expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      bitmap.dispose();
    });
  });


  test('an element at infinity exports without throwing or writing Infinity',
      () {
    final broken = [
      const SceneShapeElement(
        id: 'inf',
        zOrder: 0,
        shapeType: ShapeType.rectangle,
        geometryData: [0, 0, double.infinity, 10],
        color: 0xFF000000,
        strokeWidth: 1,
      ),
    ];

    final svg = SceneExporter.toSvg(broken);

    expect(svg, isNot(contains('Infinity')));
    expect(svg, isNot(contains('NaN')));
  });


  group('pictures in an SVG', () {
    const picture = ImageElement(
      id: 'pic',
      zOrder: 0,
      geometryData: [0, 0, 40, 30],
      relativeImagePath: 'notes/1/imports/img_a.png',
    );
    final png = Uint8List.fromList(
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);

    test('a picture is embedded from its bytes, not linked by its file path',
        () {
      final svg = SceneExporter.toSvg(
        [picture],
        images: {picture.relativeImagePath: png},
      );

      expect(svg, contains('xlink:href="data:image/png;base64,'));
      expect(svg, isNot(contains('img_a.png')));
      expect(svg, contains('xmlns:xlink="http://www.w3.org/1999/xlink"'));
    });

    test('a picture with no bytes is drawn as the placeholder, not a broken link',
        () {
      final svg = SceneExporter.toSvg([picture]);

      expect(svg, isNot(contains('<image')));
      expect(svg, isNot(contains('img_a.png')));
      expect(svg, contains('stroke="#8A93A6"'));
    });

    test('bytes that are not a picture type are never embedded under a made-up one',
        () {
      final svg = SceneExporter.toSvg(
        [picture],
        images: {
          picture.relativeImagePath: Uint8List.fromList([1, 2, 3, 4]),
        },
      );

      expect(svg, isNot(contains('<image')));
      expect(svg, isNot(contains('data:')));
    });

    test('the picture type is read from the first bytes', () {
      expect(SceneExporter.imageMimeType(png), 'image/png');
      expect(
        SceneExporter.imageMimeType(
            Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
        'image/jpeg',
      );
      // RIFF, a size, then WEBP.
      expect(
        SceneExporter.imageMimeType(Uint8List.fromList(
            [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50])),
        'image/webp',
      );
      // RIFF, a size, then WAVE: a sound file, not a picture.
      expect(
        SceneExporter.imageMimeType(Uint8List.fromList(
            [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45])),
        isNull,
      );
      expect(SceneExporter.imageMimeType(Uint8List(0)), isNull);
    });
  });
}
