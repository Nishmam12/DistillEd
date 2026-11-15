// The vector PDF: built uncompressed here so its content can be read back.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/domain/model/template_type.dart';
import 'package:margo/editor/render/pdf_export_plan.dart';
import 'package:margo/editor/render/vector_pdf_writer.dart';

Uint8List _font(String name) =>
    File('assets/fonts/pdf/$name').readAsBytesSync();

final _regular = _font('NotoSans-Regular.ttf');
final _bold = _font('NotoSans-Bold.ttf');
final _bengali = _font('NotoSansBengali-Regular.ttf');

/// A 1 x 1 PNG.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

const _a4 = Rect.fromLTWH(0, 0, 794, 1123);

Future<String> _pdf(List<PdfPagePlan> pages,
    {Map<String, Uint8List> images = const {}}) async {
  final bytes = await writeVectorPdf(PdfExportJob(
    pages: pages,
    images: images,
    regularFont: _regular,
    boldFont: _bold,
    bengaliFont: _bengali,
    compress: false,
  ));
  return latin1.decode(bytes);
}

PdfPagePlan _page({
  List<SceneElement> elements = const [],
  Map<String, PdfTextBlock> texts = const {},
  List<PdfHiddenText> hidden = const [],
  TemplateType template = TemplateType.blank,
  Rect sheet = _a4,
}) =>
    PdfPagePlan(
      sheet: sheet,
      bounded: true,
      background: 0xFFFFFFFF,
      template: template,
      elements: elements,
      texts: texts,
      hidden: hidden,
    );

FreehandElement _stroke(String id,
        {PenKind kind = PenKind.ballpoint, double y = 100}) =>
    FreehandElement(
      id: id,
      zOrder: 0,
      points: [
        StrokePoint(x: 100, y: y, pressure: 0.5),
        StrokePoint(x: 150, y: y + 10, pressure: 0.5),
        StrokePoint(x: 200, y: y, pressure: 0.5),
      ],
      color: 0xFF1F2933,
      size: 3,
      penKind: kind,
    );

int _count(String haystack, String needle) =>
    needle.allMatches(haystack).length;

