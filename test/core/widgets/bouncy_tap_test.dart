import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/widgets/bouncy_tap.dart';

void main() {
  testWidgets('BouncyTap triggers onTap on tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BouncyTap(
            onTap: () => tapped = true,
            child: const Text('Tap Me'),
          ),
        ),
      ),
    );

    expect(find.text('Tap Me'), findsOneWidget);
    await tester.tap(find.text('Tap Me'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('BouncyTap scales down on press', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BouncyTap(
            scaleDown: 0.9,
            onTap: () {},
            child: const Text('Bounce'),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text('Bounce')));
    await tester.pump(const Duration(milliseconds: 50));

    final scaleFinder = find.byType(AnimatedScale);
    expect(scaleFinder, findsOneWidget);
    final animatedScale = tester.widget<AnimatedScale>(scaleFinder);
    expect(animatedScale.scale, 0.9);

    await gesture.up();
    await tester.pumpAndSettle();

    final releasedScale = tester.widget<AnimatedScale>(scaleFinder);
    expect(releasedScale.scale, 1.0);
  });
}
