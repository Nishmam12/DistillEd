// The real NotebookEditorScreen, pumped with in-memory stores: closing it
// releases each page's scene and undo state and stops a live lecture
// recording; covering it with another route does neither.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/data/persistence/lecture_recording_store.dart';
import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/commands/scene_command.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/state/history_controller.dart';
import 'package:margo/editor/state/page_notifier.dart';
import 'package:margo/editor/state/scene_controller.dart';
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
  late Directory docs;
  final navKey = GlobalKey<NavigatorState>();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    docs = Directory.systemTemp.createTempSync('margo_editor_');
    capture = FakeCapture();
    store = InMemorySceneElementStore();
    final notes = FakeNoteRepository();
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
