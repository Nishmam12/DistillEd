import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/editor/state/viewport_controller.dart';
import 'package:inkflow/editor/ui/zoom_pill.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: ZoomPill())),
        ),
      ),
    );
    return container;
  }

  testWidgets('shows 100% at the default zoom', (tester) async {
    await pump(tester);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('reflects the current zoom level', (tester) async {
    final container = await pump(tester);
    container.read(viewportProvider.notifier).zoomAtPoint(2.0, Offset.zero);
    await tester.pump();
    expect(find.text('200%'), findsOneWidget);
  });

  testWidgets('tapping resets the view to 100%', (tester) async {
    final container = await pump(tester);
    container.read(viewportProvider.notifier).zoomAtPoint(2.5, Offset.zero);
    await tester.pump();
    expect(find.text('250%'), findsOneWidget);

    await tester.tap(find.byType(ZoomPill));
    await tester.pump();

    expect(find.text('100%'), findsOneWidget);
    expect(container.read(viewportProvider).zoom, 1.0);
  });
}
