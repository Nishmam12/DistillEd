// The figure benchmark's own logic (docs: roadmap D2 step 8).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/features/ai/domain/figure.dart';
import 'package:margo/features/ai/domain/figure_benchmark.dart';
import 'package:margo/features/ai/domain/image_transcriber.dart';
import 'package:margo/features/ai/domain/page_content.dart';

class _Model implements ImageTranscriber {
  _Model(this.reply);
  final String reply;
  final prompts = <String>[];

  @override
  Future<String> transcribeImage(Uint8List imageBytes,
      {required String prompt,
      double temperature = 0.0,
      int maxOutputTokens = 1024,
      int? randomSeed}) async {
    prompts.add(prompt);
    return reply;
  }
}

TextElement box(String id, String text) => TextElement(
      id: id,
      zOrder: 0,
      geometryData: const [0, 0, 200, 40],
      text: text,
      color: 0xFF000000,
    );

const shape = SceneShapeElement(
  id: 'chart',
  zOrder: 0,
  shapeType: ShapeType.rectangle,
  geometryData: [0, 100, 200, 200],
  color: 0xFF000000,
  strokeWidth: 2,
);

const revenue = FigureDescription(
  kind: FigureKind.chart,
  title: 'Revenue',
  summary: 'A bar chart of revenue over four quarters.',
);

void main() {
  group('benchQuestionsOf', () {
    test('Q/A pairs in a text box, with alternatives', () {
      final found = benchQuestionsOf([
        box('qa', 'Q: What is the value in Q3?\nA: 40 | forty\n'
            'q) Which bar is tallest?\na) Q3'),
        box('note', 'Just a caption'),
        shape,
      ]);
      expect(found.boxIds, {'qa'});
      expect(found.questions.map((q) => q.question),
          ['What is the value in Q3?', 'Which bar is tallest?']);
      expect(found.questions.first.accepted, ['40', 'forty']);
    });

    test('a question with no answer is not a case', () {
      final found = benchQuestionsOf([box('qa', 'Q: What is this?')]);
      expect(found.questions, isEmpty);
      expect(found.boxIds, isEmpty);
    });
  });

  group('benchAnswerMatches', () {
    test('the wanted words and numbers, however the reply is worded', () {
      expect(benchAnswerMatches('It reaches 40 in the third quarter.', ['40']),
          isTrue);
      expect(benchAnswerMatches('The value is 40.0', ['40']), isTrue);
      expect(benchAnswerMatches('About 1,200 units', ['1200']), isTrue);
      expect(benchAnswerMatches('Two arrows leave it', ['two arrow']), isTrue);
      expect(benchAnswerMatches('The Krebs Cycle', ['krebs cycle']), isTrue);
    });

    test('numbers are exact', () {
      expect(benchAnswerMatches('about 45', ['40']), isFalse);
      expect(benchAnswerMatches('It is 140', ['40']), isFalse);
      expect(benchAnswerMatches('4.0', ['40']), isFalse);
    });

    test('any one alternative is enough; an empty reply never is', () {
      expect(benchAnswerMatches('forty', ['40', 'forty']), isTrue);
      expect(benchAnswerMatches('', ['40']), isFalse);
      expect(benchAnswerMatches('NOT VISIBLE', ['40']), isFalse);
    });
  });

  test('a run answers each question every way, without the Q/A box in view',
      () async {
    List<SceneElement>? read;
    final local = _Model('The Q3 bar reaches 45.');
    final cloud = _Model('The Q3 bar reaches 40.');
    final benchmark = FigureBenchmark(
      loadElements: (pageId) async => pageId == 1
          ? [box('qa', 'Q: What is the value in Q3?\nA: 40'), shape]
          : [box('note', 'A page with no question'), shape],
      readPage: (elements) async {
        read = elements;
        return const PageContent(
            recognizedInkText: '', typedText: '', figures: [revenue]);
      },
      imageOf: (_, _) async => Uint8List.fromList(const [1]),
      pictureOf: (_) async => null,
      answerFromText: (notes, question) async => 'NOT IN NOTES',
      local: local,
      cloud: cloud,
    );

    final status = <String>[];
    final report = await benchmark.run([1, 2], onProgress: status.add);

    expect(read!.map((e) => e.id), ['chart'],
        reason: 'the answer must not be on the page the model reads');
    expect(report.pages.single.pageNumber, 1, reason: 'page 2 has no question');
    expect(report.results.length, 3);
    expect(report.correct(BenchTier.description), 0);
    expect(report.correct(BenchTier.lookLocal), 0);
    expect(report.correct(BenchTier.lookCloud), 1);
    expect(local.prompts.single, contains('What is the value in Q3?'));
    expect(status, isNotEmpty);

    final text = report.toText();
    expect(text, contains('Looking, cloud: 1/1 correct'));
    expect(text, contains('Looking, on device: 0/1 correct'));
    expect(text, contains('want: 40'));
  });

  test('with no cloud the cloud tier is left out, and a failing page does not '
      'stop the run', () async {
    final benchmark = FigureBenchmark(
      loadElements: (_) async => [box('qa', 'Q: What is shown?\nA: revenue')],
      readPage: (_) async => throw StateError('model gone'),
      imageOf: (_, _) async => null,
      pictureOf: (_) async => null,
      answerFromText: (_, _) async => throw StateError('model gone'),
      local: _Model('unused'),
    );
    final report = await benchmark.run([1]);
    expect(report.tiers, [BenchTier.description, BenchTier.lookLocal]);
    expect(report.pages.single.error, contains('model gone'));
    expect(report.results.every((r) => !r.correct), isTrue);
  });
}
