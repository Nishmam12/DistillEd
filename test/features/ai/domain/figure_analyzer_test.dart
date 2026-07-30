import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_exception.dart';
import 'package:inkflow/features/ai/domain/figure.dart';
import 'package:inkflow/features/ai/domain/figure_analyzer.dart';
import 'package:inkflow/features/ai/domain/image_transcriber.dart';
import 'package:inkflow/features/ai/domain/page_content.dart';

/// Replies with a scripted string (the last is reused once exhausted), or
/// throws [throwError] on every call.
class ScriptedTranscriber implements ImageTranscriber {
  final List<String> replies;
  final Object? throwError;
  int calls = 0;
  final prompts = <String>[];

  ScriptedTranscriber(this.replies, {this.throwError});

  @override
  Future<String> transcribeImage(
    Uint8List imageBytes, {
    required String prompt,
    double temperature = 0.0,
    int maxOutputTokens = 1024,
    int? randomSeed,
  }) async {
    prompts.add(prompt);
    if (throwError != null) throw throwError!;
    final reply = calls < replies.length ? replies[calls] : replies.last;
    calls++;
    return reply;
  }
}

final _bytes = Uint8List.fromList([1, 2, 3]);

/// A well-formed, confident chart reading — the "local model did fine" case.
String _goodChartJson({double confidence = 0.9}) => jsonEncode({
      'kind': 'chart',
      'title': 'Quarterly revenue',
      'summary': 'A bar chart of revenue across the four quarters of 2024.',
      'axes': ['x: quarter (Q1-Q4)', 'y: revenue in thousands'],
      'series': [
        {'label': 'Revenue', 'detail': 'rises from 2 to 9'}
      ],
      'insight': 'Revenue roughly quadruples over the year.',
      'verbatim_text': 'Q1 2\nQ2 4\nQ3 7\nQ4 9',
      'confidence': confidence,
    });

