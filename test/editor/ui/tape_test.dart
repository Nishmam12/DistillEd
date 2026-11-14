// Revision tape through the real canvas, pointer pipeline, history and
// selection bar.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/geometry/scene_hit_test.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/render/scene_exporter.dart';
import 'package:margo/editor/state/editor_tool_controller.dart';
import 'package:margo/editor/state/history_controller.dart';
import 'package:margo/editor/state/scene_controller.dart';
import 'package:margo/editor/state/selection_controller.dart';
import 'package:margo/editor/ui/scene_canvas.dart';
import 'package:margo/features/notebook/presentation/controls/selection_bar.dart';

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

  List<SceneElement> scene() => container.read(sceneControllerProvider(_key));

  Future<void> pumpCanvas(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
          home: Scaffold(body: SceneCanvas(notebookId: 0, pageId: 0))),
    ));
    container.read(editorToolProvider.notifier).setTool(EditorTool.tape);
    await tester.pump();
  }

  Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
    final g = await tester.startGesture(from, kind: PointerDeviceKind.stylus);
    await g.moveTo(Offset.lerp(from, to, 0.5)!);
    await g.moveTo(to);
    await g.up();
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, Offset at) async {
    final g = await tester.startGesture(at, kind: PointerDeviceKind.stylus);
    await g.up();
    await tester.pump();
  }

  testWidgets('a drag lays tape, covered, as one undo step', (tester) async {
    await pumpCanvas(tester);
    await drag(tester, const Offset(100, 200), const Offset(300, 260));
    final t = scene().single as TapeElement;
    expect(t.revealed, isFalse);
    expect(t.color, kDefaultTapeColor);
    container.read(historyProvider(_key).notifier).undo();
    expect(scene(), isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a quick stroke along a line still lays a usable strip',
      (tester) async {
    await pumpCanvas(tester);
    await drag(tester, const Offset(100, 200), const Offset(300, 202));
    final t = scene().single as TapeElement;
    expect(t.boundsRect.height, greaterThanOrEqualTo(kTapeMinThickness));
    expect(t.boundsRect.center.dy, closeTo(201, 2));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the chosen colour is used', (tester) async {
    await pumpCanvas(tester);
    container.read(editorToolProvider.notifier).setTapeColor(0xFF8FB8DE);
    await drag(tester, const Offset(100, 200), const Offset(300, 260));
    expect((scene().single as TapeElement).color, 0xFF8FB8DE);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a tap lifts the tape and another lays it back; no undo step',
      (tester) async {
    await pumpCanvas(tester);
    await drag(tester, const Offset(100, 200), const Offset(300, 260));
    container.read(historyProvider(_key).notifier).clear();

    await tap(tester, const Offset(200, 230));
    expect((scene().single as TapeElement).revealed, isTrue);
    expect(container.read(historyProvider(_key)).canUndo, isFalse,
        reason: 'peeking is reading, not editing');
    await tap(tester, const Offset(200, 230));
    expect((scene().single as TapeElement).revealed, isFalse);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a tap off any tape does nothing', (tester) async {
    await pumpCanvas(tester);
    await tap(tester, const Offset(500, 500));
    expect(scene(), isEmpty);
  });

  test('tape is hit anywhere inside it, like a filled box', () {
    const t = TapeElement(id: 't', zOrder: 0, geometryData: [0, 0, 100, 30]);
    expect(SceneHitTest.topmostAt(const Offset(50, 15), [t]), 't');
    expect(SceneHitTest.topmostAt(const Offset(150, 15), [t]), isNull);
  });

  testWidgets('export draws covered tape opaque', (tester) async {
    await tester.runAsync(() async {
      final png = await SceneExporter.toPng([
        const TapeElement(id: 't', zOrder: 0, geometryData: [0, 0, 100, 30]),
      ]);
      expect(png, isNotNull);
    });
    final svg = SceneExporter.toSvg([
      const TapeElement(id: 't', zOrder: 0, geometryData: [0, 0, 100, 30]),
      const TapeElement(
          id: 'u', zOrder: 1, geometryData: [0, 40, 100, 70], revealed: true),
    ]);
    expect(svg, contains('fill-opacity="1"'));
    expect(svg, contains('fill-opacity="0.14"'));
  });

  group('selection bar', () {
    Future<void> pumpBar(WidgetTester tester, List<TapeElement> tapes) async {
      await container
          .read(sceneControllerProvider(_key).notifier)
          .addMany(tapes);
      container
          .read(selectionProvider.notifier)
          .selectMany(tapes.map((t) => t.id));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: Scaffold(body: SelectionBar(pageKey: _key))),
      ));
    }

    TapeElement tape(String id, {bool revealed = false}) => TapeElement(
        id: id, zOrder: 0, geometryData: const [0, 0, 50, 24], revealed: revealed);

    testWidgets('Peek lifts all selected tape; Cover lays it back',
        (tester) async {
      await pumpBar(tester, [tape('a'), tape('b', revealed: true)]);
      expect(find.byTooltip('Peek'), findsOneWidget, reason: 'a mix lifts');
      await tester.tap(find.byKey(const ValueKey('peekTape')));
      await tester.pump();
      expect(scene().cast<TapeElement>().every((t) => t.revealed), isTrue);
      expect(find.byTooltip('Cover'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('peekTape')));
      await tester.pump();
      expect(scene().cast<TapeElement>().any((t) => t.revealed), isFalse);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
