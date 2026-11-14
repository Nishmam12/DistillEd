// The real NotebookEditorScreen, pumped with in-memory stores: closing it
// releases each page's scene and undo state and stops a live lecture
// recording; covering it with another route does neither.

import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/data/persistence/lecture_recording_store.dart';
import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/commands/scene_command.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/state/editor_tool_controller.dart';
import 'package:margo/editor/state/history_controller.dart';
import 'package:margo/editor/state/page_notifier.dart';
import 'package:margo/editor/state/scene_controller.dart';
import 'package:margo/domain/model/page_size.dart';
import 'package:margo/editor/state/viewport_controller.dart';
import 'package:margo/editor/ui/neighbour_pages_layer.dart';
import 'package:margo/editor/ui/scene_canvas.dart';
import 'package:margo/features/audio/data/transcript_store.dart';
import 'package:margo/features/audio/presentation/audio_providers.dart';
import 'package:margo/features/audio/presentation/recording_notifier.dart';
import 'package:margo/features/home/presentation/home_notifier.dart';
import 'package:margo/features/notebook/presentation/notebook_editor_screen.dart';

import '../../editor/state/page_notifier_test.dart' show FakePageRepository;
import '../audio/lecture_recording_test.dart' show FakeCapture;
import '../home/trash_test.dart' show FakeNoteRepository;

