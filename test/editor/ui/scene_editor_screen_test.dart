// End-to-end check that the dev playground wires the toolbar, the floating
// tool-options overlay and the canvas together correctly: tapping a tool
// opens its panel, and starting to draw closes it again — the same
// composition the real notebook editor uses (see notebook_editor_screen.dart)
// but bottom-docked here instead of top-docked.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/editor/ui/controls/editor_tool_options_overlay.dart';
import 'package:inkflow/editor/ui/scene_canvas.dart';
import 'package:inkflow/editor/ui/scene_editor_screen.dart';

void main() {
  testWidgets('the options panel starts open, showing the default pen tool',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SceneEditorScreen()));
    await tester.pump();

    expect(find.byType(EditorToolOptionsOverlay), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(2)); // pen: size/opacity
  });

  testWidgets('drawing on the canvas closes the panel without resizing it',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SceneEditorScreen()));
    await tester.pump();

    final canvasSize = tester.getSize(find.byType(SceneCanvas));
    final g = await tester.startGesture(const Offset(100, 100),
        kind: PointerDeviceKind.stylus);
    await g.moveBy(const Offset(20, 20));
    await g.up();
    await tester.pump();

    // The panel is gone (mid slide-away) but the canvas itself never
    // reflows — its size is unaffected by the panel opening or closing.
    expect(tester.getSize(find.byType(SceneCanvas)), canvasSize);
    // Scoped to the tool-options overlay: the universal colour palette also
    // uses an AnimatedSlide for its own dropdown, so an unscoped type lookup
    // would be ambiguous now that both live in this screen at once.
    final slide = tester.widget<AnimatedSlide>(find.descendant(
      of: find.byType(EditorToolOptionsOverlay),
      matching: find.byType(AnimatedSlide),
    ));
    expect(slide.offset, isNot(Offset.zero));
  });

  testWidgets('re-tapping the eraser tool reopens its panel', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SceneEditorScreen()));
    await tester.pump();

    // Pick the eraser (a different tool → opens its panel). Its button shows
    // the stroke-eraser icon by default (see _ToolIconButton).
    await tester.tap(find.byIcon(Icons.layers_clear));
    await tester.pump();
    expect(find.byType(Slider), findsOneWidget); // eraser: size only

    // Draw with it — the panel auto-closes.
    final g = await tester.startGesture(const Offset(120, 140),
        kind: PointerDeviceKind.stylus);
    await g.up();
    await tester.pumpAndSettle();
    final ignoreAfterDraw = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey('editorToolOptionsIgnorePointer')),
    );
    expect(ignoreAfterDraw.ignoring, isTrue);

    // Tapping the still-active eraser tool again brings the panel back.
    await tester.tap(find.byIcon(Icons.layers_clear));
    await tester.pump();
    final ignoreAfterRetap = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey('editorToolOptionsIgnorePointer')),
    );
    expect(ignoreAfterRetap.ignoring, isFalse);
  });
}
