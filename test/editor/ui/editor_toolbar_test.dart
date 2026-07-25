import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/data/persistence/scene_element_store.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/state/editor_tool_controller.dart';
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

    testWidgets('the import handler fires when the import button is tapped',
        (tester) async {
      var imported = 0;
      await pumpBar(tester, onImport: () => imported++);
      await tester.tap(find.byIcon(Icons.image_outlined));
      await tester.pump();
      expect(imported, 1);
    });
  });

  group('arrow tool', () {
    testWidgets('tapping the arrow icon selects the arrow shape directly',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      expect(container.read(editorToolProvider).tool, EditorTool.pen);

      await tester.tap(find.byIcon(Icons.arrow_right_alt));
      await tester.pump();

      expect(container.read(editorToolProvider).tool, EditorTool.shape);
      expect(container.read(editorToolProvider).shapeType, ShapeType.arrow);
    });

    testWidgets('the arrow button is visibly selected once active',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      await tester.tap(find.byIcon(Icons.arrow_right_alt));
      await tester.pump();

      final btn = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_right_alt),
          matching: find.byType(IconButton),
        ),
      );
      expect(btn.isSelected, isTrue);

      // Switching to an unrelated tool clears the highlight again.
      await tester.tap(find.byIcon(Icons.near_me_outlined));
      await tester.pump();
      final btnAfter = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_right_alt),
          matching: find.byType(IconButton),
        ),
      );
      expect(btnAfter.isSelected, isFalse);
      expect(container.read(editorToolProvider).tool, EditorTool.select);
    });

    testWidgets('long-pressing opens the arrowhead style menu', (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      await tester.longPress(find.byIcon(Icons.arrow_right_alt));
      await tester.pumpAndSettle();

      expect(find.text('Elbow arrow'), findsOneWidget);

      // Picking the "no arrowhead" style (a plain line) updates the tool
      // state and is reflected by the button's own icon afterwards.
      await tester.tap(find.byIcon(Icons.remove).last);
      await tester.pump();
      expect(container.read(editorToolProvider).endArrowhead, Arrowhead.none);

      await tester.tapAt(const Offset(5, 5)); // dismiss the popup
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.remove), findsOneWidget); // now the tool icon
    });

    testWidgets('long-press does not change the active tool', (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      await tester.longPress(find.byIcon(Icons.arrow_right_alt));
      await tester.pumpAndSettle();
      expect(container.read(editorToolProvider).tool, EditorTool.pen);
    });
  });

  group('undo/redo', () {
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

  // The tool options panel used to live inline in this bar; it's now a
  // separate floating overlay (see EditorToolOptionsOverlay) so opening it
  // never resizes the bar/canvas. Its own behaviour is covered in
  // editor_tool_options_overlay_test.dart.
}
