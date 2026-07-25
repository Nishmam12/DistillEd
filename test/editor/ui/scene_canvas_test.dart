// Widget tests proving the unified canvas draws (stylus → committed element)
// and pans (hand tool → viewport scroll), end-to-end through the real input
// pipeline, viewport and SceneController.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/data/persistence/scene_element_store.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/state/editor_tool_controller.dart';
import 'package:inkflow/editor/state/history_controller.dart';
import 'package:inkflow/editor/state/scene_controller.dart';
import 'package:inkflow/editor/state/selection_controller.dart';
import 'package:inkflow/editor/state/viewport_controller.dart';
import 'package:inkflow/editor/ui/scene_canvas.dart';

const ScenePageKey _key = (notebookId: 0, pageId: 0);

ProviderContainer _container() => ProviderContainer(overrides: [
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

  testWidgets('text tool tap adds a TextElement via the dialog',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    container.read(editorToolProvider.notifier).setTool(EditorTool.text);
    await tester.pump();

    final g = await tester.startGesture(const Offset(120, 120),
        kind: PointerDeviceKind.stylus);
    await g.up();
    await tester.pumpAndSettle(); // dialog opens

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final els = container.read(sceneControllerProvider(_key));
    expect(els.length, 1);
    expect(els.first, isA<TextElement>());
    expect((els.first as TextElement).text, 'Hello');
  });

  testWidgets('select tool: marquee selects, then drag moves', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    // Seed a rectangle at (100,100)-(160,140).
    await container.read(sceneControllerProvider(_key).notifier).add(
          const SceneShapeElement(
            id: 'r',
            zOrder: 0,
            shapeType: ShapeType.rectangle,
            geometryData: [100, 100, 160, 140],
            color: 0xFF000000,
            strokeWidth: 2,
          ),
        );
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
    await ctl.add(const FrameElement(
        id: 'frame', zOrder: 0, geometryData: [50, 50, 200, 200], name: 'F'));
    await ctl.add(const SceneShapeElement(
      id: 'r',
      zOrder: 1,
      shapeType: ShapeType.rectangle,
      geometryData: [100, 100, 140, 140],
      color: 0xFF000000,
      strokeWidth: 2,
    ));
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

    await container.read(sceneControllerProvider(_key).notifier).add(
          const SceneShapeElement(
            id: 'r',
            zOrder: 0,
            shapeType: ShapeType.rectangle,
            geometryData: [100, 100, 160, 140],
            color: 0xFF000000,
            strokeWidth: 2,
          ),
        );
    container.read(editorToolProvider.notifier).setTool(EditorTool.eraser);
    await tester.pump();

    final g = await tester.startGesture(const Offset(90, 120),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(90, 0)); // swipe across the rect
    await g.up();
    await tester.pump();

    expect(container.read(sceneControllerProvider(_key)), isEmpty);
  });
}
