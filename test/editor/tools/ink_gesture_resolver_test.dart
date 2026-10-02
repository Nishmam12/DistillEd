import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/tools/ink_gestures.dart';

/// Answers each model with a fixed label (or nothing, or an error) and records
/// which models it was asked.
class _FakeClassifier implements InkClassifier {
  _FakeClassifier({this.byModel = const {}, this.throws = false});

  final Map<String, String> byModel;
  final bool throws;
  final asked = <String>[];

  @override
  Future<InkClass?> classify(FreehandElement stroke, {required String model}) async {
    asked.add(model);
    if (throws) throw StateError('platform channel failed');
    final label = byModel[model];
    return label == null ? null : (label: label, score: 0.1);
  }
}

List<StrokePoint> trace(List<(double, double)> corners, {int stepMs = 10}) {
  final out = <StrokePoint>[];
  var t = 0;
  for (var i = 0; i < corners.length - 1; i++) {
    final (x0, y0) = corners[i];
    final (x1, y1) = corners[i + 1];
    for (var s = 0; s < 10; s++) {
      final f = s / 10;
      out.add(StrokePoint(x: x0 + (x1 - x0) * f, y: y0 + (y1 - y0) * f, t: t));
      t += stepMs;
    }
  }
  final (lx, ly) = corners.last;
  out.add(StrokePoint(x: lx, y: ly, t: t));
  return out;
}

FreehandElement stroke(List<StrokePoint> points) => FreehandElement(
    id: 'new', zOrder: 7, points: points, color: 0xFF336699, size: 4, opacity: 0.7);

/// 100 px square-ish stroke, drawn in 400 ms.
List<StrokePoint> square() =>
    trace([(0, 0), (100, 0), (100, 100), (0, 100)]);

/// A scrub across x 0..90, y 0..72.
List<StrokePoint> scrub() => trace([
      for (var i = 0; i <= 6; i++) (i.isEven ? 0.0 : 90.0, i * 12.0),
    ]);

SceneShapeElement existing(String id, double l, double t, double w, double h) =>
    SceneShapeElement(
      id: id,
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [l, t, l + w, t + h],
      color: 0xFF000000,
      strokeWidth: 2,
    );

Future<InkGestureAction?> resolve(
  FreehandElement s, {
  List<SceneElement> scene = const [],
  int? upMs,
  required InkClassifier classifier,
  bool snap = true,
  bool erase = true,
  double zoom = 1,
}) =>
    resolveInkGesture(
      stroke: s,
      scene: [...scene, s],
      upMs: upMs ?? s.points.last.t!,
      classifier: classifier,
      snapShapes: snap,
      scribbleErase: erase,
      zoom: zoom,
      newId: () => 'shape-1',
      seed: 99,
    );

