// The page manager grid: drag to reorder, multi-select, delete with a check.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/editor/state/page_notifier.dart';
import 'package:margo/editor/state/scene_controller.dart';
import 'package:margo/features/home/data/repositories/note_repository.dart';
import 'package:margo/features/home/domain/models/notebook.dart';
import 'package:margo/features/home/presentation/home_notifier.dart';
import 'package:margo/features/notebook/presentation/page_manager_screen.dart';

import '../../editor/state/page_notifier_test.dart' show FakePageRepository;

class _Notes implements NoteRepository {
  @override
  Future<Notebook?> getNotebook(int id) async => Notebook()
    ..id = id
    ..title = 't'
    ..createdAt = DateTime(2027)
    ..modifiedAt = DateTime(2027);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakePageRepository repo;
  late ProviderContainer container;

  Future<List<int>> pump(WidgetTester tester) async {
    repo = FakePageRepository();
    container = ProviderContainer(overrides: [
      pageRepositoryProvider.overrideWithValue(repo),
      sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
      noteRepositoryProvider.overrideWithValue(_Notes()),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(pageProvider(1).notifier);
    await notifier.initialize();
    for (var i = 0; i < 3; i++) {
      await notifier.insertPage();
    }
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PageManagerScreen(notebookId: 1)),
    ));
    await tester.pumpAndSettle();
    return [for (final p in container.read(pageProvider(1)).pages) p.id];
  }

  List<int> order() =>
      [for (final p in container.read(pageProvider(1)).pages) p.id];

  testWidgets('shows every page', (tester) async {
    await pump(tester);
    expect(find.text('Pages (4)'), findsOneWidget);
    expect(find.byKey(const Key('pageCell_3')), findsOneWidget);
  });

  testWidgets('long-press and drag moves a page to the dropped place',
      (tester) async {
    final a = await pump(tester);
    final g = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('pageCell_0'))));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveTo(tester.getCenter(find.byKey(const Key('pageCell_2'))));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(order(), [a[1], a[2], a[0], a[3]]);
  });

  testWidgets('select mode toggles pages and deletes them after asking',
      (tester) async {
    final a = await pump(tester);
    await tester.tap(find.byKey(const Key('pageManagerSelect')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pageCell_1')));
    await tester.tap(find.byKey(const Key('pageCell_2')));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pageManagerDelete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 pages?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pageManagerConfirmDelete')));
    await tester.pumpAndSettle();
    expect(order(), [a[0], a[3]]);
  });

  testWidgets('selecting every page cannot be deleted', (tester) async {
    final a = await pump(tester);
    await tester.tap(find.byKey(const Key('pageManagerSelect')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pageManagerSelectAll')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pageManagerDelete')));
    await tester.pump();
    expect(find.text('A notebook needs at least one page.'), findsOneWidget);
    expect(order(), a);
  });

  testWidgets('move to end sends the selection to the back', (tester) async {
    final a = await pump(tester);
    await tester.tap(find.byKey(const Key('pageManagerSelect')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pageCell_0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pageManagerToEnd')));
    await tester.pumpAndSettle();
    expect(order(), [a[1], a[2], a[3], a[0]]);
  });
}
