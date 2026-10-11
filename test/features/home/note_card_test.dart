import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/core/theme/app_colors.dart';
import 'package:distill_ed/core/theme/distill_theme.dart';
import 'package:distill_ed/features/home/presentation/models/note_card_data.dart';
import 'package:distill_ed/features/home/presentation/notes_palette.dart';
import 'package:distill_ed/features/home/presentation/widgets/knowledge_graph_button.dart';
import 'package:distill_ed/features/home/presentation/widgets/note_card.dart';
import 'package:distill_ed/features/home/presentation/widgets/note_preview.dart';

NoteCardData _note({
  String title = 'Workout',
  int pages = 2,
  bool pinned = false,
}) {
  return NoteCardData(
    id: 3,
    title: title,
    createdAt: DateTime(2020, 8, 14),
    pages: pages,
    type: NoteType.text,
    pinned: pinned,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  VoidCallback? onGraphTap,
  VoidCallback? onToggleFavorite,
  bool graph = true,
  bool pinned = false,
  ThemeData? theme,
  Size size = const Size(252, 296),
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: NoteCard(
              note: _note(pinned: pinned),
              onTap: onTap,
              onLongPress: onLongPress,
              onGraphTap: graph ? (onGraphTap ?? () {}) : null,
              onToggleFavorite: onToggleFavorite,
            ),
          ),
        ),
      ),
    ),
  );
}

BoxDecoration _cardDecoration(WidgetTester tester) {
  return tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .decoration!
      as BoxDecoration;
}

Future<TestGesture> _hover(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(find.byType(NoteCard)));
  await tester.pumpAndSettle();
  return gesture;
}

void main() {
  group('shell', () {
    testWidgets('is a single card with a 20px outer radius', (tester) async {
      await _pump(tester);

      expect(NoteCard.borderRadius, BorderRadius.circular(20));
      expect(_cardDecoration(tester).borderRadius, NoteCard.borderRadius);
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('rests on the design shadow — blur 40, dropped 4', (
      tester,
    ) async {
      await _pump(tester);

      final shadow = _cardDecoration(tester).boxShadow!.single;
      expect(shadow.blurRadius, 40);
      expect(shadow.offset, const Offset(0, 4));
      expect(_cardDecoration(tester).border, isNull);
    });

    testWidgets('dark swaps the shadow for a hairline', (tester) async {
      await _pump(tester, theme: DistillTheme.dark);

      final decoration = _cardDecoration(tester);
      expect(decoration.boxShadow, isNull);
      expect(decoration.border, isNotNull);
      expect(decoration.color, AppColors.dark.surface);
    });

    testWidgets('stacks a thumbnail over a 98px footer', (tester) async {
      await _pump(tester);

      final card = tester.getRect(find.byType(NoteCard));
      final preview = tester.getRect(find.byType(NotePreview));

      expect(preview.top, card.top);
      expect(preview.height, closeTo(198, 0.5));
      expect(card.bottom - preview.bottom, closeTo(98, 0.5));
    });

    testWidgets('the grid tile ratio matches the design', (tester) async {
      expect(
        NotesPalette.cardWidth / NotesPalette.cardHeight,
        closeTo(NotesPalette.cardAspect, 1e-9),
      );
    });
  });

  group('footer', () {
    testWidgets('shows the title, page count and long date', (tester) async {
      await _pump(tester);

      expect(find.text('Workout'), findsWidgets);
      expect(find.text('2 Pages'), findsOneWidget);
      expect(find.text('14 August 2020'), findsOneWidget);
    });

    testWidgets('truncates a long title rather than overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 252,
                height: 296,
                child: NoteCard(note: _note(title: 'A' * 200)),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('favorite toggle', () {
    testWidgets('offers to add an unpinned note', (tester) async {
      await _pump(tester);

      expect(find.bySemanticsLabel('Add to favorites'), findsOneWidget);
    });

    testWidgets('offers to remove a pinned note', (tester) async {
      await _pump(tester, pinned: true);

      expect(find.bySemanticsLabel('Remove from favorites'), findsOneWidget);
    });

    testWidgets('tapping it toggles and does not open the note', (
      tester,
    ) async {
      var opened = 0;
      var toggled = 0;
      await _pump(
        tester,
        onTap: () => opened++,
        onToggleFavorite: () => toggled++,
      );

      await tester.tap(find.bySemanticsLabel('Add to favorites'));
      await tester.pumpAndSettle();

      expect(toggled, 1);
      expect(opened, 0);
    });
  });

  group('knowledge graph button', () {
    testWidgets('floats in the thumbnail\'s top-right corner', (tester) async {
      await _pump(tester);

      final preview = tester.getRect(find.byType(NotePreview));
      final button = tester.getRect(find.byType(KnowledgeGraphButton));

      expect(button.top, greaterThanOrEqualTo(preview.top));
      expect(button.right, lessThanOrEqualTo(preview.right));
      expect(button.bottom, lessThan(preview.center.dy));
    });

    testWidgets('is omitted when the card has no graph action', (tester) async {
      await _pump(tester, graph: false);

      expect(find.byType(KnowledgeGraphButton), findsNothing);
    });

    testWidgets('its tap does not also open the note', (tester) async {
      var opened = 0;
      var graphed = 0;
      await _pump(tester, onTap: () => opened++, onGraphTap: () => graphed++);

      await tester.tap(find.byType(KnowledgeGraphButton));
      await tester.pumpAndSettle();

      expect(graphed, 1);
      expect(opened, 0);
    });
  });

  group('interaction', () {
    testWidgets('tapping the card opens the note', (tester) async {
      var opened = 0;
      await _pump(tester, onTap: () => opened++);

      await tester.tapAt(tester.getCenter(find.byType(NotePreview)));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets('long-pressing the card raises its actions', (tester) async {
      var held = 0;
      await _pump(tester, onLongPress: () => held++);

      await tester.longPressAt(tester.getCenter(find.byType(NotePreview)));
      await tester.pumpAndSettle();

      expect(held, 1);
    });
  });

  group('hover', () {
    testWidgets('lifts to 1.01 and deepens its shadow, then settles back', (
      tester,
    ) async {
      await _pump(tester);

      double scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale;
      final restingAlpha = _cardDecoration(tester).boxShadow!.first.color.a;
      expect(scale(), 1.0);

      final gesture = await _hover(tester);
      expect(scale(), 1.01);
      expect(
        _cardDecoration(tester).boxShadow!.first.color.a,
        greaterThan(restingAlpha),
      );

      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(scale(), 1.0);
      expect(_cardDecoration(tester).boxShadow!.first.color.a, restingAlpha);
    });
  });
}
