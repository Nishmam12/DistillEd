import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/core/icons/phosphor_icons_regular.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/commands/scene_command.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/state/editor_tool_controller.dart';
import 'package:margo/editor/state/history_controller.dart';
import 'package:margo/editor/state/pen_presets.dart';
import 'package:margo/editor/state/scene_controller.dart';
import 'package:margo/features/notebook/presentation/controls/editor_bottom_bar.dart';
import 'package:margo/editor/ui/controls/undo_redo_buttons.dart';
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
    final container = ProviderContainer(retry: (_, _) => null, overrides: [
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

      expect(find.byIcon(PhosphorIconsRegular.lasso), findsOneWidget);
      expect(find.byKey(const ValueKey('penTool')), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.shapes), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.textT), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.eraser), findsOneWidget);
      // The laser has its own glyph; the highlighter one is a pen type now.
      expect(find.byIcon(Icons.flare), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.image), findsOneWidget);
    });

    testWidgets('narrowed by the AI panel, the row packs tighter and every tool '
        'stays reachable', (tester) async {
      tester.view.physicalSize = const Size(420, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpBar(tester, onImport: () {});
      await tester.pumpAndSettle();

      final scrollbar = tester.widget<Scrollbar>(
          find.byKey(const ValueKey('toolRowScrollbar')));
      expect(scrollbar.thumbVisibility, isTrue,
          reason: 'a visible sign that the row scrolls');
      // The Text tool is not left half off the edge once scrolled to.
      await tester.scrollUntilVisible(
          find.byIcon(PhosphorIconsRegular.image), 100,
          scrollable: find.descendant(
              of: find.byKey(const ValueKey('toolRowScrollbar')),
              matching: find.byType(Scrollable)));
      expect(find.byIcon(PhosphorIconsRegular.image), findsOneWidget);
    });

    testWidgets('the finger-draw switch flips the setting', (tester) async {
      final container = await pumpBar(tester);
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).fingerDraws, isTrue);
      await tester.tap(find.byKey(const ValueKey('fingerDrawToggle')));
      await tester.pump();
      expect(container.read(settingsProvider).fingerDraws, isFalse);
      await tester.tap(find.byKey(const ValueKey('fingerDrawToggle')));
      await tester.pump();
      expect(container.read(settingsProvider).fingerDraws, isTrue);
    });

    testWidgets('the import button is omitted when no import handler is given',
        (tester) async {
      await pumpBar(tester);
      expect(find.byIcon(PhosphorIconsRegular.image), findsNothing);
    });

    testWidgets('tapping a tool makes it the active tool (highlight source)',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      expect(container.read(editorToolProvider).tool, EditorTool.pen);

      await tester.tap(find.byIcon(PhosphorIconsRegular.lasso));
      await tester.pump();
      expect(container.read(editorToolProvider).tool, EditorTool.select);

      await tester.tap(find.byIcon(PhosphorIconsRegular.textT));
      await tester.pump();
      expect(container.read(editorToolProvider).tool, EditorTool.text);
    });

    testWidgets('the active tool button is visibly selected', (tester) async {
      await pumpBar(tester, onImport: () {});
      await tester.tap(find.byIcon(PhosphorIconsRegular.lasso));
      await tester.pump();

      final selectBtn = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(PhosphorIconsRegular.lasso),
          matching: find.byType(IconButton),
        ),
      );
      expect(selectBtn.isSelected, isTrue);
    });

    testWidgets('re-tapping the active eraser does not change its mode',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});

      await tester.tap(find.byIcon(PhosphorIconsRegular.eraser));
      await tester.pump();
      expect(container.read(editorToolProvider).tool, EditorTool.eraser);
      expect(container.read(editorToolProvider).eraserPixel, isFalse);

      await tester.tap(find.byIcon(PhosphorIconsRegular.eraser));
      await tester.pump();
      expect(container.read(editorToolProvider).eraserPixel, isFalse);
      expect(find.byIcon(PhosphorIconsRegular.eraser), findsOneWidget);
    });

    testWidgets('the import handler fires when the import button is tapped',
        (tester) async {
      var imported = 0;
      await pumpBar(tester, onImport: () => imported++);
      await tester.tap(find.byIcon(PhosphorIconsRegular.image));
      await tester.pump();
      expect(imported, 1);
    });
  });

  group('arrow tool', () {
    testWidgets('tapping the arrow icon selects the arrow shape directly',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      expect(container.read(editorToolProvider).tool, EditorTool.pen);

      await tester.tap(find.byIcon(PhosphorIconsRegular.arrowRight));
      await tester.pump();

      expect(container.read(editorToolProvider).tool, EditorTool.shape);
      expect(container.read(editorToolProvider).shapeType, ShapeType.arrow);
    });

    testWidgets('the arrow button is visibly selected once active',
        (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      await tester.tap(find.byIcon(PhosphorIconsRegular.arrowRight));
      await tester.pump();

      final btn = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(PhosphorIconsRegular.arrowRight),
          matching: find.byType(IconButton),
        ),
      );
      expect(btn.isSelected, isTrue);

      // Switching to an unrelated tool clears the highlight again.
      await tester.tap(find.byIcon(PhosphorIconsRegular.lasso));
      await tester.pump();
      final btnAfter = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(PhosphorIconsRegular.arrowRight),
          matching: find.byType(IconButton),
        ),
      );
      expect(btnAfter.isSelected, isFalse);
      expect(container.read(editorToolProvider).tool, EditorTool.select);
    });

    testWidgets('long-pressing opens the arrowhead style menu', (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      await tester.longPress(find.byIcon(PhosphorIconsRegular.arrowRight));
      await tester.pumpAndSettle();

      expect(find.text('Elbow arrow'), findsOneWidget);

      // Picking the "no arrowhead" style (a plain line) updates the tool state.
      await tester.tap(find.byIcon(Icons.remove).last);
      await tester.pump();
      expect(container.read(editorToolProvider).endArrowhead, Arrowhead.none);

      await tester.tapAt(const Offset(5, 5)); // dismiss the popup
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.remove), findsNothing); // menu closed
    });

    testWidgets('long-press does not change the active tool', (tester) async {
      final container = await pumpBar(tester, onImport: () {});
      await tester.longPress(find.byIcon(PhosphorIconsRegular.arrowRight));
      await tester.pumpAndSettle();
      expect(container.read(editorToolProvider).tool, EditorTool.pen);
    });
  });

  group('undo/redo', () {
    Future<ProviderContainer> pumpHistory(WidgetTester tester) async {
      final container = ProviderContainer(retry: (_, _) => null, overrides: [
        sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: UndoRedoButtons(pageKey: key)),
          ),
        ),
      );
      return container;
    }

    IconButton button(WidgetTester tester, String tooltip) =>
        tester.widget<IconButton>(find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ));

    testWidgets('undo/redo left the tool row for the top bar', (tester) async {
      await pumpBar(tester, onImport: () {});
      expect(find.byTooltip('Undo'), findsNothing);
      expect(find.byTooltip('Redo'), findsNothing);
    });

    testWidgets('start disabled, and undo enables once something is drawn',
        (tester) async {
      final container = await pumpHistory(tester);
      expect(button(tester, 'Undo').onPressed, isNull);
      expect(button(tester, 'Redo').onPressed, isNull);

      container.read(historyProvider(key).notifier).push(AddElementsCommand([
        FreehandElement(id: 'a', zOrder: 0, color: 0, size: 1, points: const []),
      ]));
      await tester.pump();
      expect(button(tester, 'Undo').onPressed, isNotNull);
      expect(button(tester, 'Redo').onPressed, isNull);
    });
  });

  // The tool options panel used to live inline in this bar; it's now a
  // separate floating overlay (see EditorToolOptionsOverlay) so opening it
  // never resizes the bar/canvas. Its own behaviour is covered in
  // editor_tool_options_overlay_test.dart.

  group('saved pens', () {
    testWidgets('tapping one switches to the pen drawing with it',
        (tester) async {
      final container = await pumpBar(tester);
      container.read(editorToolProvider.notifier).setTool(EditorTool.eraser);
      await tester.pump();

      final highlighter = kDefaultPenPresets
          .indexWhere((p) => p.kind == PenKind.highlighter);
      await tester.tap(find.byKey(ValueKey('penPreset-$highlighter')));
      await tester.pump();

      final state = container.read(editorToolProvider);
      expect(state.tool, EditorTool.pen);
      expect(state.penKind, PenKind.highlighter);
      expect(state.color, kDefaultPenPresets[highlighter].color);
    });

    testWidgets('+ saves the pen in use', (tester) async {
      final container = await pumpBar(tester);
      container.read(editorToolProvider.notifier)
        ..setPenKind(PenKind.fountain)
        ..setColor(0xFFE03131);
      await tester.pump();

      await tester.tap(find.byTooltip('Save this pen'));
      await tester.pump();

      expect(container.read(penPresetsProvider).last.color, 0xFFE03131);
      expect(container.read(penPresetsProvider).last.kind, PenKind.fountain);
    });

    testWidgets('the pen button shows the pen being drawn with',
        (tester) async {
      final container = await pumpBar(tester);
      Finder penGlyph(IconData icon) => find.descendant(
          of: find.byKey(const ValueKey('penTool')),
          matching: find.byIcon(icon));

      // Not a fixed pencil any more: that read as the Pencil type.
      expect(penGlyph(Icons.edit_outlined), findsOneWidget);
      expect(penGlyph(PhosphorIconsRegular.pencilSimple), findsNothing);

      container
          .read(editorToolProvider.notifier)
          .setPenKind(PenKind.highlighter);
      await tester.pump();
      expect(penGlyph(PhosphorIconsRegular.highlighter), findsOneWidget);
    });

    testWidgets('sit in their own strip, apart from the tools',
        (tester) async {
      await pumpBar(tester);
      final strip = find.byKey(const ValueKey('penPresets'));
      expect(strip, findsOneWidget);
      for (var i = 0; i < kDefaultPenPresets.length; i++) {
        expect(
            find.descendant(
                of: strip, matching: find.byKey(ValueKey('penPreset-$i'))),
            findsOneWidget);
      }
      // A saved pen is not an IconButton: it must not pass for a tool.
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('penPreset-0')),
              matching: find.byType(IconButton)),
          findsNothing);
    });

    testWidgets('long-press offers Remove', (tester) async {
      final container = await pumpBar(tester);
      final before = container.read(penPresetsProvider).length;

      await tester.longPress(find.byKey(const ValueKey('penPreset-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(container.read(penPresetsProvider).length, before - 1);
    });
  });
}
