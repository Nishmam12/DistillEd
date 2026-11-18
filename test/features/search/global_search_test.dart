import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/data/persistence/page_text_store.dart';
import 'package:margo/features/home/presentation/models/note_card_data.dart';
import 'package:margo/features/home/presentation/note_cards_provider.dart';
import 'package:margo/features/home/presentation/screens/notes_screen.dart';
import 'package:margo/features/home/presentation/widgets/search_bar_widget.dart';
import 'package:margo/features/search/domain/global_search.dart';
import 'package:margo/features/search/presentation/global_search_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

PageText _t(int pageId, int nb, String text) =>
    PageText(pageId: pageId, notebookId: nb, text: text);

final _corpus = [
  NotebookCorpus(
    notebookId: 1,
    title: 'Biology',
    texts: [
      _t(10, 1, 'The mitochondria is the powerhouse of the cell'),
      _t(11, 1, 'Cell walls and mitochondria in plants'),
      _t(12, 1, 'Mitochondria again, and again mitochondria'),
      _t(13, 1, 'More about the mitochondria here'),
    ],
    pageIndexById: {10: 0, 11: 1, 12: 2, 13: 3},
  ),
  NotebookCorpus(
    notebookId: 2,
    title: 'Chemistry',
    texts: [_t(20, 2, 'Nothing relevant'), _t(21, 2, 'Mitochondria energy')],
    pageIndexById: {20: 0, 21: 1},
  ),
];

void main() {
  group('searchAcrossNotebooks', () {
    test('finds pages in several notebooks, one hit per page', () {
      final hits = searchAcrossNotebooks(_corpus, 'mitochondria');
      expect(hits.map((h) => (h.notebookTitle, h.hit.pageIndex)), [
        ('Biology', 0),
        ('Biology', 1),
        ('Biology', 2),
        ('Chemistry', 1),
      ]);
      expect(hits.first.hit.snippet, contains('mitochondria'));
    });

    test('a big notebook cannot crowd out the others, and total is capped', () {
      final capped = searchAcrossNotebooks(_corpus, 'mitochondria',
          maxPerNotebook: 2);
      expect(capped.where((h) => h.notebookId == 1), hasLength(2));
      expect(capped.any((h) => h.notebookId == 2), isTrue);
      expect(searchAcrossNotebooks(_corpus, 'mitochondria', maxTotal: 1),
          hasLength(1));
    });

    test('an empty or unmatched query finds nothing', () {
      expect(searchAcrossNotebooks(_corpus, '  '), isEmpty);
      expect(searchAcrossNotebooks(_corpus, 'zebra'), isEmpty);
    });
  });

  testWidgets('the home search lists page matches and opens one',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(retry: (_, _) => null, overrides: [
      noteCardsProvider.overrideWith((ref) async => [
            NoteCardData(
                id: 1,
                title: 'Biology',
                createdAt: DateTime(2026),
                pages: 4,
                type: NoteType.text),
          ]),
      globalSearchCorpusProvider.overrideWith((ref) async => _corpus),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c, child: const MaterialApp(home: NotesScreen())));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(SearchBarWidget), matching: find.byType(TextField)),
        'mitochondria');
    await tester.pumpAndSettle();
    expect(find.text('On pages'), findsOneWidget);
    expect(find.text('Chemistry · Page 2'), findsOneWidget);
  });
}
