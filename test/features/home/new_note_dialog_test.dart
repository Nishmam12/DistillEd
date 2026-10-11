import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/core/theme/paper_colors.dart';
import 'package:distill_ed/domain/model/template_type.dart';
import 'package:distill_ed/features/home/presentation/widgets/new_note_dialog.dart';

Future<void> _open(WidgetTester tester, void Function(NewNoteChoice?) onDone) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => onDone(await showNewNoteDialog(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('offers every template and the three page colours', (
    tester,
  ) async {
    await _open(tester, (_) {});
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Template'), findsOneWidget);
    expect(find.text('Page Style'), findsOneWidget);
    expect(find.text('Page Color'), findsOneWidget);
    for (final type in TemplateType.values) {
      expect(find.bySemanticsLabel(type.displayName), findsOneWidget);
    }
    expect(newNotePaperColors, hasLength(3));
  });

  testWidgets('Create returns the title, template and page colour', (
    tester,
  ) async {
    NewNoteChoice? result;
    await _open(tester, (r) => result = r);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Thermo');
    await tester.tap(find.bySemanticsLabel(TemplateType.grid.displayName));
    await tester.pump();
    // The third swatch is the dark page.
    final swatches = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    );
    await tester.tap(swatches.at(2));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.title, 'Thermo');
    expect(result!.templateIndex, TemplateType.grid.index);
    expect(result!.backgroundColor, PaperColors.paperDark.toARGB32());
  });

  testWidgets('defaults to blank on white, and Cancel returns null', (
    tester,
  ) async {
    NewNoteChoice? result = (title: 'x', templateIndex: 9, backgroundColor: 0);
    await _open(tester, (r) => result = r);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(newNotePaperColors.first, PaperColors.paperWhite);
  });

  testWidgets('Create with defaults is blank on white', (tester) async {
    NewNoteChoice? result;
    await _open(tester, (r) => result = r);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Plain');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result!.templateIndex, TemplateType.blank.index);
    expect(result!.backgroundColor, PaperColors.paperWhite.toARGB32());
  });
}
