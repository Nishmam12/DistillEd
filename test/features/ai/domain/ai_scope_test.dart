import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_scope.dart';

/// A notebook holding a hand-written page, a 3-page PDF, and a page from a
/// SECOND import — the layout that makes "the whole PDF" a distinct scope from
/// both "this page" and "the whole notebook".
const _pages = [
  ScopePage(pageId: 1),
  ScopePage(
      pageId: 2, importGroupId: 'import-a', importSourceName: 'lecture.pdf'),
  ScopePage(
      pageId: 3, importGroupId: 'import-a', importSourceName: 'lecture.pdf'),
  ScopePage(
      pageId: 4, importGroupId: 'import-a', importSourceName: 'lecture.pdf'),
  ScopePage(
      pageId: 5, importGroupId: 'import-b', importSourceName: 'tutorial.pdf'),
];

AiScopeResolver _resolver([List<ScopePage> pages = _pages]) =>
    AiScopeResolver(pagesOf: (_) async => pages);

void main() {
  group('page scope', () {
    test('covers exactly the one page, never its neighbours', () async {
      final scope = await _resolver()
          .resolve(kind: AiScopeKind.page, notebookId: 1, pageId: 3);

      expect(scope.pageIds, [3]);
      expect(scope.spansMultiplePages, isFalse);
      expect(scope.label, 'this page');
    });

    test('a page in the middle of a PDF still means only that page', () async {
      final scope = await _resolver()
          .resolve(kind: AiScopeKind.page, notebookId: 1, pageId: 2);
      expect(scope.pageIds, [2]);
    });
  });

  group('import-group scope', () {
    test('covers every page of the same import, in page order', () async {
      final scope = await _resolver()
          .resolve(kind: AiScopeKind.importGroup, notebookId: 1, pageId: 3);

      expect(scope.pageIds, [2, 3, 4]);
      expect(scope.importGroupId, 'import-a');
      expect(scope.spansMultiplePages, isTrue);
    });

    test('does not leak pages from a different import', () async {
      final scope = await _resolver()
          .resolve(kind: AiScopeKind.importGroup, notebookId: 1, pageId: 5);

      expect(scope.pageIds, [5]);
      expect(scope.importGroupId, 'import-b');
    });

    test('labels itself with the source file and page count', () async {
      final scope = await _resolver()
          .resolve(kind: AiScopeKind.importGroup, notebookId: 1, pageId: 2);
      expect(scope.label, 'lecture.pdf (3 pages)');
    });

    test('on a hand-made page it narrows to that page rather than widening',
        () async {
      // The alternative — falling through to the notebook — would read pages
      // the student never asked about, which is the failure this scope exists
      // to prevent.
      final scope = await _resolver()
          .resolve(kind: AiScopeKind.importGroup, notebookId: 1, pageId: 1);

      expect(scope.kind, AiScopeKind.page);
      expect(scope.pageIds, [1]);
    });
  });

  test('notebook scope covers every page', () async {
    final scope = await _resolver()
        .resolve(kind: AiScopeKind.notebook, notebookId: 1, pageId: 3);

    expect(scope.pageIds, [1, 2, 3, 4, 5]);
    expect(scope.label, 'the whole notebook');
  });

  test('selection scope carries the element ids and stays on one page',
      () async {
    final scope = await _resolver().resolve(
      kind: AiScopeKind.selection,
      notebookId: 1,
      pageId: 3,
      elementIds: {'e1', 'e2'},
    );

    expect(scope.pageIds, [3]);
    expect(scope.elementIds, {'e1', 'e2'});
    expect(scope.label, 'the selection');
  });

  group('importGroupOf', () {
    test('reports the group for an imported page', () async {
      final page =
          await _resolver().importGroupOf(notebookId: 1, pageId: 4);
      expect(page?.importGroupId, 'import-a');
      expect(page?.importSourceName, 'lecture.pdf');
    });

    test('is null for a hand-made page, so the menu can hide the option',
        () async {
      expect(await _resolver().importGroupOf(notebookId: 1, pageId: 1), isNull);
    });

    test('is null for a page id that is not in the notebook', () async {
      expect(await _resolver().importGroupOf(notebookId: 1, pageId: 99), isNull);
    });
  });

  test('an empty notebook resolves to no pages rather than throwing', () async {
    final scope = await _resolver(const [])
        .resolve(kind: AiScopeKind.notebook, notebookId: 1, pageId: 1);
    expect(scope.pageIds, isEmpty);
  });
}
