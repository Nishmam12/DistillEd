import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/editor/ui/editable_note_title.dart';

void main() {
  Widget host(String title, ValueChanged<String>? onRename) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: EditableNoteTitle(title: title, onRename: onRename),
          ),
        ),
      );

  testWidgets('shows the title as plain text with no edit affordance when '
      'onRename is null', (tester) async {
    await tester.pumpWidget(host('My note', null));
    expect(find.text('My note'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    // Tapping does nothing (no text field appears) while not renameable.
    await tester.tap(find.text('My note'));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('tapping enters edit mode and submitting renames', (tester) async {
    String? renamed;
    await tester.pumpWidget(host('Old name', (v) => renamed = v));

    await tester.tap(find.text('Old name'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'New name');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(renamed, 'New name');
  });

  testWidgets('a blank name is rejected and does not rename', (tester) async {
    String? renamed;
    await tester.pumpWidget(host('Keep me', (v) => renamed = v));

    await tester.tap(find.text('Keep me'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(renamed, isNull);
    expect(find.text('Keep me'), findsOneWidget);
  });

  testWidgets('an unchanged name does not fire the rename callback',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(host('Same', (_) => calls++));

    await tester.tap(find.text('Same'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Same');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(calls, 0);
  });

  testWidgets('the rename callback fires at most once per commit',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(host('Start', (_) => calls++));

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Done');
    // Submitting commits; the trailing tap-outside must not commit again.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(calls, 1);
  });
}
