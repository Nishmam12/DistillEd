import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/theme/app_colors.dart';
import 'package:inkflow/features/home/presentation/models/note_card_data.dart';
import 'package:inkflow/features/home/presentation/notes_palette.dart';
import 'package:inkflow/features/home/presentation/widgets/knowledge_graph_button.dart';
import 'package:inkflow/features/home/presentation/widgets/note_card.dart';
import 'package:inkflow/features/home/presentation/widgets/note_overlay.dart';
import 'package:inkflow/features/home/presentation/widgets/note_preview.dart';

NoteCardData _note({
  String title = 'Workout',
  int pages = 2,
  String previewText = '',
}) {
  return NoteCardData(
    id: 3,
    title: title,
    createdAt: DateTime(2020, 8, 14),
    pages: pages,
    type: NoteType.text,
    previewText: previewText,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  VoidCallback? onGraphTap,
  Size size = const Size(360, 160),
  String previewText = '',
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: NoteCard(
              note: _note(previewText: previewText),
              onTap: onTap,
              onLongPress: onLongPress,
              onGraphTap: onGraphTap ?? () {},
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
      .decoration! as BoxDecoration;
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
    testWidgets('is a single card with a 22px outer radius', (tester) async {
      await _pump(tester);

      expect(
        _cardDecoration(tester).borderRadius,
        BorderRadius.circular(NotesPalette.cardRadius),
      );
      expect(NotesPalette.cardRadius, 22.0);
      expect(_cardDecoration(tester).color, AppColors.light.surface);
    });

    testWidgets('rests on a soft shadow — blur ~20 at ~10% opacity',
        (tester) async {
      await _pump(tester);

      final shadow = _cardDecoration(tester).boxShadow!.first;
      expect(shadow.blurRadius, closeTo(20, 4));
      expect(shadow.color.a, closeTo(0.10, 0.03));
    });
  });

  group('layout', () {
    testWidgets('splits the card ~1/3 overlay to ~2/3 preview', (tester) async {
      await _pump(tester);

      final cardWidth = tester.getSize(find.byType(NoteCard)).width;
      final overlayWidth = tester.getSize(find.byType(NoteOverlay)).width;

      expect(overlayWidth / cardWidth, inInclusiveRange(0.30, 0.35));
    });

    testWidgets('the preview runs the full width, under the overlay',
        (tester) async {
      await _pump(tester);

      final card = tester.getRect(find.byType(NoteCard));
      final preview = tester.getRect(find.byType(NotePreview));

      expect(preview.left, card.left);
      expect(preview.right, card.right);
      expect(preview.height, card.height);
    });

    testWidgets('leaves no gap between the overlay and the preview beside it',
        (tester) async {
      await _pump(tester);

      final card = tester.getRect(find.byType(NoteCard));
      final overlay = tester.getRect(find.byType(NoteOverlay));

      expect(overlay.left, card.left);
      expect(overlay.top, card.top);
      expect(overlay.bottom, card.bottom);
      // Its inner edge lands inside the card, with preview on both sides of it.
      expect(overlay.right, lessThan(card.right));
    });

    testWidgets('re-proportions itself when the card gets wider',
        (tester) async {
      await _pump(tester, size: const Size(720, 170));

      final overlayWidth = tester.getSize(find.byType(NoteOverlay)).width;
      expect(overlayWidth, closeTo(720 * NotesPalette.overlayWidthFactor, 0.5));
    });
  });

  group('knowledge graph button', () {
    testWidgets('floats over the preview, clear of the overlay',
        (tester) async {
      await _pump(tester);

      final card = tester.getRect(find.byType(NoteCard));
      final overlay = tester.getRect(find.byType(NoteOverlay));
      final button = tester.getRect(find.byType(KnowledgeGraphButton));

      expect(button.left, greaterThan(overlay.right));
      expect(button.right, lessThan(card.right));
      expect(button.center.dy, closeTo(card.center.dy, 0.5));
    });

    testWidgets('never covers the preview\'s own text', (tester) async {
      // The preview's text is the first page's recognised content. It used to
      // be the note title set in caps; that was removed because the details
      // column beside it already shows the title.
      await _pump(tester, previewText: 'Admitting fault');

      final line = tester.getRect(find.text('Admitting fault'));
      final button = tester.getRect(find.byType(KnowledgeGraphButton));

      expect(line.right, lessThanOrEqualTo(button.left));
    });

    testWidgets('is omitted when the card has no graph action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 160,
                child: NoteCard(note: _note()),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(KnowledgeGraphButton), findsNothing);
    });

    testWidgets('its tap does not also open the note', (tester) async {
      var opened = 0;
      var graphed = 0;
      await _pump(
        tester,
        onTap: () => opened++,
        onGraphTap: () => graphed++,
      );

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

      await tester.tapAt(tester.getCenter(find.byType(NoteOverlay)));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets('long-pressing the card raises its actions', (tester) async {
      var held = 0;
      await _pump(tester, onLongPress: () => held++);

      await tester.longPressAt(tester.getCenter(find.byType(NoteOverlay)));
      await tester.pumpAndSettle();

      expect(held, 1);
    });
  });

  group('hover', () {
    testWidgets('lifts to 1.01 and deepens its shadow, then settles back',
        (tester) async {
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
