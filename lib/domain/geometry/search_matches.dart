// Which words of a page picture a search found, so they can be tinted when the
// page is opened from Find.
//
// Agrees with Find itself (`NoteSearch`): a case-insensitive substring, with
// runs of whitespace counting as one space, so a phrase that wraps onto the
// next line still matches. A match inside a word tints the whole word, and a
// match across words tints each of them.

import '../model/page_words.dart';

/// The words of [words] that overlap a match of [query], and how many matches
/// there are. Empty for a blank query.
({Set<int> indexes, int matches}) matchWords(PageWords words, String query) {
  final needle = query.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  if (needle.isEmpty || words.words.isEmpty) {
    return (indexes: const <int>{}, matches: 0);
  }

  // The words joined by single spaces, and where each one starts and ends.
  final text = StringBuffer();
  final starts = <int>[];
  final ends = <int>[];
  for (var i = 0; i < words.words.length; i++) {
    if (i > 0) text.write(' ');
    starts.add(text.length);
    text.write(words.words[i].text.replaceAll(RegExp(r'\s+'), ' '));
    ends.add(text.length);
  }
  final hay = text.toString().toLowerCase();
  if (hay.length != text.length) {
    // Lower-casing changed the length (rare letters): no safe way to map a
    // match back to its words.
    return (indexes: const <int>{}, matches: 0);
  }

  final indexes = <int>{};
  var matches = 0;
  var from = 0;
  while (true) {
    final at = hay.indexOf(needle, from);
    if (at < 0) break;
    matches++;
    final end = at + needle.length;
    for (var i = 0; i < starts.length; i++) {
      if (starts[i] < end && ends[i] > at) indexes.add(i);
    }
    from = end;
  }
  return (indexes: indexes, matches: matches);
}
