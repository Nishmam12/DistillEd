// Text on page pictures, end to end through the canvas: the select tool's Text
// mode selects words, a highlighter over printed words snaps to them (and undo
// brings the stroke back), and the text bar's Copy, Highlight and Search.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/data/persistence/page_text_store.dart';
import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/model/page_words.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/state/editor_tool_controller.dart';
import 'package:margo/editor/state/history_controller.dart';
import 'package:margo/editor/state/page_notifier.dart';
import 'package:margo/editor/state/page_text_selection.dart';
import 'package:margo/editor/state/scene_controller.dart';
import 'package:margo/editor/ui/scene_canvas.dart';
import 'package:margo/features/import/page_words_service.dart';
import 'package:margo/features/notebook/presentation/controls/text_selection_bar.dart';

import '../state/page_notifier_test.dart' show FakePageRepository;

const ScenePageKey _key = (notebookId: 0, pageId: 0);

/// The picture covers 0..700 x 0..500 on the page (the canvas starts at 1:1).
const _image = ImageElement(
  id: 'pdf',
  zOrder: 0,
  geometryData: [0, 0, 700, 500],
  relativeImagePath: 'notes/0/imports/p.png',
  isLocked: true,
);

/// "Cell division" on one line at y 100..120, "makes two cells" below it at
/// y 140..160.
const _words = PageWords(source: PageWordsSource.pdf, words: [
  PageWord(text: 'Cell', box: Rect.fromLTRB(0.1, 0.2, 0.2, 0.24), line: 0),
  PageWord(text: 'division', box: Rect.fromLTRB(0.22, 0.2, 0.4, 0.24), line: 0),
  PageWord(text: 'makes', box: Rect.fromLTRB(0.1, 0.28, 0.2, 0.32), line: 1),
  PageWord(text: 'two', box: Rect.fromLTRB(0.22, 0.28, 0.28, 0.32), line: 1),
  PageWord(text: 'cells', box: Rect.fromLTRB(0.3, 0.28, 0.4, 0.32), line: 1),
]);

class _Words implements PageWordsService {
  @override
  String get docsDir => '';
  @override
  OcrWordsReader get readWords => (_) async => _words;
  @override
  PageWords? cached(String relativeImagePath) => _words;
  @override
  Future<PageWords> wordsFor(String relativeImagePath) async => _words;
}

Future<ProviderContainer> _scene(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(retry: (_, _) => null, overrides: [
    sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
    pageWordsServiceProvider.overrideWithValue(_Words()),
  ]);
  addTearDown(container.dispose);
  await container.read(sceneControllerProvider(_key).notifier).addMany([_image]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(body: SceneCanvas(notebookId: 0, pageId: 0)),
    ),
  ));
  await tester.pump();
  return container;
}

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.startGesture(from, kind: PointerDeviceKind.stylus);
  for (var i = 1; i <= 6; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 6)!);
  }
  await g.up();
  await tester.pump();
  await tester.pump();
}

