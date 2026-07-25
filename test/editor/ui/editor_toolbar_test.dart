import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/data/persistence/scene_element_store.dart';
import 'package:inkflow/editor/state/editor_tool_controller.dart';
import 'package:inkflow/editor/state/favorite_colors_controller.dart';
import 'package:inkflow/editor/state/scene_controller.dart';
import 'package:inkflow/editor/ui/editor_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = (notebookId: 0, pageId: 0);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The bar reads history (undo/redo) → scene controller → element store, so
  // tests supply an in-memory store just like the dev playground does.
  Future<ProviderContainer> pumpBar(
    WidgetTester tester, {
    VoidCallback? onImport,
  }) async {
    final container = ProviderContainer(overrides: [
      sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorBottomBar(pageKey: key, onImport: onImport),
          ),
        ),
      ),
    );
    return container;
  }

  group('tool row', () {
    testWidgets('renders the six primary tools and the import action',
        (tester) async {
      await pumpBar(tester, onImport: () {});

      expect(find.byIcon(Icons.near_me_outlined), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.category), findsOneWidget);
      expect(find.byIcon(Icons.title), findsOneWidget);
      expect(find.byIcon(Icons.layers_clear), findsOneWidget);
      expect(find.byIcon(Icons.flashlight_on_outlined), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('the import button is omitted when no import handler is given',
        (tester) async {
      await pumpBar(tester);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
    });

    testWidgets('tapping a tool makes it the active tool (highlight source)',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      expect(container.read(editorToolProvider).tool, EditorTool.pen);

      await tester.tap(find.byIcon(Icons.near_me_outlined));
      await tester.pump();
      expect(container.read(editorToolProvider).tool, EditorTool.select);

      await tester.tap(find.byIcon(Icons.title));
      await tester.pump();
      expect(container.read(editorToolProvider).tool, EditorTool.text);
    });

    testWidgets('the active tool button is visibly selected', (tester) async {
      await pumpBar(tester, onImport: () {});
      await tester.tap(find.byIcon(Icons.near_me_outlined));
      await tester.pump();

      final selectBtn = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.near_me_outlined),
          matching: find.byType(IconButton),
        ),
      );
      expect(selectBtn.isSelected, isTrue);
    });

    testWidgets('re-tapping the active eraser does not change its mode',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});

      await tester.tap(find.byIcon(Icons.layers_clear));
      await tester.pump();
      expect(container.read(editorToolProvider).tool, EditorTool.eraser);
      expect(container.read(editorToolProvider).eraserPixel, isFalse);

      await tester.tap(find.byIcon(Icons.layers_clear));
      await tester.pump();
      expect(container.read(editorToolProvider).eraserPixel, isFalse);
      expect(find.byIcon(Icons.layers_clear), findsOneWidget);
    });

    testWidgets('the eraser panel switches pixel/stroke mode', (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      await tester.tap(find.byIcon(Icons.layers_clear));
      await tester.pump();
      expect(container.read(editorToolProvider).eraserPixel, isFalse);

      await tester.tap(find.text('Pixel eraser'));
      await tester.pump();
      expect(container.read(editorToolProvider).eraserPixel, isTrue);

      await tester.tap(find.text('Stroke eraser'));
      await tester.pump();
      expect(container.read(editorToolProvider).eraserPixel, isFalse);
    });

    testWidgets('the import handler fires when the import button is tapped',
        (tester) async {
      var imported = 0;
      await pumpBar(tester, onImport: () => imported++);
      await tester.tap(find.byIcon(Icons.image_outlined));
      await tester.pump();
      expect(imported, 1);
    });
  });

  group('favourite colours + undo/redo', () {
    testWidgets('shows three favourite swatches on the default colours',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      expect(
        container.read(favoriteColorsProvider),
        FavoriteColorsController.defaults,
      );
      // Each swatch carries the tap/long-press affordance tooltip.
      expect(
        find.byTooltip('Tap to use · long-press to change'),
        findsNWidgets(FavoriteColorsController.slots),
      );
    });

    testWidgets('tapping a favourite sets it as the active drawing colour',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      // Move off the first default so the tap is a real change.
      container.read(editorToolProvider.notifier).setColor(0xFF000000);

      await tester.tap(
        find.byTooltip('Tap to use · long-press to change').first,
      );
      await tester.pump();

      expect(
        container.read(editorToolProvider).color,
        FavoriteColorsController.defaults.first,
      );
    });

    testWidgets('undo and redo live in the bar and start disabled',
        (tester) async {
      await pumpBar(tester, onImport: () {});

      final undo = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.undo),
          matching: find.byType(IconButton),
        ),
      );
      final redo = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.redo),
          matching: find.byType(IconButton),
        ),
      );
      // Nothing drawn yet, so both are disabled (null onPressed).
      expect(undo.onPressed, isNull);
      expect(redo.onPressed, isNull);
    });
  });

  group('tool options panel', () {
    testWidgets(
        'shows the pen panel (size/roughness/opacity) for the default tool',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      expect(container.read(editorToolProvider).tool, EditorTool.pen);
      expect(find.byType(Slider), findsNWidgets(3));
    });

    testWidgets('shows the eraser panel (size/roughness) for the eraser',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      container.read(editorToolProvider.notifier).setTool(EditorTool.eraser);
      await tester.pump();
      expect(find.byType(Slider), findsNWidgets(2));
    });

    testWidgets('shows the shape panel (size/opacity) for shapes',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      container.read(editorToolProvider.notifier).setTool(EditorTool.shape);
      await tester.pump();
      expect(find.byType(Slider), findsNWidgets(2));
    });

    testWidgets('shows the text panel (font size) for text', (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      container.read(editorToolProvider.notifier).setTool(EditorTool.text);
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('is empty for tools with no options of their own',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      for (final t in [EditorTool.select, EditorTool.laser]) {
        container.read(editorToolProvider.notifier).setTool(t);
        await tester.pump();
        expect(find.byType(Slider), findsNothing, reason: 'no slider for $t');
      }
    });

    testWidgets('dragging the thickness slider changes the stroke size',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      final before = container.read(editorToolProvider).size;
      // Thickness is the first slider in the pen panel.
      await tester.drag(find.byType(Slider).first, const Offset(60, 0));
      await tester.pump();
      expect(container.read(editorToolProvider).size, greaterThan(before));
    });
  });
}
