import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:inkflow/core/theme/app_colors.dart';
import 'package:inkflow/features/home/presentation/notes_palette.dart';
import 'package:inkflow/features/home/presentation/widgets/knowledge_graph_button.dart';

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onTap,
  double? radius,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: KnowledgeGraphButton(
            onTap: onTap ?? () {},
            radius: radius ?? NotesPalette.graphButtonRadius,
          ),
        ),
      ),
    ),
  );
}

BoxDecoration _decoration(WidgetTester tester) {
  return tester
      .widget<Container>(
        find.descendant(
          of: find.byType(KnowledgeGraphButton),
          matching: find.byType(Container),
        ),
      )
      .decoration! as BoxDecoration;
}

void main() {
  testWidgets('is a white circle at the spec radius', (tester) async {
    await _pump(tester);

    final decoration = _decoration(tester);
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, AppColors.light.surface);
    expect(NotesPalette.graphButtonRadius, 26.0);
    expect(
      tester.getSize(find.byType(KnowledgeGraphButton)),
      const Size(52, 52),
    );
  });

  testWidgets('scales with a caller-supplied radius', (tester) async {
    await _pump(tester, radius: 20);

    expect(
      tester.getSize(find.byType(KnowledgeGraphButton)),
      const Size(40, 40),
    );
  });

  testWidgets('floats on a shadow stronger than a card at rest',
      (tester) async {
    await _pump(tester);

    final shadows = _decoration(tester).boxShadow!;
    expect(shadows, isNotEmpty);
    // The note card's own resting alpha (see `note_card.dart`). The button
    // floats ABOVE the card, so it has to cast the heavier shadow of the two or
    // it reads as printed on the thumbnail rather than hovering over it.
    const cardRestingAlpha = 0.08;
    expect(shadows.first.color.a, greaterThan(cardRestingAlpha));
  });

  testWidgets('carries a network icon', (tester) async {
    await _pump(tester);

    expect(find.byIcon(PhosphorIconsRegular.asterisk), findsOneWidget);
  });

  testWidgets('reports itself to screen readers as a button', (tester) async {
    await _pump(tester);

    expect(
      tester.getSemantics(find.byType(KnowledgeGraphButton).first),
      isSemantics(
        isButton: true,
        label: 'Knowledge graph',
        hasTapAction: true,
      ),
    );
  });

  testWidgets('invokes its callback on tap', (tester) async {
    var taps = 0;
    await _pump(tester, onTap: () => taps++);

    await tester.tap(find.byType(KnowledgeGraphButton));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('dips while pressed and springs back on release',
      (tester) async {
    await _pump(tester);

    double scale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    expect(scale(), 1.0);

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(AnimatedScale)));
    // The tooltip's long-press recognizer shares the arena, so the tap's
    // down callback only fires once the press deadline passes.
    await tester.pump(const Duration(milliseconds: 150));
    expect(scale(), lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(), 1.0);
  });

  testWidgets('springs back when the press is cancelled', (tester) async {
    await _pump(tester);

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(AnimatedScale)));
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      lessThan(1.0),
    );

    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      1.0,
    );
  });
}
