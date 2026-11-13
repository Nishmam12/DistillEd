import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/features/ai/domain/figure_locator.dart';

SceneShapeElement box(String id, double l, double t, double r, double b) =>
    SceneShapeElement(
      id: id,
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [l, t, r, b],
      color: 0xFF000000,
      strokeWidth: 2,
    );

SceneShapeElement arrow(String id, double x1, double y1, double x2, double y2,
        {String from = '', String to = ''}) =>
    SceneShapeElement(
      id: id,
      zOrder: 1,
      shapeType: ShapeType.arrow,
      geometryData: [x1, y1, x2, y2],
      color: 0xFF000000,
      strokeWidth: 2,
      startBindingId: from,
      endBindingId: to,
    );

FreehandElement stroke(String id, double l, double t, double r, double b) =>
    FreehandElement(
      id: id,
      zOrder: 2,
      color: 0xFF000000,
      size: 2,
      points: [StrokePoint(x: l, y: t), StrokePoint(x: r, y: b)],
    );

TextElement label(String id, String text, double l, double t, double r, double b,
        {String inside = ''}) =>
    TextElement(
      id: id,
      zOrder: 3,
      geometryData: [l, t, r, b],
      text: text,
      color: 0xFF000000,
      containerId: inside,
    );

void main() {
  test('a page with nothing drawn has no figures', () {
    expect(locateFigures(const [], writingIds: const {}), isEmpty);
    expect(
        locateFigures([label('t', 'just words', 0, 0, 100, 20)],
            writingIds: const {}),
        isEmpty);
  });

  test('handwriting alone is not a figure', () {
    final page = [stroke('w1', 0, 0, 80, 20), stroke('w2', 0, 30, 90, 50)];
    expect(locateFigures(page, writingIds: {'w1', 'w2'}), isEmpty);
  });

  test('two boxes joined by an arrow are one figure', () {
    final page = [
      box('a', 100, 100, 200, 160),
      box('b', 400, 100, 500, 160),
      arrow('ab', 200, 130, 400, 130, from: 'a', to: 'b'),
    ];
    final regions = locateFigures(page, writingIds: const {});
    expect(regions, hasLength(1));
    expect(regions.single.elements.map((e) => e.id), containsAll(['a', 'b', 'ab']));
    expect(regions.single.bounds.contains(const Offset(150, 130)), isTrue);
    expect(regions.single.bounds.contains(const Offset(450, 130)), isTrue);
  });

  test('two drawings far apart are two figures, top one first', () {
    final page = [
      box('low', 100, 900, 220, 980),
      box('high', 100, 100, 220, 180),
    ];
    final regions = locateFigures(page, writingIds: const {});
    expect(regions, hasLength(2));
    expect(regions.first.elements.single.id, 'high');
  });

  test('labels inside a figure come with it; a caption beside it is context',
      () {
    final page = [
      box('a', 100, 100, 260, 180),
      label('in', 'Mitosis', 120, 130, 240, 150, inside: 'a'),
      label('cap', 'Figure 1: the cell cycle', 100, 200, 400, 220),
      label('far', 'Homework for Monday', 100, 900, 400, 920),
    ];
    final region = locateFigures(page, writingIds: const {}).single;
    expect(region.elements.map((e) => e.id), contains('in'));
    expect(region.labelText, contains('Mitosis'));
    expect(region.nearbyText, contains('Figure 1'));
    expect(region.nearbyText, isNot(contains('Homework')));
  });

  test('ink that is not writing is a figure; writing over it is its label', () {
    final page = [
      stroke('axisX', 100, 400, 400, 400),
      stroke('axisY', 100, 100, 100, 400),
      stroke('curve', 110, 380, 390, 120),
      stroke('word', 420, 395, 470, 410), // "time", read by ML Kit
      stroke('prose', 100, 800, 500, 820),
    ];
    final regions = locateFigures(
      page,
      writingIds: {'word', 'prose'},
      textLines: [
        (bounds: const Rect.fromLTRB(420, 395, 470, 410), text: 'time'),
        (bounds: const Rect.fromLTRB(100, 800, 500, 820), text: 'next week'),
      ],
    );
    expect(regions, hasLength(1));
    final ids = regions.single.elements.map((e) => e.id);
    expect(ids, containsAll(['axisX', 'axisY', 'curve']));
    expect(ids, isNot(contains('prose')));
    expect(regions.single.labelText + regions.single.nearbyText, contains('time'));
  });

  test('a stray dot is not a figure', () {
    final page = [stroke('dot', 100, 100, 103, 102), stroke('w', 0, 0, 90, 20)];
    expect(locateFigures(page, writingIds: {'w'}), isEmpty);
  });

  test('when it is not known which ink is writing, the whole drawing is one '
      'figure', () {
    final page = [
      box('a', 100, 100, 200, 160),
      stroke('s', 100, 900, 300, 920),
    ];
    final regions = locateFigures(page, writingIds: null);
    expect(regions, hasLength(1));
    expect(regions.single.elements, hasLength(2));
  });

  test('a page of many scattered drawings is read as one, not a dozen calls',
      () {
    final page = [
      for (var i = 0; i < 7; i++) box('b$i', 100, i * 400.0, 200, i * 400.0 + 80),
    ];
    expect(locateFigures(page, writingIds: const {}), hasLength(1));
  });

  test('erased ink and pictures are never part of a figure', () {
    final page = <SceneElement>[
      box('a', 100, 100, 200, 160),
      const FreehandElement(
          id: 'rub', zOrder: 5, color: 0, size: 9, isEraser: true,
          points: [StrokePoint(x: 120, y: 120), StrokePoint(x: 150, y: 150)]),
      const ImageElement(
          id: 'pic', zOrder: 0, geometryData: [0, 0, 1000, 1000],
          relativeImagePath: 'notes/1/imports/x.png'),
    ];
    final region = locateFigures(page, writingIds: const {}).single;
    expect(region.elements.map((e) => e.id), ['a']);
  });
}
