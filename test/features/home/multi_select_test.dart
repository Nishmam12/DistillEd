import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/home/presentation/home_notifier.dart';
import 'package:margo/features/home/presentation/models/note_card_data.dart';
import 'package:margo/features/home/presentation/note_cards_provider.dart';
import 'package:margo/features/home/presentation/notes_selection.dart';
import 'package:margo/features/home/presentation/screens/notes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trash_test.dart' show FakeNoteRepository;

NoteCardData _c(int id, {bool pinned = false}) => NoteCardData(
    id: id,
    title: 'Note $id',
    createdAt: DateTime(2026),
    pages: 1,
    type: NoteType.text,
    pinned: pinned);

void main() {
  group('bulk actions', () {
    late FakeNoteRepository repo;
    late HomeNotifier home;
    setUp(() async {
      repo = FakeNoteRepository();
      home = HomeNotifier(repo);
      for (final t in ['A', 'B', 'C']) {
        await repo.createNotebook(t);
      }
      await home.loadNotebooks();
    });

    test('pin, folder and delete apply to every id, with undo', () async {
      await home.setPinnedMany([1, 3], true);
      expect(home.state.where((n) => n.pinned).map((n) => n.id), [1, 3]);

      await home.setFolderMany([1, 2], 9);
      expect(home.state.where((n) => n.folderId == 9).map((n) => n.id), [1, 2]);

      await home.deleteMany([1, 2]);
      expect(home.state.map((n) => n.id), [3]);
      await home.restoreMany([1, 2]);
      expect(home.state, hasLength(3));
    });

    test('added tags are merged with the tags a notebook already has',
        () async {
      await home.setTags(1, ['exam']);
      await home.addTagsMany([1, 2], ['week 3']);
      final byId = {for (final n in home.state) n.id: n};
      expect(byId[1]!.tags, ['exam', 'week 3']);
      expect(byId[2]!.tags, ['week 3']);
    });
  });

  group('home grid', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(retry: (_, _) => null, overrides: [
        noteCardsProvider.overrideWith((ref) async => [_c(1), _c(2), _c(3)]),
        noteRepositoryProvider.overrideWithValue(FakeNoteRepository()),
      ]);
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: c, child: const MaterialApp(home: NotesScreen())));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('long press, Select, then taps pick; All and Done work',
        (tester) async {
      final c = await pump(tester);
      await tester.longPress(find.text('Note 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(c.read(notesSelectionProvider), {1});
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byKey(const ValueKey('picked:1')), findsOneWidget);

      // While selecting, a tap picks instead of opening.
      await tester.tap(find.text('Note 2'));
      await tester.pumpAndSettle();
      expect(c.read(notesSelectionProvider), {1, 2});

      await tester.tap(find.byKey(const ValueKey('selectAll')));
      await tester.pumpAndSettle();
      expect(c.read(notesSelectionProvider), {1, 2, 3});

      await tester.tap(find.byKey(const ValueKey('selectionDone')));
      await tester.pumpAndSettle();
      expect(c.read(notesSelectionProvider), isEmpty);
      expect(find.byKey(const ValueKey('selectionCount')), findsNothing);
    });

    testWidgets('changing the view starts the selection again', (tester) async {
      final c = await pump(tester);
      c.read(notesSelectionProvider.notifier).state = {1, 2};
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      c.read(notesFavoritesOnlyProvider.notifier).state = true;
      await tester.pumpAndSettle();
      expect(c.read(notesSelectionProvider), isEmpty);
      expect(find.byKey(const ValueKey('selectionCount')), findsNothing);
    });

    testWidgets('cancelling the folder sheet keeps the selection',
        (tester) async {
      final c = await pump(tester);
      c.read(notesSelectionProvider.notifier).state = {1, 2};
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selectionFolder')));
      await tester.pumpAndSettle();
      // Dismiss the sheet without choosing.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(c.read(notesSelectionProvider), {1, 2});
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('the selection bar and Recent strip fit a 320 dp phone '
          '(text x$scale)', (tester) async {
        SharedPreferences.setMockInitialValues({
          'home.recentNotebooks': ['1', '2', '3'],
        });
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final c = ProviderContainer(retry: (_, _) => null, overrides: [
          noteCardsProvider.overrideWith((ref) async => [_c(1), _c(2), _c(3)]),
        ]);
        addTearDown(c.dispose);
        await tester.pumpWidget(UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const NotesScreen(),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('recentStrip')), findsOneWidget);
        expect(tester.takeException(), isNull);

        c.read(notesSelectionProvider.notifier).state = {1};
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('selectionCount')), findsOneWidget);
        expect(find.byKey(const ValueKey('selectionMore')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('un-picking the last notebook leaves select mode',
        (tester) async {
      final c = await pump(tester);
      c.read(notesSelectionProvider.notifier).state = {2};
      await tester.pumpAndSettle();
      await tester.tap(find.text('Note 2'));
      await tester.pumpAndSettle();
      expect(c.read(notesSelectionProvider), isEmpty);
    });
  });
}
