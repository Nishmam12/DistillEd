import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/state/history_controller.dart';
import 'package:margo/editor/state/scene_controller.dart';
import 'package:margo/editor/state/selection_controller.dart';
import 'package:margo/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:margo/features/ai/domain/recognition_result.dart';
import 'package:margo/features/ai/presentation/ai_providers.dart';
import 'package:margo/features/notebook/domain/handwriting_conversion.dart';
import 'package:margo/features/notebook/presentation/controls/selection_bar.dart';

FreehandElement ink(String id, List<(double, double)> pts,
        {int color = 0xFF1565C0}) =>
    FreehandElement(
      id: id,
      zOrder: 0,
      color: color,
      size: 2,
      points: [for (final (x, y) in pts) StrokePoint(x: x, y: y, pressure: 1)],
    );

/// A wiggly stroke along y = y0 + slope·x, from x0 to x1.
FreehandElement writing(String id, double x0, double x1, double y0,
    {double slope = 0}) {
  final pts = <(double, double)>[];
  for (var x = x0; x <= x1; x += 4) {
    final wiggle = ((x / 4).round().isEven ? 6.0 : -6.0);
    pts.add((x, y0 + slope * (x - x0) + wiggle));
  }
  return ink(id, pts);
}

Rect boundsOf(FreehandElement e) {
  final xs = e.points.map((p) => p.x), ys = e.points.map((p) => p.y);
  return Rect.fromLTRB(xs.reduce(math.min), ys.reduce(math.min),
      xs.reduce(math.max), ys.reduce(math.max));
}

RecognizedInkLine lineOf(String text, List<FreehandElement> strokes,
        {double score = 1}) =>
    RecognizedInkLine(
      text: text,
      segmentScores: [score],
      bounds: strokes.map(boundsOf).reduce((a, b) => a.expandToInclude(b)),
      strokes: [for (final s in strokes) s.points],
    );

/// ML Kit stand-in: reads each element as the text it was given.
class _FakeRecognition implements HandwritingRecognitionService {
  final List<RecognizedInkLine> Function(List<FreehandElement> ink) read;
  _FakeRecognition(this.read);

  @override
  Future<void> ensureModelDownloaded(String languageCode) async {}

  @override
  Future<List<RecognizedInkLine>> recognizeInkLines(
          List<SceneElement> elements, String languageCode,
          {Object? writingArea}) async =>
      read(elements.whereType<FreehandElement>().toList());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('conversion lines', () {
    test('lines are matched back to their strokes by identity', () {
      final a = writing('a', 0, 100, 0), b = writing('b', 0, 100, 60);
      final lines = conversionLines(
          [lineOf('first', [a]), lineOf('second', [b])], [a, b]);
      expect(lines.map((l) => l.strokes.single.id), ['a', 'b']);
      expect(lines.map((l) => l.text), ['first', 'second']);
    });

    test('symbol soup and poor scores are marked unsure', () {
      final a = writing('a', 0, 100, 0), b = writing('b', 0, 100, 60);
      final lines = conversionLines([
        lineOf('::::::', [a]),
        lineOf('clearly words', [b]),
      ], [a, b]);
      expect(lines.first.unsure, isTrue);
      expect(lines.last.unsure, isFalse);
    });
  });

  group('converting', () {
    var n = 0;
    String id() => 'new${n++}';

    test('one text box per line, where it was written, in its ink colour', () {
      final a = writing('a', 40, 240, 100);
      final lines = conversionLines([lineOf('hello', [a])], [a]);
      final r = convertLines(lines, ['hello'],
          keepInk: false, newId: id, firstZOrder: 10);
      final t = r.added.single;
      final b = lines.single.bounds;
      expect(t.text, 'hello');
      expect(t.geometryData.take(2), [b.left, b.top]);
      expect(t.geometryData[2] - t.geometryData[0],
          greaterThanOrEqualTo(b.width));
      expect(t.color, 0xFF1565C0);
      expect(t.fontSize, fontSizeForLine(b.height));
      expect(t.zOrder, 10);
      expect(r.removed.map((e) => e.id), ['a']);
    });

    test('a blank line keeps its ink; keeping the handwriting removes none',
        () {
      final a = writing('a', 0, 100, 0), b = writing('b', 0, 100, 60);
      final lines =
          conversionLines([lineOf('kept', [a]), lineOf('', [b])], [a, b]);
      final r = convertLines(lines, ['kept', '  '],
          keepInk: false, newId: id, firstZOrder: 0);
      expect(r.added, hasLength(1));
      expect(r.removed.map((e) => e.id), ['a']);

      final kept = convertLines(lines, ['kept', ''],
          keepInk: true, newId: id, firstZOrder: 0);
      expect(kept.added, hasLength(1));
      expect(kept.removed, isEmpty);
    });

    test('the edited text is what is used', () {
      final a = writing('a', 0, 100, 0);
      final lines = conversionLines([lineOf('helo', [a])], [a]);
      final r = convertLines(lines, ['hello'],
          keepInk: false, newId: id, firstZOrder: 0);
      expect(r.added.single.text, 'hello');
    });
  });

