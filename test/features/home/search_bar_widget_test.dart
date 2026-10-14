import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/core/icons/phosphor_icons_regular.dart';
import 'package:margo/core/theme/app_colors.dart';
import 'package:margo/features/home/presentation/widgets/search_bar_widget.dart';

Future<void> _pump(
  WidgetTester tester, {
  TextEditingController? controller,
  ValueChanged<String>? onChanged,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: SearchBarWidget(
            controller: controller,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
}

/// The clear affordance's own fade/ignore wrappers — scoped to the close icon
/// so the finders cannot latch onto framework internals.
Finder _clearFade() => find
    .ancestor(
      of: find.byIcon(PhosphorIconsRegular.x),
      matching: find.byType(AnimatedOpacity),
    )
    .first;

Finder _clearGate() => find
    .ancestor(
      of: find.byIcon(PhosphorIconsRegular.x),
      matching: find.byType(IgnorePointer),
    )
    .first;

void main() {
  testWidgets('stands 32px tall', (tester) async {
    await _pump(tester);

    expect(SearchBarWidget.height, 32.0);
    expect(tester.getSize(find.byType(SearchBarWidget)).height, 32.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the hint', (tester) async {
    await _pump(tester);

    expect(find.text('Search..'), findsOneWidget);
  });

  testWidgets('is bare text with a half-strength hint (design)',
      (tester) async {
    await _pump(tester);

    final decoration =
        tester.widget<TextField>(find.byType(TextField)).decoration!;

    expect(decoration.filled, isFalse);
    expect(decoration.enabledBorder, InputBorder.none);
    expect(
      decoration.hintStyle!.color,
      AppColors.light.textPrimary.withValues(alpha: 0.5),
    );
  });

  testWidgets('reports every keystroke', (tester) async {
    final seen = <String>[];
    await _pump(tester, onChanged: seen.add);

    await tester.enterText(find.byType(TextField), 'gro');
    await tester.pump();

    expect(seen.last, 'gro');
  });

  group('clear affordance', () {
    testWidgets('stays hidden and inert while the field is empty',
        (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      expect(tester.widget<AnimatedOpacity>(_clearFade()).opacity, 0);
      expect(tester.widget<IgnorePointer>(_clearGate()).ignoring, isTrue);
    });

    testWidgets('fades in once there is a query', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'workout');
      await tester.pumpAndSettle();

      expect(tester.widget<AnimatedOpacity>(_clearFade()).opacity, 1);
      expect(tester.widget<IgnorePointer>(_clearGate()).ignoring, isFalse);
    });

    testWidgets('empties the field and reports the reset', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final seen = <String>[];
      await _pump(tester, controller: controller, onChanged: seen.add);

      await tester.enterText(find.byType(TextField), 'workout');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(PhosphorIconsRegular.x));
      await tester.pumpAndSettle();

      expect(controller.text, isEmpty);
      expect(seen.last, isEmpty);
    });
  });

  testWidgets('an external controller seeds the field', (tester) async {
    final controller = TextEditingController(text: 'ids');
    addTearDown(controller.dispose);

    await _pump(tester, controller: controller);
    await tester.pumpAndSettle();

    expect(find.text('ids'), findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(_clearFade()).opacity, 1);
  });
}
