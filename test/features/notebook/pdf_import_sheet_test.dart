import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/notebook/presentation/notebook_editor_screen.dart';

void main() {
  /// Opens the sheet from a button and returns what it pops.
  Future<PdfImportOptions?> open(
    WidgetTester tester, {
    required int pageCount,
    Future<void> Function()? interact,
  }) async {
    PdfImportOptions? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<PdfImportOptions>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    PdfImportSheet(fileName: 'lecture.pdf', pageCount: pageCount),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await interact?.call();
    await tester.tap(find.byKey(const ValueKey('pdfImportConfirm')));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('by default every page goes after the current page',
      (tester) async {
    final options = await open(tester, pageCount: 12);
    expect(options,
        (first: 1, last: 12, afterCurrent: true, readText: true));
    expect(find.text('Import 12 pages'), findsNothing,
        reason: 'the sheet has closed');
  });

  testWidgets('"Read the text now" can be switched off: pages as they are',
      (tester) async {
    final options = await open(tester, pageCount: 3, interact: () async {
      await tester.tap(find.byKey(const ValueKey('pdfReadText')));
      await tester.pumpAndSettle();
      expect(find.textContaining('imported as they are'), findsOneWidget);
    });
    expect(options?.readText, isFalse);
  });

  group('too many photos for one page', () {
    Future<PhotoLimitChoice?> ask(WidgetTester tester, Key? tap) async {
      PhotoLimitChoice? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<PhotoLimitChoice>(
                  context: context,
                  builder: (_) => const PhotoLimitDialog(
                      adding: 10, onPage: 2, limit: 4),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('12 pictures on one page'), findsOneWidget);
      expect(find.textContaining('up to 4 pictures'), findsOneWidget);
      await tester.tap(tap == null ? find.text('Cancel') : find.byKey(tap));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('a page each', (tester) async {
      expect(await ask(tester, const ValueKey('photoLimitOwnPages')),
          PhotoLimitChoice.ownPages);
    });

    testWidgets('add to this page anyway', (tester) async {
      expect(await ask(tester, const ValueKey('photoLimitThisPage')),
          PhotoLimitChoice.thisPage);
    });

    testWidgets('cancel adds nothing', (tester) async {
      expect(await ask(tester, null), isNull);
    });
  });

  testWidgets('choosing "At the end" is passed back', (tester) async {
    final options = await open(tester, pageCount: 3, interact: () async {
      await tester.tap(find.text('At the end'));
      await tester.pumpAndSettle();
    });
    expect(options?.afterCurrent, isFalse);
  });

  testWidgets('a one-page PDF has no range slider', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PdfImportSheet(fileName: 'a.pdf', pageCount: 1)),
    ));
    expect(find.byType(RangeSlider), findsNothing);
    expect(find.text('Import 1 page'), findsOneWidget);
  });

  testWidgets('dragging the range narrows the import', (tester) async {
    final options = await open(tester, pageCount: 10, interact: () async {
      final slider = tester.getRect(find.byType(RangeSlider));
      // Drag the start thumb roughly a third of the way in.
      await tester.dragFrom(
          Offset(slider.left + 24, slider.center.dy), Offset(slider.width / 3, 0));
      await tester.pumpAndSettle();
    });
    expect(options!.first, greaterThan(1));
    expect(options.last, 10);
  });
}