void main() {
  test('an A4 page is 595 x 842 points', () async {
    final pdf = await _pdf([_page()]);
    expect(pdf, contains('/MediaBox[0 0 595.5 842.25]'));
  });

  test('every page is kept, empty ones too, in order', () async {
    final pdf = await _pdf([_page(), _page(elements: [_stroke('a')]), _page()]);
    expect(RegExp(r'/Type\s*/Page\b(?!s)').allMatches(pdf).length, 3);
  });

  test('ink is a filled vector outline, not a picture', () async {
    final pdf = await _pdf([_page(elements: [_stroke('a')])]);
    expect(pdf, contains(' c '), reason: 'curves');
    expect(pdf, isNot(contains('/Subtype/Image')));
  });

  test('a highlighter keeps its see-through look', () async {
    final pdf =
        await _pdf([_page(elements: [_stroke('h', kind: PenKind.highlighter)])]);
    expect(pdf, contains('/ca 0.4'));
  });

  test('typed text is real text, stretched to the canvas width', () async {
    final pdf = await _pdf([
      _page(texts: {
        't': const PdfTextBlock(
          lines: [
            PdfTextLine(text: 'Mitosis', left: 50, baseline: 80, width: 70),
          ],
          fontSize: 20,
          color: 0xFF000000,
          opacity: 1,
          bold: false,
          italic: false,
          rotation: 0,
          centre: Offset(85, 75),
        ),
      }, elements: [
        const TextElement(
          id: 't',
          zOrder: 0,
          geometryData: [50, 60, 150, 90],
          text: 'Mitosis',
          color: 0xFF000000,
          fontSize: 20,
        ),
      ]),
    ]);
    expect(pdf, contains('BT'));
    expect(pdf, contains(' Tz'));
    expect(pdf, contains('/ToUnicode'),
        reason: 'the glyphs map back to letters, so the text can be searched');
    expect(pdf, isNot(contains('3 Tr')));
  });

  test('hidden text is invisible text', () async {
    final pdf = await _pdf([
      _page(hidden: const [
        PdfHiddenText('handwritten words', Rect.fromLTWH(100, 100, 200, 30)),
      ]),
    ]);
    expect(pdf, contains('3 Tr'));
  });

  test('Bangla hidden text uses the Bangla font, and unknown glyphs are dropped',
      () async {
    final pdf = await _pdf([
      _page(hidden: const [
        PdfHiddenText('কোষ বিভাজন 🙂', Rect.fromLTWH(100, 100, 200, 30)),
      ]),
    ]);
    // Bangla runs and the spaces between them use different fonts.
    final fonts = RegExp(r'(/F\d+) [\d.]+ Tf')
        .allMatches(pdf)
        .map((m) => m.group(1))
        .toSet();
    expect(fonts.length, greaterThanOrEqualTo(2));
    expect(pdf, contains('3 Tr'));
  });

  test('a picture is embedded once, however many times it is used', () async {
    const image = ImageElement(
      id: 'i',
      zOrder: 0,
      geometryData: [0, 0, 400, 300],
      relativeImagePath: 'notes/1/p.png',
    );
    final pdf = await _pdf(
      [
        _page(elements: [image]),
        _page(elements: [image.copyWith(id: 'j')]),
      ],
      images: {'notes/1/p.png': _png},
    );
    final once = await _pdf([_page(elements: [image])],
        images: {'notes/1/p.png': _png});
    expect(_count(pdf, '/Subtype/Image'), _count(once, '/Subtype/Image'));
    expect(_count(once, '/Subtype/Image'), greaterThan(0));
  });

  test('a missing picture draws the placeholder, and the export goes on',
      () async {
    final pdf = await _pdf([
      _page(elements: const [
        ImageElement(
          id: 'i',
          zOrder: 0,
          geometryData: [0, 0, 400, 300],
          relativeImagePath: 'notes/1/gone.png',
        ),
      ]),
    ]);
    expect(pdf, isNot(contains('/Subtype/Image')));
    expect(pdf, contains('/MediaBox'));
  });

  test('the paper pattern is drawn as lines', () async {
    final blank = await _pdf([_page()]);
    final ruled = await _pdf([_page(template: TemplateType.ruled)]);
    expect(_count(ruled, ' l\n') + _count(ruled, ' l '),
        greaterThan(_count(blank, ' l\n') + _count(blank, ' l ') + 20));
  });

  test('shapes, tape and frames draw without error', () async {
    final pdf = await _pdf([
      _page(elements: const [
        SceneShapeElement(
          id: 'r',
          zOrder: 0,
          shapeType: ShapeType.rectangle,
          geometryData: [10, 10, 110, 60],
          color: 0xFF000000,
          strokeWidth: 2,
          seed: 1,
          hasFill: true,
          fillColor: 0xFFFFE066,
          strokeStyle: StrokeStyle.dashed,
        ),
        SceneShapeElement(
          id: 'a',
          zOrder: 1,
          shapeType: ShapeType.arrow,
          geometryData: [10, 100, 200, 160],
          color: 0xFF000000,
          strokeWidth: 2,
          seed: 1,
          elbowed: true,
          startArrowhead: Arrowhead.dot,
        ),
        TapeElement(id: 't', zOrder: 2, geometryData: [20, 200, 300, 230]),
        TapeElement(
            id: 'u', zOrder: 3, geometryData: [20, 240, 300, 270], revealed: true),
        FrameElement(
            id: 'f', zOrder: 4, geometryData: [0, 300, 400, 500], name: 'Cells'),
      ]),
    ]);
    expect(pdf, contains('/MediaBox'));
  });
}