void main() {
  late ProviderContainer container;
  late FakeCapture capture;
  late InMemorySceneElementStore store;
  late FakeNoteRepository notes;
  late Directory docs;
  final navKey = GlobalKey<NavigatorState>();

  // Opening the AI panel starts a page read, whose text recognizer is closed
  // when the container is disposed. No ML Kit plugin runs in tests.
  const mlkit = MethodChannel('google_mlkit_text_recognizer');

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mlkit, (_) async => null);
    SharedPreferences.setMockInitialValues({});
    docs = Directory.systemTemp.createTempSync('margo_editor_');
    capture = FakeCapture();
    store = InMemorySceneElementStore();
    notes = FakeNoteRepository();
    await notes.createNotebook('Lecture');
    container = ProviderContainer(retry: (_, _) => null, overrides: [
      appDocsPathProvider.overrideWithValue(docs.path),
      sceneElementStoreProvider.overrideWithValue(store),
      pageRepositoryProvider.overrideWithValue(FakePageRepository()),
      noteRepositoryProvider.overrideWithValue(notes),
      secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      audioCaptureProvider.overrideWithValue(capture),
      lectureRecordingStoreProvider
          .overrideWithValue(InMemoryLectureRecordingStore()),
      transcriptStoreProvider.overrideWithValue(InMemoryTranscriptStore()),
    ]);
  });

  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mlkit, null);
    docs.deleteSync(recursive: true);
  });

  Future<void> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('home')),
      ),
    ));
  }

  Future<void> openEditor(WidgetTester tester) async {
    navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const NotebookEditorScreen(notebookId: 1),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
  }

  ScenePageKey keyOfFirstPage() => (
        notebookId: 1,
        pageId: container.read(pageProvider(1)).pages.first.id,
      );

  FreehandElement stroke(String id) => FreehandElement(
        id: id,
        zOrder: 0,
        color: 0xFF000000,
        size: 3,
        points: const [
          StrokePoint(x: 0, y: 0, pressure: 0.5),
          StrokePoint(x: 10, y: 10, pressure: 0.5),
        ],
      );

  testWidgets('closing the editor releases scene and undo state; reopening '
      'reloads the saved scene with an empty undo stack', (tester) async {
    await pumpHost(tester);
    await openEditor(tester);

    final key = keyOfFirstPage();
    final scene = container.read(sceneControllerProvider(key).notifier);
    final history = container.read(historyProvider(key).notifier);
    history.push(AddElementsCommand([stroke('s1')]));
    await tester.pumpAndSettle();
    expect(container.read(historyProvider(key)).canUndo, isTrue);

    await close(tester);
    // Released: the next read builds fresh instances.
    expect(container.read(sceneControllerProvider(key).notifier),
        isNot(same(scene)));
    expect(container.read(historyProvider(key).notifier),
        isNot(same(history)));

    await openEditor(tester);
    expect(container.read(sceneControllerProvider(key)).map((e) => e.id),
        ['s1']);
    expect(container.read(historyProvider(key)).canUndo, isFalse);
  });

  testWidgets('the AI panel floats over the page without shrinking it, and '
      'can be docked', (tester) async {
    await pumpHost(tester);
    await openEditor(tester);
    final canvas = find.byType(SceneCanvas);
    final before = tester.getSize(canvas);

    await tester.tap(find.byTooltip('AI insights'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('floatingAiPanel')), findsOneWidget);
    expect(tester.getSize(canvas), before, reason: 'the page keeps its size');

    await tester.tap(find.byKey(const ValueKey('aiPanelFloatToggle')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('floatingAiPanel')), findsNothing);
    expect(container.read(settingsProvider).aiPanelFloating, isFalse);
    expect(tester.getSize(canvas).width, lessThan(before.width),
        reason: 'docked, it sits beside the page as before');

    // Close the panel so nothing it started is left running.
    await tester.tap(find.byTooltip('Close'));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('closing the editor with text still open keeps the text',
      (tester) async {
    await pumpHost(tester);
    await openEditor(tester);
    final key = keyOfFirstPage();
    container.read(editorToolProvider.notifier).setTool(EditorTool.text);
    await tester.pump();
    final canvas = tester.getRect(find.byType(SceneCanvas));
    final g = await tester.startGesture(canvas.center,
        kind: PointerDeviceKind.stylus);
    await g.up();
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('inlineTextField')), 'written, then left');

    await close(tester);
    final saved = await tester.runAsync(() => store.loadForPage(key.pageId));
    expect(saved!.whereType<TextElement>().map((t) => t.text),
        ['written, then left']);
  });

  group('continuous layout on A4', () {
    Future<void> openTwoPages(WidgetTester tester) async {
      notes.notebooks.first
        ..layoutMode = 2
        ..pageSize = PageSizeKind.a4Portrait.index;
      await pumpHost(tester);
      await openEditor(tester);
      await container.read(pageProvider(1).notifier).insertPage();
      container.read(pageProvider(1).notifier).switchPage(0);
      await tester.pumpAndSettle();
    }

    testWidgets('the page is A4 and the next page shows below it',
        (tester) async {
      await openTwoPages(tester);
      final canvas = tester.widget<SceneCanvas>(find.byType(SceneCanvas));
      expect(canvas.pageSize, PageSizeKind.a4Portrait.size);
      expect(canvas.continuous, isTrue);
      final pages = container.read(pageProvider(1)).pages;
      final layer =
          tester.widget<NeighbourPagesLayer>(find.byType(NeighbourPagesLayer));
      expect(layer.abovePageId, isNull);
      expect(layer.belowPageId, pages[1].id);
    });

    testWidgets('scrolling the next page into the middle makes it current, '
        'without the view jumping', (tester) async {
      await openTwoPages(tester);
      final vp = container.read(viewportProvider.notifier);
      final z = container.read(viewportProvider).zoom;
      const sheet = Size(794, 1123);
      // A point near the top of page 2, in page 1's scene, before the step.
      final onNext =
          Offset(100, sheet.height + ViewportController.pageGap + 40);
      vp.pan(Offset(0, -(sheet.height * z)));
      final before = container.read(viewportProvider).toViewport(onNext);
      await tester.pumpAndSettle();

      expect(container.read(pageProvider(1)).currentPageIndex, 1);
      final after =
          container.read(viewportProvider).toViewport(const Offset(100, 40));
      expect((after - before).distance, lessThan(0.5));
      final layer =
          tester.widget<NeighbourPagesLayer>(find.byType(NeighbourPagesLayer));
      expect(layer.abovePageId, container.read(pageProvider(1)).pages[0].id);
      expect(layer.belowPageId, isNull);
    });
  });

  testWidgets('a route pushed over the editor keeps its state', (tester) async {
    await pumpHost(tester);
    await openEditor(tester);

    final key = keyOfFirstPage();
    final scene = container.read(sceneControllerProvider(key).notifier);
    navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('book view')),
    ));
    await tester.pumpAndSettle();
    await close(tester); // back to the editor

    expect(container.read(sceneControllerProvider(key).notifier), same(scene));
  });

  testWidgets('closing the editor stops a live recording and keeps it',
      (tester) async {
    await pumpHost(tester);
    await openEditor(tester);

    final key = keyOfFirstPage();
    await tester.runAsync(() => container
        .read(recordingNotifierProvider(1).notifier)
        .start(key.pageId));
    expect(capture.isRecording, isTrue);

    await close(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(capture.isRecording, isFalse);
    expect(capture.cancelled, isFalse); // stopped and finalized, not discarded
    expect(container.read(recordingNotifierProvider(1)).isRecording, isFalse);
  });
}
