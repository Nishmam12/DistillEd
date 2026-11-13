// The "Figures on this page" strip (docs: roadmap D2 step 6).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/data/persistence/page_text_store.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:margo/features/ai/domain/figure.dart';
import 'package:margo/features/ai/domain/figure_analyzer.dart';
import 'package:margo/features/ai/domain/image_transcriber.dart';
import 'package:margo/features/ai/domain/page_content_extractor.dart';
import 'package:margo/features/ai/domain/read_cache.dart';
import 'package:margo/features/ai/domain/scene_graph_figure.dart';
import 'package:margo/features/ai/presentation/ai_providers.dart';
import 'package:margo/features/ai/presentation/page_figures.dart';
import 'package:margo/features/ai/presentation/sidebar/ai_figures_strip.dart';

class _Model implements ImageTranscriber {
  _Model(this.replies);
  final List<String> replies;
  int calls = 0;

  @override
  Future<String> transcribeImage(Uint8List imageBytes,
      {required String prompt,
      double temperature = 0.0,
      int maxOutputTokens = 1024,
      int? randomSeed}) async {
    final reply = replies[calls < replies.length ? calls : replies.length - 1];
    calls++;
    return reply;
  }
}

String _chart(String title) => jsonEncode({
      'kind': 'chart',
      'title': title,
      'summary': 'A bar chart of ${title.toLowerCase()} over four quarters.',
      'insight': '$title changes.',
      'confidence': 0.9,
    });

const drawn = FigureDescription(
  kind: FigureKind.chart,
  title: 'Revenue',
  summary: 'A bar chart of revenue over four quarters.',
  insight: 'Revenue rises.',
  modelId: 'local',
  grounding: 0.0,
  bounds: Rect.fromLTRB(0, 0, 200, 100),
  pinKey: 'pin|abc|pin1|any',
);
const exact = FigureDescription(
  kind: FigureKind.diagram,
  summary: 'A diagram of 2 labelled boxes joined by 1 arrow: A → B.',
  modelId: kSceneGraphModelId,
  grounding: 1.0,
);

void main() {
  const key = (notebookId: 1, pageId: 1);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('carryFigures: a light read keeps what a deep read found', () {
    final after = carryFigures([drawn, exact], [exact], deep: false);
    expect(after, [exact, drawn]);
    expect(carryFigures([drawn, exact], [exact], deep: true), [exact]);
    expect(carryFigures([drawn], const [], deep: false), [drawn]);
  });

  test('who read it, in plain words', () {
    expect(figureReaderLabel(exact, localModelId: 'local'), 'Read exactly');
    expect(figureReaderLabel(drawn, localModelId: 'local'), 'Read on device');
    expect(figureReaderLabel(drawn.copyWith(modelId: 'gateway-mid'),
        localModelId: 'local'), 'Read by cloud AI');
    expect(
        figureReaderLabel(drawn.correctedTo(title: '', summary: 'x'),
            localModelId: 'local'),
        'Your description');
  });

  /// [figures] null shows what a real read of the page finds (one drawing,
  /// read as "Revenue"; a second read of it says "Costs").
  Future<(ProviderContainer, _Model)> pump(
      WidgetTester tester, List<FigureDescription>? figures) async {
    final model = _Model([_chart('Revenue'), _chart('Costs')]);
    final analyzer = FigureAnalyzer(local: model);
    final extractor = PageContentExtractor(
      loadElements: (_) async => const [
        SceneShapeElement(
          id: 'a',
          zOrder: 0,
          shapeType: ShapeType.rectangle,
          geometryData: [10, 10, 110, 60],
          color: 0xFF000000,
          strokeWidth: 2,
        ),
      ],
      recognition: HandwritingRecognitionService(),
      // Not a real picture: the card falls back to its icon.
      renderInk: (els) async => Uint8List.fromList(utf8.encode('png')),
      figureAnalyzer: analyzer,
      readCache: InMemoryReadCache(),
    );
    final container = ProviderContainer(overrides: [
      pageContentExtractorProvider.overrideWithValue(extractor),
      figureAnalyzerProvider.overrideWithValue(analyzer),
      pageTextStoreProvider.overrideWithValue(InMemoryPageTextStore()),
    ]);
    // Disposed before the test ends, so the index's idle timer goes with it.
    addTearDown(container.dispose);
    container.read(pageFiguresProvider(1).notifier).state = figures ??
        (await extractor.extractPage(1, languageCode: 'en', useVision: true))
            .figures;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AiFiguresStrip(pageKey: key)),
        ),
      ),
    ));
    await tester.pump();
    return (container, model);
  }

  testWidgets('nothing is shown for a page with no figures', (tester) async {
    await pump(tester, const []);
    expect(find.text('FIGURES ON THIS PAGE'), findsNothing);
  });

  testWidgets('each figure shows its reading, who read it and any doubt',
      (tester) async {
    await pump(tester, const [drawn, exact]);

    expect(find.text('FIGURES ON THIS PAGE'), findsOneWidget);
    expect(find.text('Revenue'), findsOneWidget);
    expect(find.text('A bar chart of revenue over four quarters.'),
        findsOneWidget);
    expect(find.text('Not confirmed'), findsOneWidget);
    expect(find.text('Read exactly'), findsOneWidget);
    // The exact one offers nothing to change; the other does.
    expect(find.text('Re-read'), findsOneWidget);
    expect(find.text('Fix it'), findsOneWidget);
    // Cloud AI is off by default, so it is not offered.
    expect(find.text('Ask the cloud'), findsNothing);
  });

  testWidgets('Fix it replaces the reading with the student\'s words',
      (tester) async {
    final (container, _) = await pump(tester, null);

    await tester.tap(find.text('Fix it'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'What it shows'),
        'Profit by quarter, not revenue.');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final figure = container.read(pageFiguresProvider(1)).single;
    expect(figure.modelId, kUserFigureModelId);
    expect(figure.summary, 'Profit by quarter, not revenue.');
    expect(find.text('Profit by quarter, not revenue.'), findsOneWidget);
    expect(find.text('Your description'), findsOneWidget);
    container.dispose();
  });

  testWidgets('Re-read asks the model again and shows the new reading',
      (tester) async {
    final (container, model) = await pump(tester, null);
    expect(find.text('Revenue'), findsOneWidget);

    await tester.tap(find.text('Re-read'));
    await tester.pumpAndSettle();

    expect(model.calls, 2, reason: 'the new reading is kept, not read again');
    expect(container.read(pageFiguresProvider(1)).single.title, 'Costs');
    expect(find.text('Costs'), findsOneWidget);
    container.dispose();
  });
}
