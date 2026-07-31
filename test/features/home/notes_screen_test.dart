import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/theme/app_colors.dart';
import 'package:inkflow/features/home/presentation/models/note_card_data.dart';
import 'package:inkflow/features/home/presentation/note_cards_provider.dart';
import 'package:inkflow/features/home/presentation/notes_palette.dart';
import 'package:inkflow/features/home/presentation/screens/notes_screen.dart';
import 'package:inkflow/features/home/presentation/widgets/note_card.dart';
import 'package:inkflow/features/home/presentation/widgets/search_bar_widget.dart';

NoteCardData _card(int id, String title, {DateTime? createdAt}) {
  return NoteCardData(
    id: id,
    title: title,
    createdAt: createdAt ?? DateTime(2021, 7, 26),
    pages: 3,
    type: NoteType.text,
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
  Size surface = const Size(430, 932),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      noteCardsProvider.overrideWith((ref) async => cards ?? _cards),
    ],
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

int _fullyVisibleCards(WidgetTester tester, Rect viewport) {
  return find
      .byType(NoteCard)
      .evaluate()
      .map((element) => tester.getRect(find.byWidget(element.widget)))
      .where((rect) => rect.bottom <= viewport.bottom)
      .length;
}

void main() {
  group('chrome', () {
    testWidgets('sits on the near-white canvas', (tester) async {
      await _pump(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.light.bgPrimary);
    });

    testWidgets('leads with a large bold DistillEd title', (tester) async {
      await _pump(tester);

      final title = tester.widget<Text>(find.text('DistillEd'));
      expect(title.style!.fontSize, 38);
      expect(title.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('keeps its chrome inside the safe area', (tester) async {
      await _pump(tester);

      expect(find.byType(SafeArea), findsWidgets);
      expect(find.byType(SearchBarWidget), findsOneWidget);
    });

    testWidgets('counts the notes on show', (tester) async {
      await _pump(tester);

      expect(find.text('7 Notes'), findsOneWidget);
    });

    testWidgets('singularises a lone note', (tester) async {
      await _pump(tester, cards: [_card(1, 'IDs')]);

      expect(find.text('1 Note'), findsOneWidget);
    });
  });

  group('list', () {
    testWidgets('spaces cards 16px apart with the spec padding',
        (tester) async {
      await _pump(tester);

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.padding, NotesPalette.listPadding);
      expect(NotesPalette.listPadding, const EdgeInsets.fromLTRB(18, 20, 18, 120));

      final first = tester.getRect(find.byType(NoteCard).at(0));
      final second = tester.getRect(find.byType(NoteCard).at(1));
      expect(second.top - first.bottom, NotesPalette.cardGap);
    });

    testWidgets('sizes cards so five fit, within the 150–170 band',
        (tester) async {
      await _pump(tester);

      final height = tester.getSize(find.byType(NoteCard).first).height;
      expect(
        height,
        inInclusiveRange(
          NotesPalette.cardHeightMin,
          NotesPalette.cardHeightMax,
        ),
      );
    });

    testWidgets('never squeezes cards below the band on a short screen',
        (tester) async {
      await _pump(tester, surface: const Size(430, 560));

      expect(
        tester.getSize(find.byType(NoteCard).first).height,
        greaterThanOrEqualTo(NotesPalette.cardHeightMin),
      );
    });

    testWidgets('shows five full cards on a tablet-height viewport',
        (tester) async {
      await _pump(tester, surface: const Size(834, 1194));

      final viewport = tester.getRect(find.byType(ListView));
      expect(_fullyVisibleCards(tester, viewport), inInclusiveRange(5, 6));
    });

    testWidgets('reaches into a fifth card even on a phone', (tester) async {
      await _pump(tester);

      final viewport = tester.getRect(find.byType(ListView));
      final reached = find
          .byType(NoteCard)
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .where((rect) => rect.top < viewport.bottom)
          .length;

      // Four whole cards plus a slice of the fifth: the most the 150px floor
      // allows on a phone, and never a cramped sixth.
      expect(reached, greaterThanOrEqualTo(5));
      expect(_fullyVisibleCards(tester, viewport), greaterThanOrEqualTo(4));
    });

    testWidgets('the cards scroll under the fixed bottom bar', (tester) async {
      await _pump(tester);

      expect(find.text('Grocery'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Grocery'), findsOneWidget);
      expect(find.text('7 Notes'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('narrows the list to matching notes', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'better');
      await tester.pumpAndSettle();

      expect(find.text('Better Creator'), findsOneWidget);
      expect(find.text('Better Person'), findsOneWidget);
      expect(find.text('Grocery'), findsNothing);
      expect(find.text('2 Notes'), findsOneWidget);
    });

    testWidgets('explains an empty result instead of showing a blank page',
        (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.byType(NoteCard), findsNothing);
      expect(find.textContaining('No notes match'), findsOneWidget);
    });
  });

  group('empty library', () {
    testWidgets('invites the first note', (tester) async {
      await _pump(tester, cards: []);

      expect(find.text('No notes yet'), findsOneWidget);
      expect(find.byType(NoteCard), findsNothing);
      expect(find.text('0 Notes'), findsOneWidget);
    });
  });

  group('bottom controls', () {
    testWidgets('puts filter bottom-left and compose bottom-right',
        (tester) async {
      await _pump(tester);

      final screen = tester.getRect(find.byType(NotesScreen));
      final filter = tester.getRect(find.byTooltip('Sort notes'));
      final compose = tester.getRect(find.byTooltip('New note'));

      expect(filter.center.dx, lessThan(screen.center.dx));
      expect(compose.center.dx, greaterThan(screen.center.dx));
      for (final button in [filter, compose]) {
        expect(button.center.dy, greaterThan(screen.center.dy));
      }
    });

    testWidgets('the filter button offers the sort options', (tester) async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Sort notes'));
      await tester.pumpAndSettle();

      for (final sort in NotesSort.values) {
        expect(find.text(sort.label), findsOneWidget);
      }
    });

    testWidgets('picking a sort reorders the list', (tester) async {
      final container = await _pump(tester);

      await tester.tap(find.byTooltip('Sort notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(NotesSort.title.label));
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

  group('cardHeightFor', () {
    test('fits five cards exactly when the viewport allows', () {
      // 20 top padding + 5×160 + 4×16 gaps = 884.
      expect(NotesScreen.cardHeightFor(884), 160);
    });

    test('never goes below the 150px floor on a short viewport', () {
      expect(NotesScreen.cardHeightFor(400), NotesPalette.cardHeightMin);
    });

    test('never exceeds the 170px ceiling on a tall viewport', () {
      expect(NotesScreen.cardHeightFor(4000), NotesPalette.cardHeightMax);
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

      expect(
        sortCards(cards, NotesSort.created).map((card) => card.title),
        ['new', 'old'],
      );
    });

    test('title sorts case-insensitively', () {
      final cards = [_card(1, 'banana'), _card(2, 'Apple')];

      expect(
        sortCards(cards, NotesSort.title).map((card) => card.title),
        ['Apple', 'banana'],
      );
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

      expect(
        sortCards(cards, NotesSort.title).map((card) => card.title),
        ['Pinned A', 'Pinned B', 'Apple', 'Zebra'],
      );
    });

    test('does not mutate the list it was given', () {
      final cards = [_card(1, 'banana'), _card(2, 'Apple')];
      sortCards(cards, NotesSort.title);

      expect(cards.map((card) => card.title), ['banana', 'Apple']);
    });
  });
}