void main() {
  final underScrub = existing('word', 10, 10, 60, 40);

  group('scribble to erase', () {
    test('a scrub over something, that the model calls a scribble, erases it',
        () async {
      final classifier = _FakeClassifier(byModel: {kGestureModel: 'scribble'});

      final action =
          await resolve(stroke(scrub()), scene: [underScrub], classifier: classifier);

      expect(action, isA<ScribbleErase>());
      expect((action as ScribbleErase).victims, [underScrub]);
      expect(classifier.asked, [kGestureModel]);
    });

    test('the label is matched without regard to case', () async {
      final classifier = _FakeClassifier(byModel: {kGestureModel: 'Scribble'});

      expect(
          await resolve(stroke(scrub()), scene: [underScrub], classifier: classifier),
          isA<ScribbleErase>());
    });

    test('a scrub the model calls writing erases nothing', () async {
      final classifier = _FakeClassifier(byModel: {kGestureModel: 'writing'});

      expect(
          await resolve(stroke(scrub()), scene: [underScrub], classifier: classifier),
          isNull);
    });

    test('a stroke that does not scrub is not even shown to the model', () async {
      // A circle drawn AROUND the element: its box covers it, and the model
      // would happily call it a scribble — but it does not scrub, and the
      // stroke's own geometry has the last word.
      final classifier = _FakeClassifier(byModel: {kGestureModel: 'scribble'});
      final circle = [
        for (var i = 0; i <= 40; i++)
          StrokePoint(
              x: 40 + 60 * math.cos(i / 40 * 2 * math.pi),
              y: 30 + 60 * math.sin(i / 40 * 2 * math.pi),
              t: i * 10),
      ];

      final action =
          await resolve(stroke(circle), scene: [underScrub], classifier: classifier);

      expect(action, isNull);
      expect(classifier.asked, isEmpty);
    });

    test('a scrub over nothing is left as ink — and costs no model call',
        () async {
      final classifier = _FakeClassifier(byModel: {kGestureModel: 'scribble'});

      final action = await resolve(stroke(scrub()), classifier: classifier);

      expect(action, isNull);
      expect(classifier.asked, isEmpty);
    });

    test('with the setting off the model is never asked', () async {
      final classifier = _FakeClassifier(byModel: {kGestureModel: 'scribble'});

      final action = await resolve(stroke(scrub()),
          scene: [underScrub], classifier: classifier, erase: false);

      expect(action, isNull);
      expect(classifier.asked, isEmpty);
    });

    test('the scribble itself is never one of the things erased', () async {
      final classifier = _FakeClassifier(byModel: {kGestureModel: 'scribble'});

      final action =
          await resolve(stroke(scrub()), scene: [underScrub], classifier: classifier);

      expect((action as ScribbleErase).victims.any((e) => e.id == 'new'), isFalse);
    });
  });

  group('hold to snap', () {
    test('a held stroke the model calls RECTANGLE becomes a rectangle in its '
        'place, in its colour, width and layer', () async {
      final classifier = _FakeClassifier(byModel: {kShapesModel: 'RECTANGLE'});
      final s = stroke(square());

      final action = await resolve(s,
          upMs: s.points.last.t! + 800, classifier: classifier);

      expect(action, isA<SnapToShape>());
      final shape = (action as SnapToShape).shape;
      expect(shape.shapeType, ShapeType.rectangle);
      expect(shape.geometryData, [0, 0, 100, 100]);
      expect(shape.color, 0xFF336699);
      expect(shape.strokeWidth, 4);
      expect(shape.opacity, 0.7);
      expect(shape.zOrder, 7);
      expect(shape.id, 'shape-1');
      expect(shape.seed, 99);
      expect(classifier.asked, [kShapesModel]);
    });

    test('a stroke lifted at once is not asked about', () async {
      final classifier = _FakeClassifier(byModel: {kShapesModel: 'RECTANGLE'});
      final s = stroke(square());

      final action = await resolve(s, classifier: classifier);

      expect(action, isNull);
      expect(classifier.asked, isEmpty);
    });

    test('with the setting off the model is never asked', () async {
      final classifier = _FakeClassifier(byModel: {kShapesModel: 'RECTANGLE'});
      final s = stroke(square());

      final action = await resolve(s,
          upMs: s.points.last.t! + 800, classifier: classifier, snap: false);

      expect(action, isNull);
      expect(classifier.asked, isEmpty);
    });

    test('a label that is not a shape is not a snap', () async {
      final classifier = _FakeClassifier(byModel: {kShapesModel: 'SQUIGGLE'});
      final s = stroke(square());

      expect(
          await resolve(s, upMs: s.points.last.t! + 800, classifier: classifier),
          isNull);
    });
  });

  group('when the model is missing or misbehaves', () {
    test('no answer — the model is not on the device — leaves the stroke be',
        () async {
      final classifier = _FakeClassifier();
      final s = stroke(square());

      expect(
          await resolve(s, upMs: s.points.last.t! + 800, classifier: classifier),
          isNull);
    });

    test('a classifier that throws leaves the stroke be', () async {
      final classifier = _FakeClassifier(throws: true);
      final s = stroke(square());

      expect(
          await resolve(s, upMs: s.points.last.t! + 800, classifier: classifier),
          isNull);
      expect(
          await resolve(stroke(scrub()),
              scene: [underScrub], classifier: classifier),
          isNull);
    });
  });

  group('a stroke that could be either', () {
    test('a scribble wins over a snap', () async {
      // A scrub held at the end, over content: both gestures apply.
      final classifier = _FakeClassifier(
          byModel: {kGestureModel: 'scribble', kShapesModel: 'RECTANGLE'});
      final s = stroke(scrub());

      final action = await resolve(s,
          scene: [underScrub], upMs: s.points.last.t! + 800, classifier: classifier);

      expect(action, isA<ScribbleErase>());
      expect(classifier.asked, [kGestureModel]);
    });

    test('a scrub the model does not call a scribble can still snap if held',
        () async {
      final classifier = _FakeClassifier(
          byModel: {kGestureModel: 'writing', kShapesModel: 'RECTANGLE'});
      final s = stroke(scrub());

      final action = await resolve(s,
          scene: [underScrub], upMs: s.points.last.t! + 800, classifier: classifier);

      expect(action, isA<SnapToShape>());
      expect(classifier.asked, [kGestureModel, kShapesModel]);
    });
  });
}
