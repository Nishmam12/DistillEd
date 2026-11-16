import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/home/presentation/models/note_card_data.dart';
import 'package:margo/features/home/presentation/note_cards_provider.dart';
import 'package:margo/features/home/presentation/recent_notebooks.dart';
import 'package:margo/features/home/presentation/screens/notes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

NoteCardData _c(int id) => NoteCardData(
    id: id,
    title: 'Note $id',
    createdAt: DateTime(2026),
    pages: 1,
    type: NoteType.text);

void main() {
  test('opening a notebook moves it to the front; the list is capped', () {
    expect(pushRecent([1, 2, 3], 3), [3, 1, 2]);
    expect(pushRecent([1, 2], 9), [9, 1, 2]);
    expect(pushRecent([for (var i = 0; i < 8; i++) i], 99).length, 8);
    expect(pushRecent([for (var i = 0; i < 8; i++) i], 99).first, 99);
  });

  test('recent cards follow the saved order and skip notebooks that are gone',
      () {
    final cards = recentCards([_c(1), _c(2), _c(3)], [3, 7, 1]);
    expect(cards.map((c) => c.id), [3, 1]);
  });

  test('the list is saved and read back', () async {
    SharedPreferences.setMockInitialValues({});
    final a = RecentNotebooksNotifier();
    await a.record(4);
    await a.record(5);
    final b = RecentNotebooksNotifier();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(b.state, [5, 4]);
  });

  testWidgets('the home screen shows the strip, and hides it while searching',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'home.recentNotebooks': ['2', '1'],
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(retry: (_, _) => null, overrides: [
      noteCardsProvider.overrideWith((ref) async => [_c(1), _c(2), _c(3)]),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c, child: const MaterialApp(home: NotesScreen())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recentStrip')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent:2')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent:3')), findsNothing);

    c.read(notesSearchQueryProvider.notifier).state = 'note';
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recentStrip')), findsNothing);
  });
}
