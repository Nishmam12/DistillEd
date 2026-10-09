import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/widgets/app_chip_group.dart';
import 'package:distill_ed/widgets/app_segmented_control.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

/// A tappable button that says whether it is the selected one. The selected
/// state is stated either way (not left unknown), so both values are asserted.
void _expectButton(SemanticsNode node,
    {required String label, required bool selected}) {
  final data = node.getSemanticsData();
  expect(data.label, label);
  expect(data.hasAction(SemanticsAction.tap), isTrue);
  expect(data.flagsCollection.isButton, isTrue);
  expect(
    data.flagsCollection.isSelected,
    selected ? Tristate.isTrue : Tristate.isFalse,
  );
}

void main() {
  testWidgets('a chip is announced as a button and says whether it is selected',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(AppChipGroup<String>(
      value: 'png',
      options: const [('png', 'PNG'), ('pdf', 'PDF')],
      onChanged: (_) {},
    )));

    _expectButton(tester.getSemantics(find.bySemanticsLabel('PNG')),
        label: 'PNG', selected: true);
    _expectButton(tester.getSemantics(find.bySemanticsLabel('PDF')),
        label: 'PDF', selected: false);
    semantics.dispose();
  });

  testWidgets(
      'a segment is announced as a button and says whether it is selected',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(AppSegmentedControl<String>(
      value: 'light',
      segments: const [
        AppSegment(value: 'light', label: 'Light', icon: Icons.light_mode),
        AppSegment(value: 'dark', label: 'Dark', icon: Icons.dark_mode),
      ],
      onChanged: (_) {},
    )));

    _expectButton(tester.getSemantics(find.bySemanticsLabel('Light')),
        label: 'Light', selected: true);
    _expectButton(tester.getSemantics(find.bySemanticsLabel('Dark')),
        label: 'Dark', selected: false);
    semantics.dispose();
  });
}
