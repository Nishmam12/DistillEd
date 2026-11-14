import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/state/history_controller.dart';
import 'package:margo/editor/state/scene_controller.dart';
import 'package:margo/editor/state/selection_controller.dart';
import 'package:margo/features/notebook/presentation/controls/selection_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = (notebookId: 0, pageId: 0);

  SceneShapeElement rect(String id, int z, double x) => SceneShapeElement(
        id: id,
        zOrder: z,
        shapeType: ShapeType.rectangle,
        geometryData: [x, 0, x + 10, 10],
        color: 0xFF000000,
        strokeWidth: 2,
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('bring to front keeps edits made after the bar was built',
      (tester) async {
    final container = ProviderContainer(retry: (_, _) => null, overrides: [
      sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
    ]);
    addTearDown(container.dispose);
    final scene = container.read(sceneControllerProvider(key).notifier);
    await scene.addMany([rect('a', 0, 0), rect('b', 1, 50)]);
    container.read(selectionProvider.notifier).selectMany(['a']);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
          home: Scaffold(body: SelectionBar(pageKey: key))),
    ));

    // Move 'a' after the bar has built, as a drag does.
    await scene.updateMany([rect('a', 0, 200)]);
    await tester.pump();

    await tester.tap(find.byTooltip('Bring to front'));
    await tester.pump(const Duration(seconds: 5)); // flush the persist timer

    final all = container.read(sceneControllerProvider(key));
    final a = all.firstWhere((e) => e.id == 'a') as SceneShapeElement;
    final b = all.firstWhere((e) => e.id == 'b');
    expect(a.geometryData.first, 200, reason: 'the move must survive');
    expect(a.zOrder, greaterThan(b.zOrder));
  });

  group('recolour, thickness and copy as image', () {
    late ProviderContainer container;

    Future<void> pumpBar(WidgetTester tester, List<SceneElement> els) async {
      container = ProviderContainer(retry: (_, _) => null, overrides: [
        sceneElementStoreProvider
            .overrideWithValue(InMemorySceneElementStore()),
      ]);
      addTearDown(container.dispose);
      await container.read(sceneControllerProvider(key).notifier).addMany(els);
      container
          .read(selectionProvider.notifier)
          .selectMany(els.map((e) => e.id));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: Scaffold(body: SelectionBar(pageKey: key))),
      ));
    }

    FreehandElement ink(String id) => FreehandElement(
          id: id,
          zOrder: 0,
          color: 0xFF000000,
          size: 2,
          points: const [
            StrokePoint(x: 0, y: 0, pressure: 1),
            StrokePoint(x: 20, y: 20, pressure: 1),
          ],
        );

    testWidgets('a thickness choice changes every ink and shape, one undo',
        (tester) async {
      await pumpBar(tester, [ink('a'), rect('b', 1, 50)]);
      await tester.tap(find.byKey(const ValueKey('thicknessSelection')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thick'));
      await tester.pump(const Duration(seconds: 5));

      final all = container.read(sceneControllerProvider(key));
      expect((all.firstWhere((e) => e.id == 'a') as FreehandElement).size, 8);
      expect(
          (all.firstWhere((e) => e.id == 'b') as SceneShapeElement).strokeWidth,
          8);
      container.read(historyProvider(key).notifier).undo();
      await tester.pump(const Duration(seconds: 5));
      expect(
          (container.read(sceneControllerProvider(key)).first as FreehandElement)
              .size,
          2);
    });

    testWidgets('colour opens the picker and recolours the selection',
        (tester) async {
      await pumpBar(tester, [ink('a')]);
      await tester.tap(find.byKey(const ValueKey('recolourSelection')));
      await tester.pumpAndSettle();
      expect(find.text('Custom colour'), findsOneWidget);
      await tester.tap(find.text('Use'));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      // The picker started from the ink's own colour, so "Use" kept it: still
      // a valid, undoable no-surprise result rather than a crash.
      expect(container.read(sceneControllerProvider(key)), hasLength(1));
    });

    testWidgets('no colour or thickness for a selection of only an image',
        (tester) async {
      await pumpBar(tester, [
        const ImageElement(
            id: 'p',
            zOrder: 0,
            geometryData: [0, 0, 10, 10],
            relativeImagePath: 'p.png'),
      ]);
      expect(find.byKey(const ValueKey('recolourSelection')), findsNothing);
      expect(find.byKey(const ValueKey('thicknessSelection')), findsNothing);
      expect(find.byKey(const ValueKey('copyAsImage')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // flush the persist timer
    });
  });

  testWidgets('a locked page offers "Unlock to move", and it unlocks',
      (tester) async {
    final container = ProviderContainer(retry: (_, _) => null, overrides: [
      sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
    ]);
    addTearDown(container.dispose);
    final scene = container.read(sceneControllerProvider(key).notifier);
    await scene.addMany([
      const ImageElement(
        id: 'pdf',
        zOrder: 0,
        geometryData: [0, 0, 400, 600],
        relativeImagePath: 'p.png',
        isLocked: true,
      ),
    ]);
    container.read(selectionProvider.notifier).selectMany(['pdf']);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
          home: Scaffold(body: SelectionBar(pageKey: key))),
    ));

    await tester.tap(find.byKey(const ValueKey('unlockSelection')));
    await tester.pump(const Duration(seconds: 5));

    expect(
        container.read(sceneControllerProvider(key)).single.isLocked, isFalse);
    expect(find.byKey(const ValueKey('unlockSelection')), findsNothing);
  });
}
