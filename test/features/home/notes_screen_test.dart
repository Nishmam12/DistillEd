import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/core/theme/app_colors.dart';
import 'package:distill_ed/features/home/presentation/models/note_card_data.dart';
import 'package:distill_ed/features/home/presentation/note_cards_provider.dart';
import 'package:distill_ed/features/home/presentation/notes_palette.dart';
import 'package:distill_ed/features/home/presentation/screens/notes_screen.dart';
import 'package:distill_ed/features/home/presentation/widgets/note_card.dart';
import 'package:distill_ed/features/home/presentation/widgets/note_preview.dart';
import 'package:distill_ed/features/home/presentation/widgets/home_sidebar.dart';
import 'package:distill_ed/features/home/presentation/widgets/new_note_dialog.dart';
import 'package:distill_ed/features/home/presentation/widgets/search_bar_widget.dart';

NoteCardData _card(
  int id,
  String title, {
  DateTime? createdAt,
  bool pinned = false,
}) {
  return NoteCardData(
    id: id,
    title: title,
    createdAt: createdAt ?? DateTime(2021, 7, 26),
    pages: 3,
    type: NoteType.text,
    pinned: pinned,
  );
}

final _cards = [
  _card(1, 'IDs'),
  _card(2, 'Pasig Pass'),
  _card(3, 'Unilab OR'),
  _card(4, 'Better Creator'),
  _card(5, 'Workout'),
  _card(6, 'Better Person'),
  _card(7, 'Grocery'),
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<NoteCardData>? cards,
  Size surface = const Size(1280, 800),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [noteCardsProvider.overrideWith((ref) async => cards ?? _cards)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NotesScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('chrome', () {
    testWidgets('sits on the cream canvas', (tester) async {
      await _pump(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.light.bgPrimary);
    });

    testWidgets('leads with a large semibold Notes title', (tester) async {
      await _pump(tester);

      // One in the sidebar, one as the page title.
      expect(find.text('Notes'), findsNWidgets(2));
      final title = tester
          .widgetList<Text>(find.text('Notes'))
          .firstWhere((t) => t.style!.fontSize == 40);
      expect(title.style!.fontWeight, FontWeight.w600);
    });

    testWidgets('has search, profile and settings up top', (tester) async {
      await _pump(tester);

      expect(find.byTooltip('Search'), findsOneWidget);
      expect(find.byTooltip('About'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
    });

    testWidgets('shows the current sort beside the sort glyph', (tester) async {
      await _pump(tester);

      expect(find.text(NotesSort.recent.label), findsOneWidget);
    });

    testWidgets('floats a "+ new" pill bottom-right', (tester) async {
      await _pump(tester);

      final screen = tester.getRect(find.byType(NotesScreen));
      final pill = tester.getRect(find.text('new'));
      expect(pill.center.dx, greaterThan(screen.center.dx));
      expect(pill.center.dy, greaterThan(screen.center.dy));
      expect(find.text('new'), findsOneWidget);
    });
  });

  group('sidebar', () {
    testWidgets('is pinned beside the grid on a wide screen', (tester) async {
      await _pump(tester);

      expect(find.text('margo'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Folders'), findsOneWidget);
      expect(
        tester.getSize(find.byType(HomeSidebar)).width,
        NotesPalette.sidebarWidthFor(1280),
      );
    });

    testWidgets('counts the notes beside Notes', (tester) async {
      await _pump(tester);

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('collapses and comes back', (tester) async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Hide sidebar'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeSidebar), findsNothing);

      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeSidebar), findsOneWidget);
    });

    testWidgets('Shared is shown but disabled', (tester) async {
      await _pump(tester);

      expect(find.text('Shared'), findsOneWidget);
      expect(find.text('Soon'), findsOneWidget);
      final inkWell = tester.widget<InkWell>(
        find.ancestor(of: find.text('Shared'), matching: find.byType(InkWell)),
      );
      expect(inkWell.onTap, isNull);
    });

    testWidgets('becomes a drawer on a narrow screen', (tester) async {
      await _pump(tester, surface: const Size(430, 932));

      expect(find.byType(HomeSidebar), findsNothing);

      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      expect(find.text('margo'), findsOneWidget);

      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('margo'), findsNothing);
    });
  });

  group('grid', () {
    testWidgets('lays cards out in columns with the design gap', (
      tester,
    ) async {
      await _pump(tester);

      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.padding, NotesPalette.contentPadding);

      final a = tester.getRect(find.byType(NoteCard).at(0));
      final b = tester.getRect(find.byType(NoteCard).at(1));
      final c = tester.getRect(find.byType(NoteCard).at(2));
      expect(a.top, b.top);
      expect(b.top, c.top);
      expect(b.left - a.right, NotesPalette.gridGap);
      // The thumbnail keeps the design's 252:198 shape at whatever width the
      // column lands on; the footer is a fixed height below it.
      final thumb = tester.getRect(find.byType(NotePreview).first);
      expect(thumb.height / thumb.width,
          closeTo(NotesPalette.thumbnailAspect, 0.01));
      expect(a.height - thumb.height, 98);
    });

    testWidgets('scrolls to later notes', (tester) async {
      await _pump(tester, cards: [
        for (var i = 0; i < 30; i++) _card(i + 1, 'Note ${i + 1}'),
      ]);

      expect(find.text('Note 30'), findsNothing);

      await tester.drag(find.byType(GridView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      expect(find.text('Note 30'), findsOneWidget);
    });

    testWidgets('a phone still gets a usable grid', (tester) async {
      await _pump(tester, surface: const Size(430, 932));

      expect(find.byType(NoteCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('favorites', () {
    final cards = [
      _card(1, 'IDs', pinned: true),
      _card(2, 'Pasig Pass'),
      _card(3, 'Unilab OR', pinned: true),
    ];

    testWidgets('the sidebar entry narrows to pinned notes', (tester) async {
      final container = await _pump(tester, cards: cards);

      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();

      expect(container.read(notesFavoritesOnlyProvider), isTrue);
      expect(find.byType(NoteCard), findsNWidgets(2));
      expect(find.text('Pasig Pass'), findsNothing);
      // The page title follows the scope.
      expect(find.text('Favorites'), findsNWidgets(2));
    });

    testWidgets('Notes clears it again', (tester) async {
      final container = await _pump(tester, cards: cards);

      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes').first);
      await tester.pumpAndSettle();

      expect(container.read(notesFavoritesOnlyProvider), isFalse);
      expect(find.byType(NoteCard), findsNWidgets(3));
    });

    testWidgets('says so when nothing is starred', (tester) async {
      await _pump(tester, cards: [_card(1, 'IDs')]);

      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();

      expect(find.text('No favorites yet'), findsOneWidget);
    });
  });

  group('search popover', () {
    testWidgets('opens under the search icon with every note listed', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchBarWidget), findsOneWidget);
      // Capped at five rows.
      expect(find.text('3 Pages'), findsWidgets);
    });

    testWidgets('narrows its rows to the query, leaving the grid alone', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'better');
      await tester.pumpAndSettle();

      expect(find.text('Better Creator'), findsNWidgets(2)); // row + card
      expect(find.text('Better Person'), findsNWidgets(2));
      expect(find.text('IDs'), findsOneWidget); // only its card
    });

    testWidgets('explains an empty result', (tester) async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('No notes match'), findsOneWidget);
    });

    testWidgets('closes when you tap away', (tester) async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(700, 700));
      await tester.pumpAndSettle();

      expect(find.byType(SearchBarWidget), findsNothing);
    });
  });

  group('empty library', () {
    testWidgets('invites the first note', (tester) async {
      await _pump(tester, cards: []);

      expect(find.text('No notes here'), findsOneWidget);
      expect(find.byType(NoteCard), findsNothing);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('new note', () {
    testWidgets('"+ new" opens the template dialog, Cancel dismisses it', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('new'));
      await tester.pumpAndSettle();
      expect(find.byType(NewNoteDialog), findsOneWidget);
      expect(find.text('Template'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(NewNoteDialog), findsNothing);
    });
  });

  group('sort', () {
    testWidgets('the sort row offers the sort options', (tester) async {
      await _pump(tester);

      await tester.tap(find.text(NotesSort.recent.label));
      await tester.pumpAndSettle();

      for (final sort in NotesSort.values) {
        expect(find.text(sort.label), findsWidgets);
      }
    });

    testWidgets('picking a sort reorders the list', (tester) async {
      final container = await _pump(tester);

      await tester.tap(find.text(NotesSort.recent.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(NotesSort.title.label).last);
      await tester.pumpAndSettle();

      expect(container.read(notesSortProvider), NotesSort.title);
      final titles = container
          .read(visibleNoteCardsProvider)
          .requireValue
          .map((card) => card.title)
          .toList();
      expect(titles.first, 'Better Creator');
      expect(titles.last, 'Workout');
    });
  });

  group('sorting', () {
    test('recent keeps the repository order', () {
      expect(sortCards(_cards, NotesSort.recent), _cards);
    });

    test('created puts the newest note first', () {
      final cards = [
        _card(1, 'old', createdAt: DateTime(2019, 1, 1)),
        _card(2, 'new', createdAt: DateTime(2023, 1, 1)),
      ];

      expect(sortCards(cards, NotesSort.created).map((card) => card.title), [
        'new',
        'old',
      ]);
    });

    test('title sorts case-insensitively', () {
      final cards = [_card(1, 'banana'), _card(2, 'Apple')];

      expect(sortCards(cards, NotesSort.title).map((card) => card.title), [
        'Apple',
        'banana',
      ]);
    });

    test('pinned notes lead, keeping the chosen order within each group', () {
      final cards = [
        _card(1, 'Zebra'),
        NoteCardData(
          id: 2,
          title: 'Pinned B',
          createdAt: DateTime(2021, 1, 1),
          pages: 1,
          type: NoteType.text,
          pinned: true,
        ),
        _card(3, 'Apple'),
        NoteCardData(
          id: 4,
          title: 'Pinned A',
          createdAt: DateTime(2021, 1, 1),
          pages: 1,
          type: NoteType.text,
          pinned: true,
        ),
      ];

      expect(sortCards(cards, NotesSort.title).map((card) => card.title), [
        'Pinned A',
        'Pinned B',
        'Apple',
        'Zebra',
      ]);
    });

    test('does not mutate the list it was given', () {
      final cards = [_card(1, 'banana'), _card(2, 'Apple')];
      sortCards(cards, NotesSort.title);

      expect(cards.map((card) => card.title), ['banana', 'Apple']);
    });
  });
}
