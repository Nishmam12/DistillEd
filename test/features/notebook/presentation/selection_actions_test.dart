// The selection's action chips: shown for what the selected text says, and a
// date chip adds the date to the notebook's study plan dates.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/state/scene_controller.dart';
import 'package:margo/features/ai/data/ml_kit_action_finder.dart';
import 'package:margo/features/ai/presentation/study_planner/pinned_deadlines.dart';
import 'package:margo/features/notebook/domain/action_links.dart';
import 'package:margo/features/notebook/presentation/controls/selection_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ScenePageKey _key = (notebookId: 4, pageId: 9);

class _FakeFinder extends MlKitActionFinder {
  String? asked;
  @override
  Future<List<FoundEntity>> find(String text, {required DateTime now}) async {
    asked = text;
    return [
      (kind: ActionKind.date, text: 'Dec 3', date: DateTime(now.year + 1, 12, 3)),
      (kind: ActionKind.web, text: 'margo.app', date: null),
    ];
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_FakeFinder> pump(WidgetTester tester, {Set<String>? ids}) async {
    final finder = _FakeFinder();
    final c = ProviderContainer(retry: (_, _) => null, overrides: [
      sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
      actionFinderProvider.overrideWithValue(finder),
    ]);
    addTearDown(c.dispose);
    await c.read(sceneControllerProvider(_key).notifier).addMany([
      const TextElement(
          id: 't',
          zOrder: 0,
          geometryData: [0, 0, 10, 10],
          text: 'Exam on Dec 3, notes at margo.app',
          color: 0),
    ]);
    final opened = <String>[];
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: SelectionActionChips(
            pageKey: _key,
            selectedIds: ids ?? {'t'},
            onOpenLink: opened.add,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return finder;
  }

  testWidgets('chips for the selected text; the date goes to the plan',
      (tester) async {
    final finder = await pump(tester);
    expect(finder.asked, 'Exam on Dec 3, notes at margo.app');
    expect(find.byKey(const ValueKey('action:date')), findsOneWidget);
    expect(find.byKey(const ValueKey('action:web')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('action:date')));
    await tester.pumpAndSettle();
    final pinned = await PinnedDeadlines.load(4);
    expect(pinned.single.label, 'Exam on Dec 3, notes at margo.app');
    expect(pinned.single.date.month, 12);
    expect(pinned.single.pageId, 9);
  });

  testWidgets('nothing selected, nothing shown', (tester) async {
    final finder = await pump(tester, ids: {});
    expect(finder.asked, isNull);
    expect(find.byType(ActionChip), findsNothing);
  });
}
