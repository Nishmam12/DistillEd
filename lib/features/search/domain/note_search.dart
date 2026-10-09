// Find-in-notebook over the same per-page text the home search uses.
//
// Pure and storage-free: callers hand in the notebook's [PageText] rows and get
// back located hits, so this is unit-testable and shares one definition of "what
// counts as a match" with the home list.

import '../../../data/persistence/page_text_store.dart';

/// One match, located well enough to jump to and render.
class NoteSearchHit {
  final int pageId;

  /// 0-based position of the page within the notebook, for "Page N" and for the
  /// jump. -1 when the page is not in the supplied ordering.
  final int pageIndex;

  /// A window of the page's text around the match, with ellipses where it was
  /// cut. Newlines are flattened to spaces so it renders as one line.
  final String snippet;

  /// Where the match sits inside [snippet], for highlighting.
  final int matchStart;
  final int matchLength;

  const NoteSearchHit({
    required this.pageId,
    required this.pageIndex,
    required this.snippet,
    required this.matchStart,
    required this.matchLength,
  });

  /// 1-based label for display.
  String get pageLabel => 'Page ${pageIndex + 1}';
}

class NoteSearch {
  NoteSearch._();

  /// How much context to show either side of a match.
  static const defaultSnippetRadius = 40;

  /// Caps hits per page so one page repeating a common word cannot crowd out
  /// every other page in the results.
  static const defaultMaxHitsPerPage = 3;

  /// Finds [query] across [pages].
  ///
  /// [pageIndexById] maps pageId to its position in the notebook — supplied by
  /// the caller because page order lives with the pages, not the text.
  ///
  /// Matching is a case-insensitive substring, the same rule as the home
  /// search, so a word found there is findable here too.
  static List<NoteSearchHit> search({
    required List<PageText> pages,
    required Map<int, int> pageIndexById,
    required String query,
    int snippetRadius = defaultSnippetRadius,
    int maxHitsPerPage = defaultMaxHitsPerPage,
  }) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];

    final hits = <NoteSearchHit>[];
    for (final page in pages) {
      final folded = _fold(page.text);
      final haystack = folded.text;
      var from = 0;
      var found = 0;
      while (found < maxHitsPerPage) {
        final at = haystack.indexOf(needle, from);
        if (at < 0) break;
        final origin = folded.origin;
        // Offsets in the lowercased text only equal offsets in the page's text
        // when no character changed length ('İ' lowercases to two units).
        final start = origin == null ? at : origin[at];
        final end = origin == null || at + needle.length >= origin.length
            ? (origin == null ? at + needle.length : page.text.length)
            : origin[at + needle.length];
        hits.add(_hitAt(
          page,
          pageIndexById[page.pageId] ?? -1,
          start,
          end - start,
          snippetRadius,
        ));
        from = at + needle.length;
        found++;
      }
    }

    // Notebook order, so results read like the document does.
    hits.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    return hits;
  }

  /// Total matches across the notebook, for a "3 of 12" style counter.
  static int countMatches(List<PageText> pages, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return 0;
    var total = 0;
    for (final page in pages) {
      // The same folding as [search], so the counter and the hits agree.
      final haystack = _fold(page.text).text;
      var from = 0;
      while (true) {
        final at = haystack.indexOf(needle, from);
        if (at < 0) break;
        total++;
        from = at + needle.length;
      }
    }
    return total;
  }

  /// [text] lowercased, with — only when lowercasing changed its length — where
  /// each lowercased code unit came from in [text].
  static ({String text, List<int>? origin}) _fold(String text) {
    final lower = text.toLowerCase();
    if (lower.length == text.length) return (text: lower, origin: null);
    final out = StringBuffer();
    final origin = <int>[];
    var i = 0;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final folded = char.toLowerCase();
      out.write(folded);
      for (var k = 0; k < folded.length; k++) {
        origin.add(i);
      }
      i += char.length;
    }
    return (text: out.toString(), origin: origin);
  }

  static NoteSearchHit _hitAt(
    PageText page,
    int pageIndex,
    int at,
    int length,
    int radius,
  ) {
    final text = page.text;
    final start = (at - radius).clamp(0, text.length);
    final end = (at + length + radius).clamp(0, text.length);
    final prefix = start > 0 ? '…' : '';
    final suffix = end < text.length ? '…' : '';
    // Newline → space is a 1:1 substitution, so match offsets computed against
    // the original text stay valid in the flattened snippet.
    final body = text.substring(start, end).replaceAll('\n', ' ');

    return NoteSearchHit(
      pageId: page.pageId,
      pageIndex: pageIndex,
      snippet: '$prefix$body$suffix',
      matchStart: prefix.length + (at - start),
      matchLength: length,
    );
  }
}
