// The outline lists bookmarked or named pages and opens the one tapped.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/editor/state/page_notifier.dart';
import 'package:margo/editor/state/scene_controller.dart';
import 'package:margo/features/notebook/presentation/page_outline_screen.dart';

import '../../editor/state/page_notifier_test.dart' show FakePageRepository;

void main() {
  late ProviderContainer container;

  Future<List<int>> pump(WidgetTester tester) async {
    container = ProviderContainer(overrides: [
      pageRepositoryProvider.overrideWithValue(FakePageRepository()),
      sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(pageProvider(1).notifier);
    await notifier.initialize();
    for (var i = 0; i < 3; i++) {
      await notifier.insertPage();
    }
    final ids = [for (final p in container.read(pageProvider(1)).pages) p.id];
    await notifier.setBookmarked(ids[1], true);
    await notifier.renamePage(ids[3], 'Summary');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PageOutlineScreen(notebookId: 1)),
    ));
    await tester.pumpAndSettle();
    return ids;
  }

  testWidgets('lists only bookmarked or named pages', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('outlineEntry_1')), findsOneWidget);
    expect(find.byKey(const Key('outlineEntry_3')), findsOneWidget);
    expect(find.byKey(const Key('outlineEntry_0')), findsNothing);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);
  });

  testWidgets('tapping an entry makes that page current', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('outlineEntry_1')));
    await tester.pumpAndSettle();
    expect(container.read(pageProvider(1)).currentPageIndex, 1);
  });

  testWidgets('says so when nothing is marked', (tester) async {
    container = ProviderContainer(overrides: [
      pageRepositoryProvider.overrideWithValue(FakePageRepository()),
      sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PageOutlineScreen(notebookId: 1)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bookmark or name a page'), findsOneWidget);
  });
}
