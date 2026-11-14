// Widget tests proving the unified canvas draws (stylus → committed element)
// and pans (hand tool → viewport scroll), end-to-end through the real input
// pipeline, viewport and SceneController.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/state/editor_tool_controller.dart';
import 'package:margo/editor/state/history_controller.dart';
import 'package:margo/editor/state/scene_controller.dart';
import 'package:margo/editor/state/selection_controller.dart';
import 'package:margo/editor/state/viewport_controller.dart';
import 'package:margo/editor/ui/scene_canvas.dart';

const ScenePageKey _key = (notebookId: 0, pageId: 0);

ProviderContainer _container() =>
    ProviderContainer(retry: (_, _) => null, overrides: [
      sceneElementStoreProvider
          .overrideWithValue(InMemorySceneElementStore()),
    ]);

Future<void> _pump(WidgetTester tester, ProviderContainer container) {
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: SceneCanvas(notebookId: 0, pageId: 0)),
      ),
    ),
  );
}

void main() {
  testWidgets('a stylus stroke commits one freehand element', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    final g = await tester.startGesture(const Offset(100, 100),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(20, 0));
    await g.moveBy(const Offset(20, 20));
    await g.up();
    await tester.pump();

    final elements = container.read(sceneControllerProvider(_key));
    expect(elements.length, 1);
    expect(elements.first, isA<FreehandElement>());
    expect((elements.first as FreehandElement).points.length,
        greaterThanOrEqualTo(3));
  });

  testWidgets('a stroke is saved with the pen type it was drawn with',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);
    container.read(editorToolProvider.notifier).setPenKind(PenKind.highlighter);
    await tester.pump();

    final g = await tester.startGesture(const Offset(100, 100),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(40, 0));
    await g.up();
    await tester.pump();

    final stroke =
        container.read(sceneControllerProvider(_key)).single as FreehandElement;
    expect(stroke.penKind, PenKind.highlighter);
  });

  Future<void> holdLine(WidgetTester tester) async {
    final g = await tester.startGesture(const Offset(100, 100),
        kind: PointerDeviceKind.stylus);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset(100 + i * 20.0, 100 + (i.isEven ? 3 : -3)),
          timeStamp: Duration(milliseconds: i * 20));
    }
    await g.moveTo(const Offset(300, 100),
        timeStamp: const Duration(milliseconds: 220));
    await g.moveTo(const Offset(300, 101),
        timeStamp: const Duration(milliseconds: 900));
    await g.up(timeStamp: const Duration(milliseconds: 950));
    await tester.pump();
  }

  testWidgets('straighten is off by default: a held line stays as drawn',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);
    await holdLine(tester);
    final line =
        container.read(sceneControllerProvider(_key)).single as FreehandElement;
    expect(line.points.any((p) => (p.y - 100).abs() > 2), isTrue);
  });

  testWidgets('holding the pen at the end of a line straightens it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = _container();
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).setStraightenLines(true);
    await _pump(tester, container);

    final g = await tester.startGesture(const Offset(100, 100),
        kind: PointerDeviceKind.stylus);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset(100 + i * 20.0, 100 + (i.isEven ? 3 : -3)),
          timeStamp: Duration(milliseconds: i * 20));
    }
    await g.moveTo(const Offset(300, 100),
        timeStamp: const Duration(milliseconds: 220));
    // The pen rests where it ended.
    await g.moveTo(const Offset(300, 101),
        timeStamp: const Duration(milliseconds: 900));
    await g.up(timeStamp: const Duration(milliseconds: 950));
    await tester.pump();

    final line =
        container.read(sceneControllerProvider(_key)).single as FreehandElement;
    for (final p in line.points) {
      expect(p.y, closeTo(100, 1.5));
    }

    // One undo brings back the line as drawn.
    container.read(historyProvider(_key).notifier).undo();
    final drawn =
        container.read(sceneControllerProvider(_key)).single as FreehandElement;
    expect(drawn.points.any((p) => (p.y - 100).abs() > 2), isTrue);
  });

  testWidgets('dragging a locked page with the lasso says how to move it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = _container();
    addTearDown(container.dispose);
    await container.read(sceneControllerProvider(_key).notifier).addMany([
      const ImageElement(
        id: 'pdf',
        zOrder: 0,
        geometryData: [0, 0, 700, 500],
        relativeImagePath: 'p.png',
        isLocked: true,
      ),
    ]);
    await _pump(tester, container);
    container.read(editorToolProvider.notifier).setTool(EditorTool.select);
    await tester.pump();

    final g = await tester.startGesture(const Offset(300, 300),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(60, 40));
    await g.moveBy(const Offset(60, 40));
    await g.up();
    await tester.pump();

    expect(find.textContaining('Unlock to move it'), findsOneWidget);
  });

  testWidgets('a two-finger tap undoes, a three-finger tap redoes',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    final g = await tester.startGesture(const Offset(100, 100),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(40, 0));
    await g.up();
    await tester.pump();
    expect(container.read(sceneControllerProvider(_key)), hasLength(1));

    Future<void> tap(int fingers) async {
      // Well past the palm-rejection window after the pen lifted.
      const at = Duration(seconds: 5);
      final touches = <TestGesture>[];
      for (var i = 0; i < fingers; i++) {
        touches.add(await tester.createGesture(kind: PointerDeviceKind.touch));
        await touches.last.down(Offset(200.0 + i * 50, 300), timeStamp: at);
      }
      for (final t in touches) {
        await t.up(timeStamp: at + const Duration(milliseconds: 80));
      }
      await tester.pump();
    }

    await tap(2);
    expect(container.read(sceneControllerProvider(_key)), isEmpty);
    await tap(3);
    expect(container.read(sceneControllerProvider(_key)), hasLength(1));
  });

  testWidgets('a stroke is stamped by the screen-supplied stampStroke',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SceneCanvas(
            notebookId: 0,
            pageId: 0,
            stampStroke: (_) => (recordingId: 7, audioOffsetMs: 1234),
          ),
        ),
      ),
    ));

    final g = await tester.startGesture(const Offset(100, 100),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(20, 0));
    await g.up();
    await tester.pump();

    final stroke =
        container.read(sceneControllerProvider(_key)).single as FreehandElement;
    expect(stroke.recordingId, 7);
    expect(stroke.audioOffsetMs, 1234);
  });

  testWidgets('hand tool pans the viewport instead of drawing', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    container.read(editorToolProvider.notifier).setTool(EditorTool.hand);
    await tester.pump();

    final g = await tester.startGesture(const Offset(100, 100),
        kind: PointerDeviceKind.touch);
    await g.moveBy(const Offset(30, 15));
    await g.up();
    await tester.pump();

    expect(container.read(sceneControllerProvider(_key)), isEmpty); // no draw
    final vp = container.read(viewportProvider);
    expect(vp.scrollX, closeTo(30, 1e-6));
    expect(vp.scrollY, closeTo(15, 1e-6));
  });

  testWidgets('shape tool drag commits a SceneShapeElement', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    container.read(editorToolProvider.notifier).setTool(EditorTool.shape);
    await tester.pump();

    final g = await tester.startGesture(const Offset(100, 100),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(60, 40));
    await g.up();
    await tester.pump();

    final els = container.read(sceneControllerProvider(_key));
    expect(els.length, 1);
    expect(els.first, isA<SceneShapeElement>());
  });

  // Typing text on the page: see inline_text_test.dart.

  testWidgets('select tool: a lasso loop selects what it encloses',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    final scene = container.read(sceneControllerProvider(_key).notifier);
    SceneShapeElement rect(String id, double x, double y) => SceneShapeElement(
          id: id,
          zOrder: 0,
          shapeType: ShapeType.rectangle,
          geometryData: [x, y, x + 40, y + 40],
          color: 0xFF000000,
          strokeWidth: 2,
        );
    await scene.addMany([rect('in', 100, 100), rect('out', 400, 400)]);
    await _pump(tester, container);
    container.read(editorToolProvider.notifier)
      ..setTool(EditorTool.select)
      ..setSelectLasso(true);
    await tester.pump();

    // A loop round the first, well clear of the second.
    final g = await tester.startGesture(const Offset(70, 70),
        kind: PointerDeviceKind.stylus);
    for (final p in const [
      Offset(190, 70),
      Offset(190, 190),
      Offset(70, 190),
      Offset(70, 80),
    ]) {
      await g.moveTo(p);
    }
    await tester.pump();
    await g.up();
    await tester.pump();

    expect(container.read(selectionProvider), {'in'});
  });

  testWidgets('select tool: with the lasso off a drag is still a rectangle',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await container.read(sceneControllerProvider(_key).notifier).addMany([
      const SceneShapeElement(
        id: 'a',
        zOrder: 0,
        shapeType: ShapeType.rectangle,
        geometryData: [100, 100, 140, 140],
        color: 0xFF000000,
        strokeWidth: 2,
      ),
    ]);
    await _pump(tester, container);
    container.read(editorToolProvider.notifier).setTool(EditorTool.select);
    await tester.pump();
    final g = await tester.startGesture(const Offset(70, 70),
        kind: PointerDeviceKind.stylus);
    await g.moveTo(const Offset(190, 190));
    await g.up();
    await tester.pump();
    expect(container.read(selectionProvider), {'a'});
  });

  testWidgets('select tool: marquee selects, then drag moves', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    // Seed a rectangle at (100,100)-(160,140).
    await container.read(sceneControllerProvider(_key).notifier).addMany([
          const SceneShapeElement(
            id: 'r',
            zOrder: 0,
            shapeType: ShapeType.rectangle,
            geometryData: [100, 100, 160, 140],
            color: 0xFF000000,
            strokeWidth: 2,
          ),
        ]);
    container.read(editorToolProvider.notifier).setTool(EditorTool.select);
    await tester.pump();

    // Marquee around the rectangle.
    final m = await tester.startGesture(const Offset(60, 60),
        kind: PointerDeviceKind.stylus);
    await m.moveBy(const Offset(140, 120)); // → (200, 180)
    await m.up();
    await tester.pump();
    expect(container.read(selectionProvider), {'r'});

    // Drag from inside the rectangle to move it.
    final g = await tester.startGesture(const Offset(130, 120),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(20, 10));
    await g.up();
    await tester.pump();

    final moved = container.read(sceneControllerProvider(_key)).first
        as SceneShapeElement;
    expect(moved.geometryData[0], closeTo(120, 1)); // 100 + 20
    expect(moved.geometryData[1], closeTo(110, 1)); // 100 + 10
  });

  group('select tool over a locked PDF page', () {
    Future<ProviderContainer> seeded(WidgetTester tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await _pump(tester, container);
      await container.read(sceneControllerProvider(_key).notifier).addMany([
        const ImageElement(
          id: 'pdf',
          zOrder: 0,
          geometryData: [0, 0, 700, 500],
          relativeImagePath: 'notes/0/imports/p1.png',
          isLocked: true,
        ),
        const SceneShapeElement(
          id: 'ink',
          zOrder: 1,
          shapeType: ShapeType.rectangle,
          geometryData: [100, 100, 160, 140],
          color: 0xFF000000,
          strokeWidth: 2,
        ),
      ]);
      container.read(editorToolProvider.notifier).setTool(EditorTool.select);
      await tester.pump();
      return container;
    }

    testWidgets('a drag across the page selects the ink on it, not the page',
        (tester) async {
      final container = await seeded(tester);

      final m = await tester.startGesture(const Offset(60, 60),
          kind: PointerDeviceKind.stylus);
      await m.moveBy(const Offset(140, 120));
      await m.up();
      await tester.pump();

      expect(container.read(selectionProvider), {'ink'});
      final pdf = container
          .read(sceneControllerProvider(_key))
          .firstWhere((e) => e.id == 'pdf') as ImageElement;
      expect(pdf.geometryData, [0, 0, 700, 500]);
    });

    testWidgets('a tap on a bare part of the page still selects it',
        (tester) async {
      final container = await seeded(tester);

      await tester.tapAt(const Offset(400, 300), kind: PointerDeviceKind.stylus);
      await tester.pump();

      expect(container.read(selectionProvider), {'pdf'});
    });
  });

  testWidgets('pen draw is undoable', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    final g = await tester.startGesture(const Offset(100, 100),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(20, 20));
    await g.up();
    await tester.pump();
    expect(container.read(sceneControllerProvider(_key)).length, 1);

    container.read(historyProvider(_key).notifier).undo();
    await tester.pump();
    expect(container.read(sceneControllerProvider(_key)), isEmpty);

    container.read(historyProvider(_key).notifier).redo();
    await tester.pump();
    expect(container.read(sceneControllerProvider(_key)).length, 1);
  });

  testWidgets('frame tool drag commits a FrameElement', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    container.read(editorToolProvider.notifier).setTool(EditorTool.frame);
    await tester.pump();

    final g = await tester.startGesture(const Offset(60, 60),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(140, 120));
    await g.up();
    await tester.pump();

    final els = container.read(sceneControllerProvider(_key));
    expect(els.length, 1);
    expect(els.first, isA<FrameElement>());
  });

  testWidgets('moving a frame carries the elements inside it', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    final ctl = container.read(sceneControllerProvider(_key).notifier);
    await ctl.addMany(const [
      FrameElement(
          id: 'frame', zOrder: 0, geometryData: [50, 50, 200, 200], name: 'F'),
      SceneShapeElement(
        id: 'r',
        zOrder: 1,
        shapeType: ShapeType.rectangle,
        geometryData: [100, 100, 140, 140],
        color: 0xFF000000,
        strokeWidth: 2,
      ),
    ]);
    container.read(editorToolProvider.notifier).setTool(EditorTool.select);
    container.read(selectionProvider.notifier).selectMany({'frame'});
    await tester.pump();

    // Drag from inside the frame but away from handles and the inner rect.
    final g = await tester.startGesture(const Offset(70, 170),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(30, 20));
    await g.up();
    await tester.pump();

    final rect = container
        .read(sceneControllerProvider(_key))
        .firstWhere((e) => e.id == 'r') as SceneShapeElement;
    expect(rect.geometryData[0], closeTo(130, 1)); // 100 + 30
    expect(rect.geometryData[1], closeTo(120, 1)); // 100 + 20
  });

  testWidgets('starting a stroke closes the tool options panel',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);
    expect(container.read(editorToolProvider).panelOpen, isTrue);

    final g = await tester.startGesture(const Offset(100, 100),
        kind: PointerDeviceKind.stylus);
    // Closed the instant the pointer goes down — not just once the stroke
    // is committed on pointer-up.
    expect(container.read(editorToolProvider).panelOpen, isFalse);

    await g.moveBy(const Offset(20, 20));
    await g.up();
    await tester.pump();
    expect(container.read(editorToolProvider).panelOpen, isFalse);
  });

  testWidgets('element eraser removes a stroke it crosses', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    await container.read(sceneControllerProvider(_key).notifier).addMany([
          const SceneShapeElement(
            id: 'r',
            zOrder: 0,
            shapeType: ShapeType.rectangle,
            geometryData: [100, 100, 160, 140],
            color: 0xFF000000,
            strokeWidth: 2,
          ),
        ]);
    container.read(editorToolProvider.notifier).setTool(EditorTool.eraser);
    await tester.pump();

    final g = await tester.startGesture(const Offset(90, 120),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(90, 0)); // swipe across the rect
    await g.up();
    await tester.pump();

    expect(container.read(sceneControllerProvider(_key)), isEmpty);
  });

  group('erasing from the pen itself', () {
    Future<void> drawStroke(WidgetTester tester) async {
      final g = await tester.startGesture(const Offset(100, 100),
          kind: PointerDeviceKind.stylus);
      await g.moveBy(const Offset(40, 0));
      await g.moveBy(const Offset(40, 0));
      await g.up();
      await tester.pump();
    }

    Future<void> swipeAcross(WidgetTester tester,
        {required PointerDeviceKind kind, int buttons = kPrimaryButton}) async {
      final g = await tester.startGesture(const Offset(140, 60),
          kind: kind, buttons: buttons);
      await g.moveBy(const Offset(0, 40));
      await g.moveBy(const Offset(0, 40));
      await g.up();
      await tester.pump();
    }

    testWidgets('the eraser end removes ink while the pen tool is selected',
        (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await _pump(tester, container);
      await drawStroke(tester);
      expect(container.read(sceneControllerProvider(_key)), hasLength(1));

      await swipeAcross(tester, kind: PointerDeviceKind.invertedStylus);

      expect(container.read(sceneControllerProvider(_key)), isEmpty);
      expect(container.read(editorToolProvider).tool, EditorTool.pen);
    });

    testWidgets('the side button erases, and releasing it draws again',
        (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await _pump(tester, container);
      await drawStroke(tester);

      await swipeAcross(tester,
          kind: PointerDeviceKind.stylus, buttons: kPrimaryStylusButton);
      expect(container.read(sceneControllerProvider(_key)), isEmpty);

      await swipeAcross(tester, kind: PointerDeviceKind.stylus);
      expect(container.read(sceneControllerProvider(_key)), hasLength(1));
    });
  });
}
