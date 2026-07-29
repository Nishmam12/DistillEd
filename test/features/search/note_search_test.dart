// Tier 2.8: find-in-notebook — locating matches well enough to jump to the
// page and highlight the hit.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/data/persistence/page_text_store.dart';
import 'package:inkflow/features/search/domain/note_search.dart';

PageText _page(int pageId, String text) =>
    PageText(pageId: pageId, notebookId: 1, text: text);

/// Pages 10, 11, 12 → notebook positions 0, 1, 2.
const _order = {10: 0, 11: 1, 12: 2};

List<NoteSearchHit> _search(List<PageText> pages, String query,
        {int radius = NoteSearch.defaultSnippetRadius,
        int maxPerPage = NoteSearch.defaultMaxHitsPerPage}) =>
    NoteSearch.search(
      pages: pages,
      pageIndexById: _order,
      query: query,
      snippetRadius: radius,
      maxHitsPerPage: maxPerPage,
    );

void main() {
  group('matching', () {
    test('finds a word and reports its page', () {
      final hits = _search([
        _page(10, 'nothing here'),
        _page(11, 'the krebs cycle produces ATP'),
      ], 'krebs');

      expect(hits, hasLength(1));
      expect(hits.single.pageId, 11);
      expect(hits.single.pageIndex, 1);
      expect(hits.single.pageLabel, 'Page 2');
    });

    test('is case-insensitive', () {
      final hits = _search([_page(10, 'Photosynthesis')], 'PHOTO');

      expect(hits, hasLength(1));
    });

    test('an empty query finds nothing', () {
      expect(_search([_page(10, 'anything')], ''), isEmpty);
      expect(_search([_page(10, 'anything')], '   '), isEmpty);
    });

    test('a word that is not there finds nothing', () {
      expect(_search([_page(10, 'biology')], 'calculus'), isEmpty);
    });

    test('results come back in notebook order', () {
      final hits = _search([
        _page(12, 'atp'),
        _page(10, 'atp'),
        _page(11, 'atp'),
      ], 'atp');

      expect(hits.map((h) => h.pageIndex), [0, 1, 2]);
    });

    test('finds repeated matches on one page', () {
      final hits = _search([_page(10, 'atp and atp and atp')], 'atp');

      expect(hits, hasLength(3));
    });

    test('caps hits per page so one page cannot crowd out the rest', () {
      final hits = _search([
        _page(10, 'atp atp atp atp atp atp'),
        _page(11, 'atp'),
      ], 'atp', maxPerPage: 2);

      expect(hits.where((h) => h.pageId == 10), hasLength(2));
      expect(hits.where((h) => h.pageId == 11), hasLength(1));
    });
  });

  group('snippets', () {
    test('the match offsets point at the matched word', () {
      final hits = _search([_page(10, 'the krebs cycle')], 'krebs');
      final hit = hits.single;

      expect(
        hit.snippet.substring(hit.matchStart, hit.matchStart + hit.matchLength),
        'krebs',
      );
    });

    test('offsets stay correct when the snippet is cut on both sides', () {
      final long = '${'x' * 200} krebs ${'y' * 200}';
      final hit = _search([_page(10, long)], 'krebs', radius: 10).single;

      expect(hit.snippet, startsWith('…'));
      expect(hit.snippet, endsWith('…'));
      expect(
        hit.snippet.substring(hit.matchStart, hit.matchStart + hit.matchLength),
        'krebs',
      );
    });

    test('offsets survive newlines being flattened to spaces', () {
      // A 1:1 substitution, so offsets computed on the original still hold.
      final hit = _search([_page(10, 'line one\nline two\nkrebs here')], 'krebs')
          .single;

      expect(hit.snippet, isNot(contains('\n')));
      expect(
        hit.snippet.substring(hit.matchStart, hit.matchStart + hit.matchLength),
        'krebs',
      );
    });

    test('no leading ellipsis when the match is at the start', () {
      final hit = _search([_page(10, 'krebs cycle')], 'krebs').single;

      expect(hit.snippet, isNot(startsWith('…')));
      expect(hit.matchStart, 0);
    });

    test('preserves the original casing in the snippet', () {
      final hit = _search([_page(10, 'The Krebs Cycle')], 'krebs').single;

      expect(
        hit.snippet.substring(hit.matchStart, hit.matchStart + hit.matchLength),
        'Krebs',
      );
    });
  });

  group('countMatches', () {
    test('counts every occurrence, uncapped', () {
      final total = NoteSearch.countMatches(
        [_page(10, 'atp atp atp atp'), _page(11, 'atp')],
        'atp',
      );

      expect(total, 5);
    });

    test('is zero for an empty query', () {
      expect(NoteSearch.countMatches([_page(10, 'atp')], ''), 0);
    });
  });

  group('unknown pages', () {
    test('a page missing from the ordering reports index -1', () {
      final hits = NoteSearch.search(
        pages: [_page(99, 'krebs')],
        pageIndexById: _order,
        query: 'krebs',
      );

      expect(hits.single.pageIndex, -1);
    });
  });
}
