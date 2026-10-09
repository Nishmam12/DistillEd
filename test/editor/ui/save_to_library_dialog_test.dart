import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/editor/ui/controls/save_to_library_dialog.dart';

/// Opens the dialog from a button, types [entry] if given, and taps [action].
/// Returns what the dialog gave back.
Future<String?> _answer(WidgetTester tester,
    {String? entry, required String action}) async {
  String? result = 'not answered';
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            result = await showSaveToLibraryDialog(context);
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (entry != null) await tester.enterText(find.byType(TextField), entry);
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('the name is returned trimmed', (tester) async {
    expect(
      await _answer(tester, entry: '  Biology  ', action: 'Save'),
      'Biology',
    );
  });

  testWidgets('a blank name gives back nothing, so nothing is saved',
      (tester) async {
    expect(await _answer(tester, entry: '   ', action: 'Save'), isNull);
  });

  testWidgets('cancelling gives back nothing', (tester) async {
    expect(
      await _answer(tester, entry: 'Biology', action: 'Cancel'),
      isNull,
    );
  });
}
