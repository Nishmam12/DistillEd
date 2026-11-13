// How the page reader finds, reads and places figures (docs: roadmap D2).

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:margo/features/ai/data/ocr/gemma_vision_ocr_service.dart';
import 'package:margo/features/ai/domain/figure.dart';
import 'package:margo/features/ai/domain/figure_analyzer.dart';
import 'package:margo/features/ai/domain/image_transcriber.dart';
import 'package:margo/features/ai/domain/page_content_extractor.dart';
import 'package:margo/features/ai/domain/pdf_text_layer.dart';
import 'package:margo/features/ai/domain/read_cache.dart';
import 'package:margo/features/ai/domain/scene_graph_figure.dart';

/// Answers every image with the next scripted reply, and remembers what it was
/// shown and asked.
class _Model implements ImageTranscriber {
  _Model(this.replies);
  final List<String> replies;
  final prompts = <String>[];
  final images = <Uint8List>[];
  int get calls => prompts.length;

  @override
  Future<String> transcribeImage(Uint8List imageBytes,
      {required String prompt,
      double temperature = 0.0,
      int maxOutputTokens = 1024,
      int? randomSeed}) async {
    final reply = replies[calls < replies.length ? calls : replies.length - 1];
    prompts.add(prompt);
    images.add(imageBytes);
    return reply;
  }
}

String chart(String title, List<String> labels, {double confidence = 0.9}) =>
    jsonEncode({
      'kind': 'chart',
      'title': title,
      'summary': 'A chart of $title across the period shown.',
      'series': [for (final l in labels) {'label': l, 'detail': 'rises'}],
      'insight': '$title goes up.',
      'verbatim_text': labels.join('\n'),
      'confidence': confidence,
    });

const none = '{"kind":"none"}';

SceneShapeElement box(String id, double l, double t) => SceneShapeElement(
      id: id,
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [l, t, l + 120, t + 60],
      color: 0xFF000000,
      strokeWidth: 2,
    );

TextElement text(String id, String value, double l, double t,
        {String inside = ''}) =>
    TextElement(
      id: id,
      zOrder: 3,
      geometryData: [l, t, l + 200, t + 20],
      text: value,
      color: 0xFF000000,
      containerId: inside,
    );

SceneShapeElement arrow(String id, String from, String to, List<double> at) =>
    SceneShapeElement(
      id: id,
      zOrder: 1,
      shapeType: ShapeType.arrow,
      geometryData: at,
      color: 0xFF000000,
      strokeWidth: 2,
      startBindingId: from,
      endBindingId: to,
    );

const pdfPage = ImageElement(
  id: 'pdf',
  zOrder: 0,
  geometryData: [0, 0, 800, 1000],
  relativeImagePath: 'notes/1/imports/pdf_h_1.png',
  isLocked: true,
);

