// Typing text straight onto the page (finding 11 of the first device test),
// through the real canvas, pointer pipeline and history.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/render/scene_static_layer.dart';
import 'package:margo/editor/state/editor_tool_controller.dart';
import 'package:margo/editor/state/history_controller.dart';
import 'package:margo/editor/state/inline_text_request.dart';
import 'package:margo/editor/state/scene_controller.dart';
import 'package:margo/editor/state/viewport_controller.dart';
import 'package:margo/editor/ui/scene_canvas.dart';

const ScenePageKey _key = (notebookId: 0, pageId: 0);

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(retry: (_, _) => null, overrides: [
      sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
    ]);
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester, {bool show = true}) {
    return tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          // As the editor: the page does not resize for the keyboard.
          resizeToAvoidBottomInset: false,
          body: show
              ? const SceneCanvas(notebookId: 0, pageId: 0)
              : const SizedBox(),
        ),
      ),
    ));
  }

  List<SceneElement> scene() => container.read(sceneControllerProvider(_key));
  final field = find.byKey(const ValueKey('inlineTextField'));

  Future<void> tapPage(WidgetTester tester, Offset at) async {
    final g = await tester.startGesture(at, kind: PointerDeviceKind.stylus);
    await g.up();
    await tester.pump();
  }

  Future<void> startTyping(WidgetTester tester, Offset at) async {
    await pump(tester);
    container.read(editorToolProvider.notifier).setTool(EditorTool.text);
    await tester.pump();
    await tapPage(tester, at);
  }

  TextElement seedText() => const TextElement(
        id: 't1',
        zOrder: 0,
        geometryData: [100, 100, 300, 130],
        text: 'Old words',
        color: 0xFF000000,
        fontSize: 20,
        fontFamily: 'Roboto',
      );

  Set<String> hiddenOnPage(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<SceneStaticLayer>()
      .single
      .hiddenIds;

  testWidgets('a tap opens a field right there; no dialog', (tester) async {
    await startTyping(tester, const Offset(120, 140));
    expect(field, findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.getTopLeft(field), const Offset(120, 140));
  });

  testWidgets('typing then touching the page elsewhere adds one text, '
      'one undo step', (tester) async {
    await startTyping(tester, const Offset(120, 140));
    await tester.enterText(field, 'Hello page');
    await tapPage(tester, const Offset(500, 400));

    expect(field, findsNothing);
    final t = scene().single as TextElement;
    expect(t.text, 'Hello page');
    expect(t.geometryData.first, 120);
    container.read(historyProvider(_key).notifier).undo();
    expect(scene(), isEmpty);
  });

  testWidgets('the touch that finishes the text draws nothing', (tester) async {
    await startTyping(tester, const Offset(120, 140));
    await tester.enterText(field, 'Hi');
    await tapPage(tester, const Offset(500, 400));
    expect(scene(), hasLength(1), reason: 'no second text opened or added');
    expect(field, findsNothing);
  });

  testWidgets('Done keeps bold and alignment', (tester) async {
    await startTyping(tester, const Offset(120, 140));
    await tester.enterText(field, 'Title');
    await tester.tap(find.byKey(const ValueKey('inlineTextBold')));
    await tester.tap(find.byKey(const ValueKey('inlineTextAlign_center')));
    await tester.tap(find.byKey(const ValueKey('inlineTextDone')));
    await tester.pump();

    final t = scene().single as TextElement;
    expect(t.isBold, isTrue);
    expect(t.align, TextAlignKind.center);
  });

  testWidgets('Escape throws the text away', (tester) async {
    await startTyping(tester, const Offset(120, 140));
    await tester.enterText(field, 'never mind');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(field, findsNothing);
    expect(scene(), isEmpty);
  });

  testWidgets('a field left empty adds nothing', (tester) async {
    await startTyping(tester, const Offset(120, 140));
    await tapPage(tester, const Offset(500, 400));
    expect(scene(), isEmpty);
    expect(container.read(historyProvider(_key)).canUndo, isFalse);
  });

  testWidgets('changing tool finishes the text', (tester) async {
    await startTyping(tester, const Offset(120, 140));
    await tester.enterText(field, 'kept');
    container.read(editorToolProvider.notifier).setTool(EditorTool.pen);
    await tester.pump();
    expect(field, findsNothing);
    expect((scene().single as TextElement).text, 'kept');
  });

  testWidgets('leaving the page with text open keeps it', (tester) async {
    await startTyping(tester, const Offset(120, 140));
    await tester.enterText(field, 'switching page');
    await pump(tester, show: false);
    await tester.pump();
    expect((scene().single as TextElement).text, 'switching page');
  });

  group('an existing text', () {
    Future<void> openForEdit(WidgetTester tester) async {
      await pump(tester);
      await container
          .read(sceneControllerProvider(_key).notifier)
          .addMany([seedText()]);
      await tester.pump();
      container.read(inlineTextEditRequestProvider(_key).notifier).state = 't1';
      await tester.pump();
    }

    testWidgets('"Edit text" opens it on the page, hidden underneath',
        (tester) async {
      await openForEdit(tester);
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, 'Old words');
      expect(hiddenOnPage(tester), contains('t1'),
          reason: 'not drawn twice while it is edited');
      expect(tester.getTopLeft(field), const Offset(100, 100));
    });

    testWidgets('editing updates it in place, one undo brings it back',
        (tester) async {
      await openForEdit(tester);
      await tester.enterText(field, 'New words');
      await tapPage(tester, const Offset(600, 450));

      final t = scene().single as TextElement;
      expect(t.text, 'New words');
      expect(t.geometryData.take(3), [100, 100, 300]);
      expect(hiddenOnPage(tester), isNot(contains('t1')));
      container.read(historyProvider(_key).notifier).undo();
      expect((scene().single as TextElement).text, 'Old words');
    });

    testWidgets('cleared to nothing, it is deleted (undoably)',
        (tester) async {
      await openForEdit(tester);
      await tester.enterText(field, '   ');
      await tapPage(tester, const Offset(600, 450));
      expect(scene(), isEmpty);
      container.read(historyProvider(_key).notifier).undo();
      expect(scene(), hasLength(1));
    });

    testWidgets('unchanged, no undo step is added', (tester) async {
      await openForEdit(tester);
      await tapPage(tester, const Offset(600, 450));
      expect(container.read(historyProvider(_key)).canUndo, isFalse);
      expect((scene().single as TextElement).text, 'Old words');
    });

    testWidgets('a double-tap with the lasso opens it', (tester) async {
      await pump(tester);
      await container
          .read(sceneControllerProvider(_key).notifier)
          .addMany([seedText()]);
      container.read(editorToolProvider.notifier).setTool(EditorTool.select);
      await tester.pump();
      await tapPage(tester, const Offset(150, 115));
      await tapPage(tester, const Offset(150, 115));
      expect(field, findsOneWidget);
    });
  });

  testWidgets('the field follows a zoom', (tester) async {
    await startTyping(tester, const Offset(120, 140));
    await tester.enterText(field, 'zoom me');
    await tester.pump();
    // On screen, so through the zoom (getSize would give the unscaled box).
    double shownWidth() =>
        tester.getBottomRight(field).dx - tester.getTopLeft(field).dx;
    final before = shownWidth();
    final zoom = container.read(viewportProvider).zoom;
    container.read(viewportProvider.notifier).zoomAtPoint(zoom * 2, Offset.zero);
    await tester.pump();
    final after = container.read(viewportProvider).zoom / zoom;
    expect(after, greaterThan(1.2), reason: 'the zoom took effect');
    expect(field, findsOneWidget, reason: 'a zoom keeps the text open');
    expect(shownWidth(), closeTo(before * after, 1));
  });

  testWidgets('the page scrolls up to keep the text above the keyboard, and '
      'back afterwards', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    await startTyping(tester, const Offset(120, 520));
    final scrollBefore = container.read(viewportProvider).scrollY;

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump();
    final fieldBottom = tester.getBottomLeft(field).dy;
    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(fieldBottom, lessThanOrEqualTo(screen - 300));

    await tester.enterText(field, 'above the keys');
    await tester.tap(find.byKey(const ValueKey('inlineTextDone')));
    await tester.pump();
    expect(container.read(viewportProvider).scrollY, closeTo(scrollBefore, 0.5));
  });
}