void main() {
  group('parseFigureJson', () {
    test('reads a well-formed object into every field', () {
      final figure =
          FigureAnalyzer.parseFigureJson(_goodChartJson(), modelId: 'local-x')!;

      expect(figure.kind, FigureKind.chart);
      expect(figure.title, 'Quarterly revenue');
      expect(figure.axes, hasLength(2));
      expect(figure.series.single.label, 'Revenue');
      expect(figure.series.single.detail, 'rises from 2 to 9');
      expect(figure.insight, 'Revenue roughly quadruples over the year.');
      expect(figure.confidence, 0.9);
      expect(figure.modelId, 'local-x');
    });

    test('returns null for the "no figure here" reply', () {
      expect(FigureAnalyzer.parseFigureJson('{"kind": "none"}'), isNull);
    });

    test('survives markdown fences and chatty preamble', () {
      final raw = 'Sure! Here is the analysis:\n```json\n'
          '${_goodChartJson()}\n```\nLet me know if you need more.';
      expect(FigureAnalyzer.parseFigureJson(raw)?.kind, FigureKind.chart);
    });

    test('does not end the object early on a brace inside a string', () {
      final raw = jsonEncode({
        'kind': 'chart',
        'summary': 'Cost in {USD} plotted against time',
        'insight': 'costs climb steadily',
      });
      final figure = FigureAnalyzer.parseFigureJson(raw)!;
      expect(figure.summary, 'Cost in {USD} plotted against time');
    });

    test('maps unofficial kind names onto the enum', () {
      expect(
        FigureAnalyzer.parseFigureJson(
            '{"kind":"flowchart","summary":"boxes and arrows for the process"}')
            ?.kind,
        FigureKind.diagram,
      );
      expect(
        FigureAnalyzer.parseFigureJson(
            '{"kind":"histogram","summary":"a distribution of student scores"}')
            ?.kind,
        FigureKind.chart,
      );
    });

    test('normalises a percentage confidence and defaults a missing one', () {
      expect(
        FigureAnalyzer.parseFigureJson(
                '{"kind":"chart","summary":"a chart of things","confidence":85}')
            ?.confidence,
        closeTo(0.85, 1e-9),
      );
      expect(
        FigureAnalyzer.parseFigureJson(
                '{"kind":"chart","summary":"a chart of things"}')
            ?.confidence,
        0.5,
      );
    });

    test('rejects a reply with no JSON and one with no prose', () {
      expect(FigureAnalyzer.parseFigureJson('I cannot see an image.'), isNull);
      expect(FigureAnalyzer.parseFigureJson('{"kind":"chart"}'), isNull);
    });

    test('accepts a series given as bare strings or under "name"', () {
      final raw = jsonEncode({
        'kind': 'diagram',
        'summary': 'The stages of mitosis, connected in order.',
        'series': [
          'Prophase',
          {'name': 'Anaphase', 'detail': 'chromatids separate'},
        ],
      });
      final figure = FigureAnalyzer.parseFigureJson(raw)!;
      expect(figure.series.map((s) => s.label), ['Prophase', 'Anaphase']);
      expect(figure.series.last.detail, 'chromatids separate');
    });
  });

  group('local-first routing', () {
    test('keeps a good local read and never touches the cloud', () async {
      final local = ScriptedTranscriber([_goodChartJson()]);
      final cloud = ScriptedTranscriber([_goodChartJson()]);
      final analyzer = FigureAnalyzer(
        local: local,
        cloud: cloud,
        // Even with escalation permitted, a good local read must stay local.
        canEscalate: () async => true,
        localModelId: 'local-x',
      );

      final figure = await analyzer.analyze(_bytes);

      expect(figure?.modelId, 'local-x');
      expect(cloud.calls, 0, reason: 'a good local read must not leave the device');
    });

    test('escalates an unconfident local read', () async {
      final local = ScriptedTranscriber([_goodChartJson(confidence: 0.2)]);
      final cloud = ScriptedTranscriber([_goodChartJson(confidence: 0.95)]);
      final analyzer = FigureAnalyzer(
        local: local,
        cloud: cloud,
        canEscalate: () async => true,
        cloudModelId: 'cloud-x',
      );

      final figure = await analyzer.analyze(_bytes);

      expect(cloud.calls, 1);
      expect(figure?.modelId, 'cloud-x');
    });

    test('escalates an uninformative local read', () async {
      final local = ScriptedTranscriber(
          ['{"kind":"diagram","summary":"This appears to be a diagram."}']);
      final cloud = ScriptedTranscriber([_goodChartJson()]);
      final analyzer = FigureAnalyzer(
          local: local, cloud: cloud, canEscalate: () async => true);

      final figure = await analyzer.analyze(_bytes);

      expect(cloud.calls, 1);
      expect(figure?.insight, 'Revenue roughly quadruples over the year.');
    });

    test('never escalates when the caller withholds permission', () async {
      final local = ScriptedTranscriber([_goodChartJson(confidence: 0.1)]);
      final cloud = ScriptedTranscriber([_goodChartJson()]);
      final analyzer = FigureAnalyzer(
        local: local,
        cloud: cloud,
        canEscalate: () async => false,
        localModelId: 'local-x',
      );

      final figure = await analyzer.analyze(_bytes);

      expect(cloud.calls, 0, reason: 'cloud opt-in is off — nothing may be sent');
      // The shaky-but-real local read is still better than nothing.
      expect(figure?.modelId, 'local-x');
    });

    test('defaults to never escalating when no policy is supplied', () async {
      final local = ScriptedTranscriber([_goodChartJson(confidence: 0.1)]);
      final cloud = ScriptedTranscriber([_goodChartJson()]);

      await FigureAnalyzer(local: local, cloud: cloud).analyze(_bytes);

      expect(cloud.calls, 0);
    });

    test('keeps the local read when the cloud call fails', () async {
      final local = ScriptedTranscriber([_goodChartJson(confidence: 0.2)]);
      final cloud = ScriptedTranscriber(const [],
          throwError: const AiUnavailableException('gateway down'));
      final analyzer = FigureAnalyzer(
        local: local,
        cloud: cloud,
        canEscalate: () async => true,
        localModelId: 'local-x',
      );

      final figure = await analyzer.analyze(_bytes);

      expect(figure?.modelId, 'local-x');
    });

    test('drops an unusable read rather than inventing a figure', () async {
      final local = ScriptedTranscriber(['{"kind":"none"}']);
      final analyzer = FigureAnalyzer(local: local);

      expect(await analyzer.analyze(_bytes), isNull);
    });

    test('rethrows a missing local model so the caller can offer the download',
        () async {
      final local = ScriptedTranscriber(const [],
          throwError: const AiModelNotReadyException('not downloaded'));

      expect(
        () => FigureAnalyzer(local: local).analyze(_bytes),
        throwsA(isA<AiModelNotReadyException>()),
      );
    });

    test('a failed local run escalates instead of erroring', () async {
      final local = ScriptedTranscriber(const [],
          throwError: const AiGenerationException('decode failed'));
      final cloud = ScriptedTranscriber([_goodChartJson()]);
      final analyzer = FigureAnalyzer(
          local: local, cloud: cloud, canEscalate: () async => true);

      expect((await analyzer.analyze(_bytes))?.kind, FigureKind.chart);
      expect(cloud.calls, 1);
    });
  });

  group('prompt rendering', () {
    test('labels the figure and folds in every populated part', () {
      final figure = FigureAnalyzer.parseFigureJson(_goodChartJson())!;
      final block = figure.toPromptBlock(index: 2);

      expect(block, startsWith('[Figure 2 — chart: Quarterly revenue]'));
      expect(block, contains('Axes: x: quarter (Q1-Q4); y: revenue in thousands'));
      expect(block, contains('Series: Revenue: rises from 2 to 9'));
      expect(block, contains('Shows: Revenue roughly quadruples over the year.'));
    });

    test('omits absent parts instead of emitting empty labels', () {
      const figure = FigureDescription(
        kind: FigureKind.equation,
        summary: 'The quadratic formula, written out in full.',
      );
      final block = figure.toPromptBlock();

      expect(block, '[Figure — equation]\n'
          'The quadratic formula, written out in full.');
    });
  });

  group('PageContent figure plumbing', () {
    final figure = FigureAnalyzer.parseFigureJson(_goodChartJson())!;

    test('appends figures to the prompt text but not to the written text', () {
      final content = PageContent(
        recognizedInkText: 'Revenue notes',
        typedText: '',
        figures: [figure],
      );

      expect(content.combinedText, 'Revenue notes');
      expect(content.combinedTextWithFigures, startsWith('Revenue notes\n\n['));
      expect(content.combinedTextWithFigures, contains('Quarterly revenue'));
      expect(content.hasFigures, isTrue);
    });

    test('a page that is nothing but a graph still has prompt text', () {
      final content = PageContent(
        recognizedInkText: '',
        typedText: '',
        figures: [figure],
      );

      // The regression this whole feature exists to fix: no words, but the
      // page is not empty to the AI.
      expect(content.combinedText, isEmpty);
      expect(content.combinedTextWithFigures, isNotEmpty);
    });

    test('numbers multiple figures and leaves a lone one unnumbered', () {
      final two = PageContent(
        recognizedInkText: '',
        typedText: '',
        figures: [figure, figure],
      );
      expect(two.figureBlocks, contains('[Figure 1 —'));
      expect(two.figureBlocks, contains('[Figure 2 —'));

      final one =
          PageContent(recognizedInkText: '', typedText: '', figures: [figure]);
      expect(one.figureBlocks, contains('[Figure —'));
    });

    test('no figures leaves the prompt text byte-identical', () {
      const content =
          PageContent(recognizedInkText: 'just words', typedText: 'and more');
      expect(content.combinedTextWithFigures, content.combinedText);
    });
  });
}
