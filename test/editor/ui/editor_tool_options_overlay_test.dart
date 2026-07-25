import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/state/editor_tool_controller.dart';
import 'package:inkflow/core/constants/editor_constants.dart';
import 'package:inkflow/editor/ui/controls/editor_tool_options_overlay.dart';

void main() {
  Future<ProviderContainer> pumpOverlay(
    WidgetTester tester, {
    bool anchorBottom = false,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
              body: EditorToolOptionsOverlay(anchorBottom: anchorBottom)),
        ),
      ),
    );
    return container;
  }

  group('panel content per tool', () {
    testWidgets('shows the pen panel (size/opacity) for the default tool',
        (tester) async {
      final container = await pumpOverlay(tester);
      expect(container.read(editorToolProvider).tool, EditorTool.pen);
      expect(container.read(editorToolProvider).panelOpen, isTrue);
      expect(find.byType(Slider), findsNWidgets(2));
    });

    testWidgets(
        'the pen panel has no stroke/edge/fill styling — those are shape '
        'concepts now', (tester) async {
      await pumpOverlay(tester);
      expect(find.text('Dashed'), findsNothing);
      expect(find.text('Round'), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('shows the eraser panel (size only) for the eraser',
        (tester) async {
      final container = await pumpOverlay(tester);
      container.read(editorToolProvider.notifier).setTool(EditorTool.eraser);
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('shows the shape panel (size/opacity) for shapes',
        (tester) async {
      final container = await pumpOverlay(tester);
      container.read(editorToolProvider.notifier).setTool(EditorTool.shape);
      await tester.pump();
      expect(find.byType(Slider), findsNWidgets(2));
    });

    testWidgets(
        'the shape-type picker has no line/arrow chips — those are the '
        'dedicated arrow tool now', (tester) async {
      final container = await pumpOverlay(tester);
      container.read(editorToolProvider.notifier).setTool(EditorTool.shape);
      await tester.pump();

      expect(kEditorShapes.map((e) => e.$1), isNot(contains(ShapeType.line)));
      expect(
          kEditorShapes.map((e) => e.$1), isNot(contains(ShapeType.arrow)));
      expect(find.byIcon(Icons.remove), findsNothing); // the old line chip
      expect(find.byIcon(Icons.arrow_right_alt), findsNothing);
    });

    testWidgets('the shape panel now carries stroke style, edges and fill',
        (tester) async {
      final container = await pumpOverlay(tester);
      container.read(editorToolProvider.notifier).setTool(EditorTool.shape);
      await tester.pump();

      expect(find.text('Dashed'), findsOneWidget);
      expect(find.text('Dotted'), findsOneWidget);
      expect(find.text('Sharp'), findsOneWidget);
      expect(find.text('Round'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget); // fill toggle

      await tester.tap(find.text('Dashed'));
      await tester.pump();
      expect(container.read(editorToolProvider).strokeStyle, StrokeStyle.dashed);

      await tester.tap(find.text('Round'));
      await tester.pump();
      expect(container.read(editorToolProvider).edges, EdgeStyle.round);
    });

    testWidgets('shows the text panel (font size) for text', (tester) async {
      final container = await pumpOverlay(tester);
      container.read(editorToolProvider.notifier).setTool(EditorTool.text);
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('renders nothing for tools with no options of their own',
        (tester) async {
      final container = await pumpOverlay(tester);
      for (final t in [EditorTool.select, EditorTool.laser]) {
        container.read(editorToolProvider.notifier).setTool(t);
        await tester.pump();
        expect(find.byType(Slider), findsNothing, reason: 'no slider for $t');
        expect(find.byType(EditorToolOptionsOverlay), findsOneWidget);
      }
    });

    testWidgets('the eraser panel switches pixel/stroke mode', (tester) async {
      final container = await pumpOverlay(tester);
      container.read(editorToolProvider.notifier).setTool(EditorTool.eraser);
      await tester.pump();
      expect(container.read(editorToolProvider).eraserPixel, isFalse);

      await tester.tap(find.text('Pixel eraser'));
      await tester.pump();
      expect(container.read(editorToolProvider).eraserPixel, isTrue);

      await tester.tap(find.text('Stroke eraser'));
      await tester.pump();
      expect(container.read(editorToolProvider).eraserPixel, isFalse);
    });

    testWidgets('dragging the thickness slider changes the stroke size',
        (tester) async {
      final container = await pumpOverlay(tester);
      final before = container.read(editorToolProvider).size;
      // Thickness is the first slider in the pen panel.
      await tester.drag(find.byType(Slider).first, const Offset(60, 0));
      await tester.pump();
      expect(container.read(editorToolProvider).size, greaterThan(before));
    });

    testWidgets('turning on shape fill does not overflow the panel',
        (tester) async {
      final container = await pumpOverlay(tester);
      container.read(editorToolProvider.notifier).setTool(EditorTool.shape);
      await tester.pump();
      expect(container.read(editorToolProvider).hasFill, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(container.read(editorToolProvider).hasFill, isTrue);
      expect(tester.takeException(), isNull);
      // "Hachure"/"Cross" are unique to the fill-style segments — "Solid" is
      // ambiguous with the stroke-style row, which also has a "Solid" segment.
      expect(find.text('Hachure'), findsOneWidget);
      expect(find.text('Cross'), findsOneWidget);
    });
  });

  group('temporary visibility (slide in / out)', () {
    testWidgets('is visible (opacity 1, no slide offset) while panelOpen',
        (tester) async {
      final container = await pumpOverlay(tester);
      expect(container.read(editorToolProvider).panelOpen, isTrue);

      final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity));
      expect(opacity.opacity, 1.0);
      final slide =
          tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.offset, Offset.zero);
    });

    testWidgets('slides up and fades out when the panel closes',
        (tester) async {
      final container = await pumpOverlay(tester);
      container.read(editorToolProvider.notifier).closePanel();
      await tester.pump();

      final slide =
          tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.offset.dy, lessThan(0));

      await tester.pumpAndSettle();
      final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity));
      expect(opacity.opacity, 0.0);
    });

    testWidgets('a closed panel ignores taps (does not steal the canvas)',
        (tester) async {
      final container = await pumpOverlay(tester);
      container.read(editorToolProvider.notifier).closePanel();
      await tester.pump();

      final ignore = tester.widget<IgnorePointer>(
        find.byKey(const ValueKey('editorToolOptionsIgnorePointer')),
      );
      expect(ignore.ignoring, isTrue);
    });

    testWidgets('re-opens (slides back down) when the panel reopens',
        (tester) async {
      final container = await pumpOverlay(tester);
      final ctl = container.read(editorToolProvider.notifier);
      ctl.closePanel();
      await tester.pumpAndSettle();

      ctl.setTool(EditorTool.pen); // same tool → toggles panel back open
      await tester.pump();

      final slide =
          tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.offset, Offset.zero);
      final ignore = tester.widget<IgnorePointer>(
        find.byKey(const ValueKey('editorToolOptionsIgnorePointer')),
      );
      expect(ignore.ignoring, isFalse);
    });

    testWidgets('slides down (not up) to hide when anchored to the bottom',
        (tester) async {
      final container = await pumpOverlay(tester, anchorBottom: true);
      container.read(editorToolProvider.notifier).closePanel();
      await tester.pump();

      final slide =
          tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.offset.dy, greaterThan(0));
    });
  });

  group('shape', () {
    testWidgets('renders as a ContinuousRectangleBorder ("squircle") card',
        (tester) async {
      await pumpOverlay(tester);
      final surface = tester.widget<Container>(
        find.byKey(const ValueKey('editorToolOptionsPanelSurface')),
      );
      final decoration = surface.decoration as ShapeDecoration;
      expect(decoration.shape, isA<ContinuousRectangleBorder>());
    });
  });
}
