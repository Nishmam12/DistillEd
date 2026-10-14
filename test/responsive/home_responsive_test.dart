import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/core/theme/margo_theme.dart';
import 'package:margo/features/home/presentation/models/note_card_data.dart';
import 'package:margo/features/home/presentation/note_cards_provider.dart';
import 'package:margo/features/home/presentation/screens/notes_screen.dart';
import 'package:margo/core/layout/window_size.dart';
import 'package:margo/features/home/presentation/widgets/home_sidebar.dart';
import 'package:margo/features/home/presentation/widgets/new_note_dialog.dart';
import 'package:margo/features/home/presentation/widgets/note_card.dart';
import 'package:margo/features/home/presentation/widgets/search_bar_widget.dart';

import '../support/device_matrix.dart';
import '../support/load_fonts.dart';

NoteCardData _c(int i, String t, {bool pinned = false, String text = ''}) =>
    NoteCardData(
      id: i,
      title: t,
      createdAt: DateTime(2027, 7, 9),
      pages: 7,
      type: NoteType.text,
      previewText: text,
      pinned: pinned,
    );

final _cards = [
  _c(1, 'Notepad 1', pinned: true, text: 'Plants to buy\nPetunias\nMonstera'),
  _c(2, 'A very long note title that will certainly need to be truncated'),
  _c(3, 'CSE470'),
  _c(4, 'Thermodynamics — lecture 12: entropy and the second law'),
  _c(5, 'x'),
  _c(6, 'Notepad 6', text: '- eggs\n- rice\n- milk'),
];

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  double textScale = 1.0,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [noteCardsProvider.overrideWith((ref) async => _cards)],
      child: MaterialApp(
        theme: theme ?? MargoTheme.light,
        home: const NotesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  for (final device in androidDevices) {
    for (final landscape in [false, true]) {
      for (final scale in textScales) {
        final size = landscape ? device.landscape : device.portrait;
        final label =
            '$device ${landscape ? 'landscape' : 'portrait'} @${scale}x';

        testWidgets('home: $label', (tester) async {
          await _pump(tester, size, textScale: scale);

          // Overflow and layout errors surface here.
          expect(tester.takeException(), isNull);
          expect(find.byType(NoteCard), findsWidgets);

          // Every card sits inside the screen horizontally.
          for (final e in find.byType(NoteCard).evaluate()) {
            final r = tester.getRect(find.byWidget(e.widget));
            expect(r.left, greaterThanOrEqualTo(0), reason: 'card off left');
            expect(
              r.right,
              lessThanOrEqualTo(size.width + 0.5),
              reason: 'card off right',
            );
            expect(r.width, greaterThan(100), reason: 'card too narrow');
          }

          // The sidebar is pinned exactly on expanded windows.
          final expanded = WindowSize.ofWidth(size.width).isExpanded;
          expect(
            find.byType(HomeSidebar),
            expanded ? findsOneWidget : findsNothing,
          );
        });

        testWidgets('home overlays: $label', (tester) async {
          await _pump(tester, size, textScale: scale);

          // Sidebar drawer (windows that don't pin it).
          if (!WindowSize.ofWidth(size.width).isExpanded) {
            await tester.tap(find.byTooltip('Show sidebar'));
            await tester.pumpAndSettle();
            expect(find.byType(HomeSidebar), findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'drawer overflow');
            await tester.tapAt(Offset(size.width - 4, size.height / 2));
            await tester.pumpAndSettle();
          }

          // Search popover.
          await tester.tap(find.byTooltip('Search'));
          await tester.pumpAndSettle();
          expect(find.byType(SearchBarWidget), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'popover overflow');
          final panel = tester.getRect(find.byType(SearchBarWidget));
          expect(
            panel.left,
            greaterThanOrEqualTo(0),
            reason: 'popover off left',
          );
          expect(
            panel.right,
            lessThanOrEqualTo(size.width + 0.5),
            reason: 'popover off right',
          );
          await tester.tapAt(Offset(size.width / 2, size.height - 4));
          await tester.pumpAndSettle();

          // New-note dialog.
          await tester.tap(find.text('new'));
          await tester.pumpAndSettle();
          expect(find.byType(NewNoteDialog), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'dialog overflow');
          final dialog = tester.getRect(find.byType(NewNoteDialog));
          expect(dialog.left, greaterThanOrEqualTo(0));
          expect(dialog.right, lessThanOrEqualTo(size.width + 0.5));
        });
      }
    }
  }
}
