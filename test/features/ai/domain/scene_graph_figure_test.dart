import 'package:flutter_test/flutter_test.dart';

import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/features/ai/domain/figure.dart';
import 'package:margo/features/ai/domain/figure_grounding.dart';
import 'package:margo/features/ai/domain/figure_locator.dart';
import 'package:margo/features/ai/domain/scene_graph_figure.dart';

SceneShapeElement box(String id, double l, double t) => SceneShapeElement(
      id: id,
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [l, t, l + 120, t + 60],
      color: 0xFF000000,
      strokeWidth: 2,
    );

TextElement name(String shapeId, String text, double l, double t) => TextElement(
      id: 't-$shapeId',
      zOrder: 3,
      geometryData: [l + 10, t + 20, l + 110, t + 40],
      text: text,
      color: 0xFF000000,
      containerId: shapeId,
    );

SceneShapeElement arrow(String id,
        {String from = '', String to = '', List<double>? at, Arrowhead end = Arrowhead.triangle}) =>
    SceneShapeElement(
      id: id,
      zOrder: 1,
      shapeType: ShapeType.arrow,
      geometryData: at ?? const [0, 0, 1, 1],
      color: 0xFF000000,
      strokeWidth: 2,
      startBindingId: from,
      endBindingId: to,
      endArrowhead: end,
    );

FigureRegion regionOf(List<SceneElement> elements) =>
    locateFigures(elements, writingIds: const {}).single;

void main() {
  group('describeSceneGraph', () {
    final flow = <SceneElement>[
      box('a', 0, 0), name('a', 'Glycolysis', 0, 0),
      box('b', 300, 0), name('b', 'Krebs cycle', 300, 0),
      box('c', 600, 0), name('c', 'Electron transport', 600, 0),
      arrow('ab', from: 'a', to: 'b', at: [120, 30, 300, 30]),
      arrow('bc', from: 'b', to: 'c', at: [420, 30, 600, 30]),
    ];

    test('a labelled flowchart is read exactly, with no model', () {
      final f = describeSceneGraph(regionOf(flow))!;
      expect(f.kind, FigureKind.diagram);
      expect(f.modelId, kSceneGraphModelId);
      expect(f.confidence, 1.0);
      expect(f.series.map((s) => s.label),
          ['Glycolysis', 'Krebs cycle', 'Electron transport']);
      expect(f.series.first.detail, contains('Krebs cycle'));
      expect(f.insight, 'Glycolysis → Krebs cycle → Electron transport');
      expect(f.isUncertain, isFalse);
      expect(f.isInformative, isTrue);
    });

    test('an arrow drawn between two boxes but not attached still connects them',
        () {
      final loose = <SceneElement>[
        box('a', 0, 0), name('a', 'Input', 0, 0),
        box('b', 300, 0), name('b', 'Output', 300, 0),
        arrow('ab', at: [124, 30, 296, 30]),
      ];
      final f = describeSceneGraph(regionOf(loose))!;
      expect(f.insight, 'Input → Output');
    });

    test('a plain line connects without a direction', () {
      final f = describeSceneGraph(regionOf(<SceneElement>[
        box('a', 0, 0), name('a', 'Sun', 0, 0),
        box('b', 300, 0), name('b', 'Earth', 300, 0),
        arrow('ab', from: 'a', to: 'b', at: [120, 30, 300, 30], end: Arrowhead.none),
      ]))!;
      expect(f.summary, contains('Sun — Earth'));
    });

    test('a branch is listed, not forced into a chain', () {
      final f = describeSceneGraph(regionOf(<SceneElement>[
        box('a', 300, 0), name('a', 'Cell', 300, 0),
        box('b', 0, 200), name('b', 'Plant', 0, 200),
        box('c', 600, 200), name('c', 'Animal', 600, 200),
        arrow('ab', from: 'a', to: 'b', at: [360, 60, 60, 200]),
        arrow('ac', from: 'a', to: 'c', at: [360, 60, 660, 200]),
      ]))!;
      expect(f.series.firstWhere((s) => s.label == 'Cell').detail,
          allOf(contains('Plant'), contains('Animal')));
      expect(f.insight, isNot(contains('Plant → Animal')));
    });

    test('unlabelled boxes are left to the vision model', () {
      expect(
          describeSceneGraph(regionOf(<SceneElement>[
            box('a', 0, 0),
            box('b', 300, 0),
            arrow('ab', from: 'a', to: 'b', at: [120, 30, 300, 30]),
          ])),
          isNull);
    });

    test('boxes with nothing joining them are left to the vision model', () {
      expect(
          describeSceneGraph(regionOf(<SceneElement>[
            box('a', 0, 0), name('a', 'One', 0, 0),
            box('b', 130, 0), name('b', 'Two', 130, 0),
          ])),
          isNull);
    });

    test('pen drawing mixed in means the shapes are not the whole story', () {
      final mixed = <SceneElement>[
        ...flow,
        const FreehandElement(
            id: 'sketch', zOrder: 9, color: 0, size: 2,
            points: [StrokePoint(x: 100, y: 70), StrokePoint(x: 500, y: 90)]),
      ];
      expect(describeSceneGraph(regionOf(mixed)), isNull);
    });
  });

  group('groundingOf', () {
    const read = FigureDescription(
      kind: FigureKind.chart,
      title: 'Revenue by quarter',
      summary: 'Revenue rises across the four quarters.',
      series: [FigureSeries(label: 'Revenue'), FigureSeries(label: 'Costs')],
    );

    test('labels found in the page text are confirmed', () {
      expect(groundingOf(read, 'Revenue by quarter\nRevenue Costs Q1 Q2 Q3 Q4'), 1.0);
    });

    test('labels the page does not contain are not', () {
      final g = groundingOf(read, 'Mitochondria produce ATP through respiration')!;
      expect(g, 0.0);
      expect(read.copyWith(grounding: g).isUncertain, isTrue);
    });

    test('a slip in handwriting recognition still counts', () {
      expect(groundingOf(read, 'Revenve by quarter\nRevenue Cost Q1 Q2'),
          greaterThan(0.6));
    });

    test('nothing to check against means no verdict', () {
      expect(groundingOf(read, ''), isNull);
      expect(groundingOf(read, 'Q1'), isNull);
    });

    test('a description that names nothing has nothing to confirm', () {
      const bare = FigureDescription(
          kind: FigureKind.diagram, summary: 'Some kind of drawing here.');
      expect(groundingOf(bare, 'plenty of words on the page here'), isNull);
    });
  });
}
