// The page menu's option guards. Covers only the sheet body
// ([PageActionsSheet]), which pops an action and touches no persistence.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/editor/ui/controls/page_actions_sheet.dart';

Future<void> _pump(
  WidgetTester tester, {
  required int pageIndex,
  required int pageCount,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PageActionsSheet(pageIndex: pageIndex, pageCount: pageCount),
      ),
    ),
  );
}

bool _enabled(WidgetTester tester, String label) {
  final tile = tester.widget<ListTile>(
    find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
  );
  return tile.enabled;
}

void main() {
  testWidgets('names the page it is acting on', (tester) async {
    await _pump(tester, pageIndex: 2, pageCount: 5);

    expect(find.text('Page 3 of 5'), findsOneWidget);
  });

  testWidgets('offers every action on a middle page', (tester) async {
    await _pump(tester, pageIndex: 1, pageCount: 3);

    expect(_enabled(tester, 'Duplicate'), isTrue);
    expect(_enabled(tester, 'Move left'), isTrue);
    expect(_enabled(tester, 'Move right'), isTrue);
    expect(_enabled(tester, 'Delete'), isTrue);
  });

  testWidgets('cannot move the first page left', (tester) async {
    await _pump(tester, pageIndex: 0, pageCount: 3);

    expect(_enabled(tester, 'Move left'), isFalse);
    expect(_enabled(tester, 'Move right'), isTrue);
  });

  testWidgets('cannot move the last page right', (tester) async {
    await _pump(tester, pageIndex: 2, pageCount: 3);

    expect(_enabled(tester, 'Move left'), isTrue);
    expect(_enabled(tester, 'Move right'), isFalse);
  });

  testWidgets('cannot delete the only page, and says why', (tester) async {
    await _pump(tester, pageIndex: 0, pageCount: 1);

    expect(_enabled(tester, 'Delete'), isFalse);
    expect(find.text('A notebook needs at least one page'), findsOneWidget);
  });

  testWidgets('duplicate stays available on a single-page notebook',
      (tester) async {
    await _pump(tester, pageIndex: 0, pageCount: 1);

    expect(_enabled(tester, 'Duplicate'), isTrue);
  });

  testWidgets('pops the chosen action', (tester) async {
    PageAction? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showModalBottomSheet<PageAction>(
                  context: context,
                  builder: (_) =>
                      const PageActionsSheet(pageIndex: 1, pageCount: 3),
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
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    expect(result, PageAction.duplicate);
  });
}