void main() {
  group('Text mode of the select tool', () {
    testWidgets('a drag across the words selects them, in reading order',
        (tester) async {
      final c = await _scene(tester);
      c.read(editorToolProvider.notifier)
        ..setTool(EditorTool.select)
        ..setSelectText(true);
      await tester.pump();

      // From "division" back to "makes".
      await _drag(tester, const Offset(200, 110), const Offset(100, 150));

      final sel = c.read(pageTextSelectionProvider);
      expect(sel, isNotNull);
      expect(sel!.text, 'division\nmakes');
      // Nothing was moved or selected as an element.
      expect(c.read(sceneControllerProvider(_key)).single, _image);
    });

    testWidgets('a drag away from the picture selects nothing', (tester) async {
      final c = await _scene(tester);
      c.read(editorToolProvider.notifier)
        ..setTool(EditorTool.select)
        ..setSelectText(true);
      await tester.pump();
      await _drag(tester, const Offset(750, 550), const Offset(780, 580));
      expect(c.read(pageTextSelectionProvider), isNull);
    });

    testWidgets('Rectangle and Lasso leave Text mode', (tester) async {
      final c = await _scene(tester);
      final ctl = c.read(editorToolProvider.notifier)..setSelectText(true);
      ctl.setSelectLasso(true);
      expect(c.read(editorToolProvider).selectText, isFalse);
    });
  });

  group('highlighter snapping', () {
    Future<void> highlightAcross(WidgetTester tester, ProviderContainer c) async {
      c.read(editorToolProvider.notifier).setPenKind(PenKind.highlighter);
      await tester.pump();
      // A wobbly stroke along "Cell division".
      final g = await tester.startGesture(const Offset(66, 112),
          kind: PointerDeviceKind.stylus);
      for (final p in const [
        Offset(110, 109), Offset(160, 113), Offset(220, 108), Offset(285, 111),
      ]) {
        await g.moveTo(p);
      }
      await g.up();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a stroke over printed words becomes a clean mark over them',
        (tester) async {
      final c = await _scene(tester);
      await highlightAcross(tester, c);

      final strokes = c
          .read(sceneControllerProvider(_key))
          .whereType<FreehandElement>()
          .toList();
      expect(strokes, hasLength(1));
      final mark = strokes.single;
      expect(mark.penKind, PenKind.highlighter);
      // Straight along the middle of the line (y 110), from "Cell" to
      // "division", as tall as the line.
      expect(mark.points.every((p) => (p.y - 110).abs() < 0.01), isTrue);
      expect(mark.points.first.x, greaterThanOrEqualTo(70));
      expect(mark.points.last.x, lessThanOrEqualTo(280));
      expect(mark.size, closeTo(20 * 1.15, 0.01));

      // One undo brings back the stroke as drawn.
      c.read(historyProvider(_key).notifier).undo();
      await tester.pump();
      final back = c
          .read(sceneControllerProvider(_key))
          .whereType<FreehandElement>()
          .single;
      expect(back.points.any((p) => (p.y - 110).abs() > 0.5), isTrue);
    });

    testWidgets('with the setting off the stroke stays as drawn',
        (tester) async {
      final c = await _scene(tester);
      await c.read(settingsProvider.notifier).setSnapHighlighter(false);
      await highlightAcross(tester, c);
      final stroke = c
          .read(sceneControllerProvider(_key))
          .whereType<FreehandElement>()
          .single;
      expect(stroke.points.any((p) => (p.y - 110).abs() > 0.5), isTrue);
    });

    testWidgets('a highlighter stroke away from the words stays as drawn',
        (tester) async {
      final c = await _scene(tester);
      c.read(editorToolProvider.notifier).setPenKind(PenKind.highlighter);
      await tester.pump();
      await _drag(tester, const Offset(400, 400), const Offset(600, 410));
      final stroke = c
          .read(sceneControllerProvider(_key))
          .whereType<FreehandElement>()
          .single;
      expect(stroke.points.first.y, closeTo(400, 0.5));
    });
  });

  group('the text bar', () {
    Future<ProviderContainer> bar(WidgetTester tester,
        {ValueChanged<String>? onAsk, ValueChanged<int>? onJump}) async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakePageRepository();
      final texts = InMemoryPageTextStore();
      final container = ProviderContainer(retry: (_, _) => null, overrides: [
        sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
        pageRepositoryProvider.overrideWithValue(repo),
        pageTextStoreProvider.overrideWithValue(texts),
      ]);
      addTearDown(container.dispose);
      final pages = container.read(pageProvider(0).notifier);
      await pages.initialize();
      await pages.insertPage();
      final ids = [for (final p in container.read(pageProvider(0)).pages) p.id];
      await texts.save(notebookId: 0, pageId: ids[0], text: 'Intro');
      await texts.save(
          notebookId: 0, pageId: ids[1], text: 'Recap: cell\ndivision again');
      await container
          .read(sceneControllerProvider(_key).notifier)
          .addMany([_image]);
      container.read(editorToolProvider.notifier)
        ..setTool(EditorTool.select)
        ..setSelectText(true);
      container.read(pageTextSelectionProvider.notifier).state =
          const PageTextSelection(
              key: _key, imageId: 'pdf', words: _words, indexes: [0, 1, 2]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: TextSelectionBar(
                pageKey: _key,
                onAsk: onAsk ?? (_) {},
                onJump: onJump ?? (_) {},
              ),
            ),
          ),
        ),
      ));
      return container;
    }

    testWidgets('Copy puts the words on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await bar(tester);
      await tester.tap(find.byKey(const Key('textCopy')));
      await tester.pump();
      expect(copied, 'Cell division\nmakes');
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Highlight lays one mark per line, as one undo step',
        (tester) async {
      final c = await bar(tester);
      await tester.tap(find.byKey(const Key('textHighlight')));
      await tester.pump();
      final marks = c
          .read(sceneControllerProvider(_key))
          .whereType<FreehandElement>()
          .toList();
      expect(marks, hasLength(2));
      expect(marks.every((m) => m.penKind == PenKind.highlighter), isTrue);
      expect(c.read(pageTextSelectionProvider), isNull);

      c.read(historyProvider(_key).notifier).undo();
      expect(
          c.read(sceneControllerProvider(_key)).whereType<FreehandElement>(),
          isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Ask hands the words to the editor', (tester) async {
      String? asked;
      await bar(tester, onAsk: (t) => asked = t);
      await tester.tap(find.byKey(const Key('textAsk')));
      await tester.pump();
      expect(asked, 'Cell division\nmakes');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Search lists the pages that mention the words',
        (tester) async {
      int? jumped;
      final c = await bar(tester, onJump: (id) => jumped = id);
      c.read(pageTextSelectionProvider.notifier).state =
          const PageTextSelection(
              key: _key, imageId: 'pdf', words: _words, indexes: [0, 1]);
      await tester.pump();
      await tester.tap(find.byKey(const Key('textSearch')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 page mention'), findsOneWidget);
      final second = c.read(pageProvider(0)).pages[1].id;
      await tester.tap(find.byKey(Key('searchHit_$second')));
      await tester.pumpAndSettle();
      expect(jumped, second);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('hidden outside the Text mode', (tester) async {
      final c = await bar(tester);
      c.read(editorToolProvider.notifier).setTool(EditorTool.pen);
      await tester.pump();
      expect(find.byKey(const Key('textSelectionBar')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
