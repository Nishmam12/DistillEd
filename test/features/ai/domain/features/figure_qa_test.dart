// Looking at a figure again at question time (docs: roadmap D2 step 4).

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:margo/features/ai/domain/ai_exception.dart';
import 'package:margo/features/ai/domain/features/figure_qa.dart';
import 'package:margo/features/ai/domain/figure.dart';
import 'package:margo/features/ai/domain/image_transcriber.dart';
import 'package:margo/features/ai/domain/page_content_extractor.dart';
import 'package:margo/features/ai/domain/scene_graph_figure.dart';

class _Model implements ImageTranscriber {
  _Model(this.reply, {this.fails = false});
  final String reply;
  final bool fails;
  final prompts = <String>[];
  final images = <Uint8List>[];

  @override
  Future<String> transcribeImage(Uint8List imageBytes,
      {required String prompt,
      double temperature = 0.0,
      int maxOutputTokens = 1024,
      int? randomSeed}) async {
    prompts.add(prompt);
    images.add(imageBytes);
    if (fails) throw const AiGenerationException('no');
    return reply;
  }
}

const revenue = FigureDescription(
  kind: FigureKind.chart,
  title: 'Revenue by quarter',
  summary: 'A bar chart of revenue over four quarters.',
  series: [FigureSeries(label: 'Revenue')],
  nearbyText: 'Figure 2',
  bounds: Rect.fromLTRB(0, 0, 100, 100),
);
const cell = FigureDescription(
  kind: FigureKind.illustration,
  title: 'Animal cell',
  summary: 'A labelled drawing of an animal cell.',
  series: [FigureSeries(label: 'Nucleus'), FigureSeries(label: 'Mitochondria')],
);

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  FigureQa qa({
    required _Model local,
    _Model? cloud,
    bool cloudAllowed = false,
    bool preferCloud = false,
    Map<int, List<FigureDescription>> figures = const {
      7: [revenue, cell],
    },
    Map<int, String> pictures = const {},
  }) =>
      FigureQa(
        figuresOf: (pageId) async => figures[pageId] ?? const [],
        imageOf: (pageId, f) async => bytes('$pageId/${f.title}'),
        pictureOf: (pageId) async =>
            pictures[pageId] == null ? null : bytes(pictures[pageId]!),
        local: local,
        cloud: cloud,
        canUseCloud: () async => cloudAllowed,
        preferCloud: () => preferCloud,
      );

  const landed = [(pageId: 7, text: '[Figure 1 — chart: Revenue by quarter]')];
  const prose = [(pageId: 7, text: 'Revenue grew in every quarter.')];

  group('pick', () {
    test('the figure the question shares words with', () {
      expect(FigureQa.pick('where is the nucleus?', [revenue, cell]), cell);
      expect(FigureQa.pick('what was revenue in Q3?', [revenue, cell]),
          revenue);
    });

    test('"the graph" with nothing else to go on gets the first figure', () {
      expect(FigureQa.pick('what does the graph show?', [revenue, cell]),
          revenue);
    });

    test('a question about neither picks none', () {
      expect(FigureQa.pick('when did the war end?', [revenue, cell]), isNull);
    });

    test('a figure read exactly from its shapes is never looked at again', () {
      final exact = revenue.copyWith(modelId: kSceneGraphModelId);
      expect(FigureQa.pick('what was revenue in Q3?', [exact]), isNull);
    });
  });

  group('look', () {
    test('shows the model the figure and the question, and returns the reply',
        () async {
      final model = _Model('Revenue in Q3 is about 40, the tallest bar.');
      final seen = await qa(local: model)
          .look(question: 'What was revenue in Q3?', passages: landed);

      expect(utf8.decode(model.images.single), '7/Revenue by quarter');
      expect(model.prompts.single, contains('What was revenue in Q3?'));
      expect(model.prompts.single, contains('Figure 2'),
          reason: 'the caption is context');
      expect(seen!.pageId, 7);
      expect(seen.label, 'figure "Revenue by quarter"');
      expect(seen.passage, contains('about 40'));
      expect(seen.modelId, 'local');
    });

    test('a question that is not about a figure costs no model call', () async {
      final model = _Model('unused');
      final seen = await qa(local: model)
          .look(question: 'When did revenue start growing?', passages: prose);
      expect(seen, isNull);
      expect(model.prompts, isEmpty);
    });

    test('"not visible" is no answer', () async {
      final seen = await qa(local: _Model('NOT VISIBLE'))
          .look(question: 'What was revenue in Q3?', passages: landed);
      expect(seen, isNull);
    });

    test('a figure stays on the device unless the cloud is allowed', () async {
      final cloud = _Model('It is 40.');
      final seen = await qa(local: _Model('NOT VISIBLE'), cloud: cloud)
          .look(question: 'What was revenue in Q3?', passages: landed);
      expect(seen, isNull);
      expect(cloud.prompts, isEmpty);
    });

    test('when it is allowed, the cloud is asked after the local model fails',
        () async {
      final cloud = _Model('Revenue in Q3 is 40.');
      final seen = await qa(
        local: _Model('', fails: true),
        cloud: cloud,
        cloudAllowed: true,
      ).look(question: 'What was revenue in Q3?', passages: landed);
      expect(seen!.modelId, 'cloud');
    });

    test('cloud-first asks the cloud and leaves the local model alone',
        () async {
      final local = _Model('unused');
      final seen = await qa(
        local: local,
        cloud: _Model('Revenue in Q3 is 40.'),
        cloudAllowed: true,
        preferCloud: true,
      ).look(question: 'What was revenue in Q3?', passages: landed);
      expect(seen!.modelId, 'cloud');
      expect(local.prompts, isEmpty);
    });

    test('a page whose figure was never noticed: its picture is looked at when '
        'the question names a figure', () async {
      final model = _Model('The graph rises steadily from left to right.');
      final seen = await qa(
        local: model,
        figures: const {},
        pictures: const {7: 'slide.png'},
      ).look(question: 'What does the graph show?', passages: prose);
      expect(utf8.decode(model.images.single), 'slide.png');
      expect(seen!.label, 'picture');
    });

    test('nothing that goes wrong reaches the caller', () async {
      final broken = FigureQa(
        figuresOf: (_) async => throw StateError('db closed'),
        imageOf: (_, _) async => null,
        local: _Model('unused'),
      );
      expect(
          await broken.look(
              question: 'What does the graph show?', passages: landed),
          isNull);
    });
  });

  group('the picture of a figure', () {
    const photo = ImageElement(
      id: 'photo',
      zOrder: 0,
      geometryData: [0, 0, 400, 300],
      relativeImagePath: 'notes/1/imports/img.png',
    );
    SceneShapeElement box(String id, double l, double t) => SceneShapeElement(
          id: id,
          zOrder: 1,
          shapeType: ShapeType.rectangle,
          geometryData: [l, t, l + 100, t + 50],
          color: 0xFF000000,
          strokeWidth: 2,
        );

    PageContentExtractor reader(List<SceneElement> elements) =>
        PageContentExtractor(
          loadElements: (_) async => elements,
          recognition: HandwritingRecognitionService(),
          renderInk: (els) async => bytes(els.map((e) => e.id).join(',')),
          loadImageBytes: (path) async => bytes(path),
        );

    test('a figure from a picture is that picture', () async {
      final image = await reader([photo]).figureImage(
          1, revenue.copyWith(imagePath: 'notes/1/imports/img.png'));
      expect(utf8.decode(image!), 'notes/1/imports/img.png');
    });

    test('a drawn figure is rendered again from what is inside its bounds',
        () async {
      final image = await reader([box('in', 10, 10), box('far', 10, 900)])
          .figureImage(1, revenue.copyWith(
              bounds: const Rect.fromLTRB(0, 0, 200, 100)));
      expect(utf8.decode(image!), 'in');
    });

    test('a drawing that has since been erased has no picture', () async {
      final image = await reader([box('far', 10, 900)]).figureImage(
          1, revenue.copyWith(bounds: const Rect.fromLTRB(0, 0, 200, 100)));
      expect(image, isNull);
    });

    test('the largest picture on a page', () async {
      const small = ImageElement(
        id: 's',
        zOrder: 0,
        geometryData: [0, 0, 10, 10],
        relativeImagePath: 'small.png',
      );
      expect(utf8.decode((await reader([small, photo]).largestPicture(1))!),
          'notes/1/imports/img.png');
      expect(await reader([box('a', 0, 0)]).largestPicture(1), isNull);
    });
  });
}