void main() {
  /// Renders a region as its element ids, so a test can see what was cropped.
  Future<Uint8List?> render(List<SceneElement> els) async =>
      Uint8List.fromList(utf8.encode(els.map((e) => e.id).join(',')));

  PageContentExtractor reader(
    List<SceneElement> elements, {
    _Model? model,
    _Model? cloud,
    bool figures = true,
    ReadCache? cache,
    PdfTextLayerReader? pdfText,
    ImageTextReader? ocr,
  }) =>
      PageContentExtractor(
        loadElements: (_) async => elements,
        recognition: HandwritingRecognitionService(),
        renderInk: render,
        loadImageBytes: (path) async => Uint8List.fromList(utf8.encode(path)),
        visionOcr: GemmaVisionOcrService(transcriber: _Model(const ['unused'])),
        figureAnalyzer: figures && model != null
            ? FigureAnalyzer(
                local: model,
                cloud: cloud,
                canEscalate: () async => cloud != null,
                localModelId: 'local',
                cloudModelId: 'cloud',
              )
            : null,
        readCache: cache,
        pdfTextLayer: pdfText,
        readImageText: ocr,
      );

  group('drawings', () {
    test('two drawings on one page are read separately, each with its place',
        () async {
      final model = _Model([chart('Top', ['A']), chart('Bottom', ['B'])]);
      final content = await reader(
        [box('high', 100, 100), box('low', 100, 900)],
        model: model,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(model.calls, 2);
      expect(utf8.decode(model.images[0]), 'high');
      expect(utf8.decode(model.images[1]), 'low');
      expect(content.figures.map((f) => f.title), ['Top', 'Bottom']);
      expect(content.figures[0].bounds!.contains(const Offset(160, 130)), isTrue);
      expect(content.figures[1].bounds!.contains(const Offset(160, 930)), isTrue);
      expect(content.figures[0].bounds!.overlaps(content.figures[1].bounds!),
          isFalse);
    });

    test('a labelled flowchart is read from its shapes: exact, and no model',
        () async {
      final model = _Model([none]);
      final flow = <SceneElement>[
        box('a', 0, 0), text('ta', 'Glycolysis', 10, 20, inside: 'a'),
        box('b', 300, 0), text('tb', 'Krebs cycle', 310, 20, inside: 'b'),
        arrow('ab', 'a', 'b', [120, 30, 300, 30]),
      ];
      final content = await reader(flow, model: model)
          .extractPage(1, languageCode: 'en', useVision: true);

      expect(model.calls, 0);
      final figure = content.figures.single;
      expect(figure.modelId, kSceneGraphModelId);
      expect(figure.insight, 'Glycolysis → Krebs cycle');
      expect(content.combinedTextWithFigures, contains('Glycolysis → Krebs cycle'));
    });

    test('that works on a light read too, with no vision model at all',
        () async {
      final flow = <SceneElement>[
        box('a', 0, 0), text('ta', 'Input', 10, 20, inside: 'a'),
        box('b', 300, 0), text('tb', 'Output', 310, 20, inside: 'b'),
        arrow('ab', 'a', 'b', [120, 30, 300, 30]),
      ];
      final content = await reader(flow, figures: false)
          .extractPage(1, languageCode: 'en'); // useVision off
      expect(content.figures.single.insight, 'Input → Output');
    });

    test('a caption beside a drawing is given to the model as context',
        () async {
      final model = _Model([chart('Cell cycle', ['G1'])]);
      await reader(
        [box('a', 100, 100), text('cap', 'Figure 3: the cell cycle', 100, 190)],
        model: model,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(model.prompts.single, contains('Figure 3: the cell cycle'));
    });

    test('a reading that names things not on the figure is flagged', () async {
      final model = _Model([chart('Revenue', ['Revenue', 'Costs'])]);
      final content = await reader(
        [box('a', 100, 100), text('in', 'Mitosis cell division', 110, 120)],
        model: model,
      ).extractPage(1, languageCode: 'en', useVision: true);

      final figure = content.figures.single;
      expect(figure.isUncertain, isTrue);
      expect(content.figureBlocks, contains('could not be confirmed'));
    });

    test('and is sent to the stronger model when one is allowed', () async {
      final local = _Model([chart('Revenue', ['Revenue', 'Costs'])]);
      final cloud = _Model([chart('Mitosis', ['cell division'])]);
      final content = await reader(
        [box('a', 100, 100), text('in', 'Mitosis cell division', 110, 120)],
        model: local,
        cloud: cloud,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(cloud.calls, 1, reason: 'the local model was sure, and wrong');
      expect(content.figures.single.modelId, 'cloud');
      expect(content.figures.single.isUncertain, isFalse);
    });

    test('a remembered drawing keeps its place when it is read again',
        () async {
      final cache = InMemoryReadCache();
      final elements = [box('a', 100, 100)];
      await reader(elements, model: _Model([chart('T', ['A'])]), cache: cache)
          .extractPage(1, languageCode: 'en', useVision: true);

      final second = _Model([none]);
      final content = await reader(elements, model: second, cache: cache)
          .extractPage(1, languageCode: 'en', useVision: true);
      expect(second.calls, 0);
      expect(content.figures.single.bounds, isNotNull);
    });
  });

  group('going easy on the device', () {
    final three = [box('a', 100, 100), box('b', 100, 900), box('c', 100, 1700)];
    const equation = '{"kind":"equation","title":"Quadratic formula",'
        '"summary":"The quadratic formula as written in the notes.",'
        '"insight":"It gives the roots.","confidence":0.9}';

    test('the on-device model reads at most two drawings one by one', () async {
      final model = _Model([chart('All', ['A'])]);
      final content = await reader(three, model: model)
          .extractPage(1, languageCode: 'en', useVision: true);
      expect(model.calls, 1, reason: 'three drawings are read as one picture');
      expect(utf8.decode(model.images.single), 'a,b,c');
      expect(content.figures.length, 1);
    });

    test('the cloud, reading first, is given each one', () async {
      final local = _Model([none]);
      final cloud = _Model([chart('One', ['A'])]);
      final r = PageContentExtractor(
        loadElements: (_) async => three,
        recognition: HandwritingRecognitionService(),
        renderInk: render,
        visionOcr: GemmaVisionOcrService(transcriber: _Model(const ['unused'])),
        figureAnalyzer: FigureAnalyzer(
          local: local,
          cloud: cloud,
          canEscalate: () async => true,
          preferCloud: () => true,
        ),
      );
      final content = await r.extractPage(1, languageCode: 'en', useVision: true);
      expect(cloud.calls, 3);
      expect(local.calls, 0);
      expect(content.figures.length, 3);
    });

    test('a background read spends one call on everything drawn', () async {
      final model = _Model([chart('Both', ['A'])]);
      await reader([box('a', 100, 100), box('b', 100, 900)], model: model)
          .extractPage(1, languageCode: 'en', useVision: true, economy: true);
      expect(model.calls, 1);
    });

    test('a background read does not look at a PDF page for charts', () async {
      final model = _Model([chart('Revenue', ['Revenue'])]);
      final content = await reader([pdfPage],
              model: model,
              pdfText: (_) async =>
                  'Figure 2: Revenue by quarter. Revenue grew in every quarter '
                  'while costs stayed level throughout the whole period.')
          .extractPage(1, languageCode: 'en', useVision: true, economy: true);
      expect(model.calls, 0);
      expect(content.recognizedImageText, contains('Revenue by quarter'));
    });

    test('a background read skips the LaTeX follow-up; opening the page '
        'does it, once', () async {
      final cache = InMemoryReadCache();
      final elements = [box('a', 100, 100)];
      final model = _Model([equation, r'x = \frac{1}{2}']);

      final r = reader(elements, model: model, cache: cache);
      final background = await r.extractPage(1,
          languageCode: 'en', useVision: true, economy: true);
      expect(model.calls, 1);
      expect(background.figures.single.latex, '');

      final opened =
          await r.extractPage(1, languageCode: 'en', useVision: true);
      expect(model.calls, 2, reason: 'only the follow-up; the read is kept');
      expect(opened.figures.single.latex, r'x = \frac{1}{2}');

      await r.extractPage(1, languageCode: 'en', useVision: true);
      expect(model.calls, 2, reason: 'and it is remembered');
    });
  });

  group('a replaced reading', () {
    final elements = [box('a', 100, 100)];

    test('a re-read samples a new reading and every later read uses it',
        () async {
      final cache = InMemoryReadCache();
      final model = _Model([chart('First', ['A']), chart('Second', ['A'])]);
      final r = reader(elements, model: model, cache: cache);

      final first = (await r.extractPage(1, languageCode: 'en', useVision: true))
          .figures
          .single;
      expect(first.pinKey, isNotEmpty);

      final again = await r.rereadFigure(1, first);
      expect(again!.title, 'Second');
      expect(again.bounds, first.bounds, reason: 'it is the same figure');

      final later = await r.extractPage(1, languageCode: 'en', useVision: true);
      expect(later.figures.single.title, 'Second');
      expect(model.calls, 2, reason: 'the replaced reading is not read again');
    });

    test('the cloud is asked when the student asks for it by name', () async {
      final cache = InMemoryReadCache();
      final local = _Model([chart('Local', ['A'])]);
      final cloud = _Model([chart('Cloud', ['A'])]);
      final r = PageContentExtractor(
        loadElements: (_) async => elements,
        recognition: HandwritingRecognitionService(),
        renderInk: render,
        visionOcr: GemmaVisionOcrService(transcriber: _Model(const ['unused'])),
        // No standing permission to escalate: only the explicit ask reaches it.
        figureAnalyzer: FigureAnalyzer(local: local, cloud: cloud),
        readCache: cache,
      );
      final first = (await r.extractPage(1, languageCode: 'en', useVision: true))
          .figures
          .single;
      expect(cloud.calls, 0);

      final asked = await r.rereadFigure(1, first, onCloud: true);
      expect(asked!.title, 'Cloud');
      expect(cloud.calls, 1);
    });

    test("the student's own description outranks any model", () async {
      final cache = InMemoryReadCache();
      final r = reader(elements,
          model: _Model([chart('Wrong', ['A'])]), cache: cache);
      final first = (await r.extractPage(1, languageCode: 'en', useVision: true))
          .figures
          .single;

      await r.correctFigure(first,
          title: 'Cell cycle', summary: 'The four phases of the cell cycle.');

      final later = await reader(elements,
              model: _Model([chart('Wrong again', ['A'])]), cache: cache)
          .extractPage(1, languageCode: 'en', useVision: true);
      final figure = later.figures.single;
      expect(figure.modelId, kUserFigureModelId);
      expect(figure.summary, 'The four phases of the cell cycle.');
      expect(figure.isUncertain, isFalse);
      expect(later.figureBlocks, contains('Cell cycle'));
    });

    test('a figure read exactly from shapes has nothing to replace', () async {
      final flow = <SceneElement>[
        box('a', 0, 0), text('ta', 'Input', 10, 20, inside: 'a'),
        box('b', 300, 0), text('tb', 'Output', 310, 20, inside: 'b'),
        arrow('ab', 'a', 'b', [120, 30, 300, 30]),
      ];
      final content = await reader(flow, cache: InMemoryReadCache())
          .extractPage(1, languageCode: 'en');
      expect(content.figures.single.pinKey, isEmpty);
    });
  });

  group('pictures and PDF pages', () {
    // Long enough to stand as the page's text (see kMinPdfTextChars).
    const slideText = 'Figure 2: Revenue by quarter\nRevenue Costs Q1 Q2 Q3 Q4\n'
        'Revenue grew in every quarter while costs stayed level throughout.';

    test('a PDF page that mentions a figure is looked at, though its text is '
        'already known', () async {
      final model = _Model([chart('Revenue by quarter', ['Revenue', 'Costs'])]);
      final content = await reader([pdfPage],
              model: model, pdfText: (_) async => slideText)
          .extractPage(1, languageCode: 'en', useVision: true);

      expect(model.calls, 1);
      expect(content.recognizedImageText, slideText);
      final figure = content.figures.single;
      expect(figure.imagePath, pdfPage.relativeImagePath);
      expect(figure.bounds, const Rect.fromLTRB(0, 0, 800, 1000));
      expect(figure.grounding, 1.0, reason: 'checked against the page text');
    });

    test('a page of plain prose is not', () async {
      final model = _Model([none]);
      await reader([pdfPage],
              model: model,
              pdfText: (_) async =>
                  'The French Revolution began in 1789 and changed the '
                  'political order of Europe for the century that followed.')
          .extractPage(1, languageCode: 'en', useVision: true);
      expect(model.calls, 0);
    });

    test('a page found to hold no figure is not asked about again', () async {
      final model = _Model([none]);
      final r = reader([pdfPage],
          model: model,
          pdfText: (_) async => slideText,
          cache: InMemoryReadCache());
      await r.extractPage(1, languageCode: 'en', useVision: true);
      await r.extractPage(1, languageCode: 'en', useVision: true);
      expect(model.calls, 1);
    });

    test('a figure in a photo knows which picture it came from, and is checked '
        'against what OCR reads there', () async {
      const photo = ImageElement(
        id: 'photo',
        zOrder: 0,
        geometryData: [50, 60, 450, 360],
        relativeImagePath: 'notes/1/imports/img_9.png',
      );
      final model = _Model([chart('Enzyme activity', ['pH', 'Rate'])]);
      final content = await reader([photo],
              model: model,
              ocr: (_) async => 'Enzyme activity\npH Rate of reaction')
          .extractPage(1, languageCode: 'en', useVision: true);

      final figure = content.figures.single;
      expect(figure.imagePath, 'notes/1/imports/img_9.png');
      expect(figure.bounds, const Rect.fromLTRB(50, 60, 450, 360));
      expect(figure.grounding, 1.0);
    });
  });

  group('pdfTextSuggestsFigure', () {
    test('mentions of a figure', () {
      for (final t in [
        'As Figure 4 shows, demand falls as price rises across the range.',
        'see Fig. 2 for the full derivation of this result in the appendix',
        'The graph below plots temperature against time for each sample.',
        'Table 3 lists the measured values for every trial in the series.',
      ]) {
        expect(pdfTextSuggestsFigure(t), isTrue, reason: t);
      }
    });

    test('ordinary prose is not', () {
      expect(
          pdfTextSuggestsFigure('The treaty was signed in 1648 and ended three '
              'decades of war across the continent between the powers.'),
          isFalse);
    });
  });

  test('a figure keeps its context and grounding through the cache', () {
    const f = FigureDescription(
      kind: FigureKind.chart,
      summary: 'A chart of things over time, rising.',
      nearbyText: 'Figure 1',
      grounding: 0.5,
    );
    final back = FigureDescription.fromJson(f.toJson())!;
    expect(back.nearbyText, 'Figure 1');
    expect(back.grounding, 0.5);
  });
}
