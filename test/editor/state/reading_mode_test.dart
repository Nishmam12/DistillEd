import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/editor/state/editor_tool_controller.dart';

void main() {
  testWidgets('reading mode switches to the hand tool and puts the pen back',
      (tester) async {
    late WidgetRef captured;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(builder: (context, ref, _) {
        captured = ref;
        return const SizedBox();
      }),
    ));
    container.read(editorToolProvider.notifier).useTool(EditorTool.pen);

    toggleReadingMode(captured);
    expect(container.read(editorToolProvider).tool, EditorTool.hand);
    expect(container.read(readingModeProvider), EditorTool.pen);

    toggleReadingMode(captured);
    expect(container.read(editorToolProvider).tool, EditorTool.pen);
    expect(container.read(readingModeProvider), isNull);
  });
}
