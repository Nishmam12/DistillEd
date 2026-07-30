import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/theme/ink_palette.dart';
import 'package:inkflow/features/home/presentation/models/note_card_data.dart';
import 'package:inkflow/features/home/presentation/notes_palette.dart';
import 'package:inkflow/features/home/presentation/widgets/note_overlay.dart';

NoteCardData _note({
  String title = 'Pasig Pass',
  DateTime? createdAt,
  int pages = 1,
  bool pinned = false,
}) {
  return NoteCardData(
    id: 1,
    title: title,
    createdAt: createdAt ?? DateTime(2021, 5, 31),
    pages: pages,
    type: NoteType.text,
    pinned: pinned,
  );
}

Future<void> _pump(WidgetTester tester, NoteCardData note) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 120,
            height: 160,
            child: NoteOverlay(note: note),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('content', () {
    testWidgets('shows the title, creation date and page count',
        (tester) async {
      await _pump(tester, _note(title: 'Unilab OR', pages: 1));

      expect(find.text('Unilab OR'), findsOneWidget);
      expect(find.text('5/31/21'), findsOneWidget);
      expect(find.text('1 page'), findsOneWidget);
    });

    testWidgets('pluralises a multi-page note', (tester) async {
      await _pump(tester, _note(pages: 3));

      expect(find.text('3 pages'), findsOneWidget);
    });

    testWidgets('marks a pinned note', (tester) async {
      await _pump(tester, _note(pinned: true));

      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    });

    testWidgets('leaves the pin off an unpinned note', (tester) async {
      await _pump(tester, _note());

      expect(find.byIcon(Icons.push_pin_rounded), findsNothing);
    });

    testWidgets('truncates a long title rather than overflowing',
        (tester) async {
      await _pump(
        tester,
        _note(title: 'A gratuitously long note title that will not fit'),
      );

      final title = tester.widget<Text>(
        find.text('A gratuitously long note title that will not fit'),
      );
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  });

  group('typography', () {
    testWidgets('title is 20 semibold in primary ink', (tester) async {
      await _pump(tester, _note(title: 'IDs'));

      final style = tester.widget<Text>(find.text('IDs')).style!;
      expect(style.fontSize, 20);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, InkPalette.light.notes.textPrimary);
    });

    testWidgets('metadata is 14 medium grey', (tester) async {
      await _pump(tester, _note(pages: 2));

      for (final label in ['5/31/21', '2 pages']) {
        final style = tester.widget<Text>(find.text(label)).style!;
        expect(style.fontSize, 14, reason: label);
        expect(style.fontWeight, FontWeight.w500, reason: label);
        expect(style.color, InkPalette.light.notes.textSecondary, reason: label);
      }
    });
  });

  group('glass', () {
    testWidgets('blurs what is behind it at sigma 8', (tester) async {
      await _pump(tester, _note());

      final filter =
          tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter;
      expect(NotesPalette.overlayBlurSigma, 8.0);
      expect(filter.toString(), contains('8.0'));
    });

    testWidgets('rounds only the outer edge, leaving the inner edge straight',
        (tester) async {
      await _pump(tester, _note());

      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      final radius = clip.borderRadius as BorderRadius;
      expect(radius.topLeft.x, NotesPalette.cardRadius);
      expect(radius.bottomLeft.x, NotesPalette.cardRadius);
      expect(radius.topRight, Radius.zero);
      expect(radius.bottomRight, Radius.zero);
    });

    testWidgets('casts a soft shadow sideways onto the preview',
        (tester) async {
      await _pump(tester, _note());

      final decoration = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((decoration) => decoration.boxShadow != null);

      final shadow = decoration.boxShadow!.single;
      expect(shadow.offset.dx, greaterThan(0));
      expect(shadow.offset.dy, 0);
      expect(shadow.blurRadius, greaterThan(0));
      expect(shadow.color.a, lessThan(0.2));
    });

    testWidgets('fills its whole box, so no gap opens beside the preview',
        (tester) async {
      await _pump(tester, _note());

      expect(tester.getSize(find.byType(NoteOverlay)), const Size(120, 160));
      expect(
        tester.getSize(find.byType(BackdropFilter)),
        const Size(120, 160),
      );
    });
  });
}
