import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/editor/state/editor_tool_controller.dart';
import 'package:inkflow/core/constants/editor_constants.dart' show kFavoritePickerColors;
import 'package:inkflow/editor/ui/universal_color_palette.dart';

void main() {
  Future<ProviderContainer> pumpPalette(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: UniversalColorPalette(),
            ),
          ),
        ),
      ),
    );
    return container;
  }

  IgnorePointer dropdownIgnorePointer(WidgetTester tester) =>
      tester.widget<IgnorePointer>(
        find.byKey(const ValueKey('universalColorPaletteIgnorePointer')),
      );

  /// Scoped to the dropdown grid, not the trigger's own little colour circle
  /// — the default colour happens to equal one of the swatches, and an
  /// unscoped predicate would match both.
  Finder swatch(int color) => find.descendant(
        of: find.byKey(const ValueKey('universalColorPaletteSurface')),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            (w.decoration as BoxDecoration).color == Color(color)),
      );

  testWidgets('starts closed', (tester) async {
    await pumpPalette(tester);
    expect(dropdownIgnorePointer(tester).ignoring, isTrue);
  });

  testWidgets('tapping the trigger opens the swatch grid', (tester) async {
    await pumpPalette(tester);
    await tester.tap(find.byTooltip('Colour'));
    await tester.pump();

    expect(dropdownIgnorePointer(tester).ignoring, isFalse);
    final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
    expect(slide.offset, Offset.zero);
  });

  testWidgets('tapping the trigger again closes it without picking a colour',
      (tester) async {
    final container = await pumpPalette(tester);
    final before = container.read(editorToolProvider).color;

    await tester.tap(find.byTooltip('Colour'));
    await tester.pump();
    await tester.tap(find.byTooltip('Colour'));
    await tester.pump();

    expect(dropdownIgnorePointer(tester).ignoring, isTrue);
    expect(container.read(editorToolProvider).color, before);
  });

  testWidgets(
      'picking a swatch sets the universal colour (stroke + fill) and closes',
      (tester) async {
    final container = await pumpPalette(tester);
    final before = container.read(editorToolProvider).color;
    final target = kFavoritePickerColors.firstWhere((c) => c != before);

    await tester.tap(find.byTooltip('Colour'));
    // Settle the slide-in animation first — the swatches aren't at their
    // final, tappable position until it finishes.
    await tester.pumpAndSettle();

    await tester.tap(swatch(target));
    await tester.pump();

    expect(container.read(editorToolProvider).color, target);
    expect(container.read(editorToolProvider).fillColor, target);
    expect(dropdownIgnorePointer(tester).ignoring, isTrue);
  });

  testWidgets('offers every colour in the shared favourites list',
      (tester) async {
    await pumpPalette(tester);
    await tester.tap(find.byTooltip('Colour'));
    await tester.pumpAndSettle();

    for (final c in kFavoritePickerColors) {
      expect(swatch(c), findsOneWidget,
          reason: 'missing swatch for 0x${c.toRadixString(16)}');
    }
  });

  testWidgets('the dropdown renders as a squircle card', (tester) async {
    await pumpPalette(tester);
    await tester.tap(find.byTooltip('Colour'));
    await tester.pump();

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('universalColorPaletteSurface')),
    );
    final decoration = surface.decoration as ShapeDecoration;
    expect(decoration.shape, isA<ContinuousRectangleBorder>());
  });
}