  group('levelling', () {
    double slopeOf(List<FreehandElement> strokes) {
      final pts = [for (final s in strokes) ...s.points];
      final mx = pts.map((p) => p.x).reduce((a, b) => a + b) / pts.length;
      final my = pts.map((p) => p.y).reduce((a, b) => a + b) / pts.length;
      var sxx = 0.0, sxy = 0.0;
      for (final p in pts) {
        sxx += (p.x - mx) * (p.x - mx);
        sxy += (p.x - mx) * (p.y - my);
      }
      return sxy / sxx;
    }

    test('a slanted line comes out level, about its own centre', () {
      final a = writing('a', 0, 300, 100, slope: 0.15);
      final out = levelHandwriting([a]);
      expect(out.single.id, 'a');
      expect(slopeOf(out), closeTo(0, 0.01));
      final before = boundsOf(a).center, after = boundsOf(out.single).center;
      expect((before - after).distance, lessThan(8));
    });

    test('writing that is already level is left alone', () {
      expect(levelHandwriting([writing('a', 0, 300, 100, slope: 0.01)]),
          isEmpty);
    });

    test('a steep label and a tall mark are not taken for slanted lines', () {
      expect(levelHandwriting([writing('a', 0, 200, 0, slope: 1.2)]), isEmpty);
      expect(levelHandwriting([ink('tall', [(0, 0), (2, 100), (4, 200)])]),
          isEmpty);
    });
  });

  group('from the selection bar', () {
    const key = (notebookId: 0, pageId: 0);
    late ProviderContainer container;

    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpBar(WidgetTester tester, List<FreehandElement> els,
        List<RecognizedInkLine> Function(List<FreehandElement>) read) async {
      container = ProviderContainer(retry: (_, _) => null, overrides: [
        sceneElementStoreProvider
            .overrideWithValue(InMemorySceneElementStore()),
        handwritingRecognitionServiceProvider
            .overrideWithValue(_FakeRecognition(read)),
      ]);
      addTearDown(container.dispose);
      await container.read(sceneControllerProvider(key).notifier).addMany(els);
      container.read(selectionProvider.notifier).selectMany(els.map((e) => e.id));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SelectionBar(pageKey: key))),
      ));
    }

    List<SceneElement> scene() => container.read(sceneControllerProvider(key));

    testWidgets('convert: check, edit, convert; one undo brings the ink back',
        (tester) async {
      final a = writing('a', 0, 200, 100), b = writing('b', 0, 200, 160);
      await pumpBar(tester, [a, b],
          (i) => [lineOf('helo', [a]), lineOf('::::', [b], score: 50)]);

      await tester.tap(find.byKey(const ValueKey('convertHandwriting')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('convertUnsure1')), findsOneWidget,
          reason: 'the doubtful line is marked');
      expect(find.byKey(const ValueKey('convertUnsure0')), findsNothing);

      await tester.enterText(
          find.byKey(const ValueKey('convertLine0')), 'hello');
      await tester.enterText(find.byKey(const ValueKey('convertLine1')), '');
      await tester.tap(find.byKey(const ValueKey('convertConfirm')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      final texts = scene().whereType<TextElement>().toList();
      expect(texts.single.text, 'hello');
      expect(scene().whereType<FreehandElement>().map((e) => e.id), ['b'],
          reason: 'the converted line is gone, the blank one stays as ink');
      expect(container.read(selectionProvider), {texts.single.id});

      container.read(historyProvider(key).notifier).undo();
      await tester.pump(const Duration(seconds: 5));
      expect(scene().whereType<TextElement>(), isEmpty);
      expect(scene().whereType<FreehandElement>(), hasLength(2));
    });

    testWidgets('keeping the handwriting adds the text over the ink',
        (tester) async {
      final a = writing('a', 0, 200, 100);
      await pumpBar(tester, [a], (i) => [lineOf('notes', [a])]);
      await tester.tap(find.byKey(const ValueKey('convertHandwriting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('convertKeepInk')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('convertConfirm')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      expect(scene().whereType<FreehandElement>(), hasLength(1));
      expect(scene().whereType<TextElement>().single.text, 'notes');
    });

    testWidgets('cancelling changes nothing', (tester) async {
      final a = writing('a', 0, 200, 100);
      await pumpBar(tester, [a], (i) => [lineOf('notes', [a])]);
      await tester.tap(find.byKey(const ValueKey('convertHandwriting')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      expect(scene().single.id, 'a');
      expect(container.read(historyProvider(key)).canUndo, isFalse);
    });

    testWidgets('straighten levels slanted writing, as one undo step',
        (tester) async {
      final a = writing('a', 0, 300, 100, slope: 0.15);
      await pumpBar(tester, [a], (i) => const []);
      await tester.tap(find.byKey(const ValueKey('levelHandwriting')));
      await tester.pump(const Duration(seconds: 5));
      final after = scene().single as FreehandElement;
      expect(after.points, isNot(a.points));
      container.read(historyProvider(key).notifier).undo();
      await tester.pump(const Duration(seconds: 5));
      expect((scene().single as FreehandElement).points.first.y,
          a.points.first.y);
    });

    testWidgets('level writing says so and changes nothing', (tester) async {
      final a = writing('a', 0, 300, 100);
      await pumpBar(tester, [a], (i) => const []);
      await tester.tap(find.byKey(const ValueKey('levelHandwriting')));
      await tester.pump();
      expect(find.text('This writing is already level.'), findsOneWidget);
      expect(container.read(historyProvider(key)).canUndo, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
