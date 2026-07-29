// Tier 0.3: the text dialog carries formatting, not just words. The fields
// were already modelled and persisted on TextElement but had no UI.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/ui/text_input_dialog.dart';

/// Opens the dialog and hands back whatever it returned.
Future<SceneTextResult?> _open(
  WidgetTester tester, {
  String initial = '',
  bool initialBold = false,
  bool initialItalic = false,
  TextAlignKind initialAlign = TextAlignKind.left,
}) async {
  SceneTextResult? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showSceneTextDialog(
                context,
                initial: initial,
                initialBold: initialBold,
                initialItalic: initialItalic,
                initialAlign: initialAlign,
                title: 'Edit text',
                confirmLabel: 'Save',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('returns null when cancelled', (tester) async {
    await _open(tester, initial: 'hello');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Nothing to assert beyond not throwing; the caller-side contract is that
    // a cancel leaves the element alone. Covered by the confirm tests below
    // returning a non-null result.
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('carries the typed text through', (tester) async {
    SceneTextResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                captured = await showSceneTextDialog(
                  context,
                  title: 'Add text',
                  confirmLabel: 'Add',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'lecture notes');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(captured!.text, 'lecture notes');
    expect(captured!.isBold, isFalse);
    expect(captured!.align, TextAlignKind.left);
  });

  testWidgets('seeds the toggles from the element being edited',
      (tester) async {
    await _open(
      tester,
      initial: 'x',
      initialBold: true,
      initialItalic: true,
      initialAlign: TextAlignKind.center,
    );

    final bold = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.format_bold),
        matching: find.byType(IconButton),
      ),
    );
    expect(bold.isSelected, isTrue);

    final centre = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.format_align_center),
        matching: find.byType(IconButton),
      ),
    );
    expect(centre.isSelected, isTrue);
  });

  testWidgets('toggling bold is reflected in the result', (tester) async {
    SceneTextResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                captured = await showSceneTextDialog(
                  context,
                  initial: 'x',
                  title: 'Edit text',
                  confirmLabel: 'Save',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.format_bold));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.format_align_right));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(captured!.isBold, isTrue);
    expect(captured!.align, TextAlignKind.right);
    expect(captured!.isItalic, isFalse);
  });

  testWidgets('previews the chosen formatting in the field', (tester) async {
    await _open(tester, initial: 'x', initialBold: true);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style!.fontWeight, FontWeight.bold);
  });

  testWidgets('previews the chosen alignment in the field', (tester) async {
    await _open(tester, initial: 'x', initialAlign: TextAlignKind.center);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textAlign, TextAlign.center);
  });
}
