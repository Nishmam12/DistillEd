import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/data/persistence/scene_element_store.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/state/scene_controller.dart';
import 'package:inkflow/editor/state/selection_controller.dart';
import 'package:inkflow/editor/ui/controls/selection_bar.dart';
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
}
