import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/widgets/fluid_segmented_control.dart';

void main() {
  testWidgets('FluidSegmentedControl renders options and switches selection', (tester) async {
    String selected = 'one';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FluidSegmentedControl<String>(
              segments: const [
                FluidSegment(value: 'one', label: 'One'),
                FluidSegment(value: 'two', label: 'Two'),
              ],
              selected: selected,
              onChanged: (val) => setState(() => selected = val),
            ),
          ),
        ),
      ),
    );

    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();

    expect(selected, 'two');
  });
}
