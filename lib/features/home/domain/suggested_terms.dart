// Suggested titles and tags (Samsung Notes' title and tag mining): the
// notebook's key concepts the AI panel already found, then the words and
// two-word phrases its pages use most. Pure, on the device, and only
// suggestions: nothing is saved until the student picks one.

import '../../ai/domain/rag/hybrid_search.dart' show kStopwords;

final RegExp _word = RegExp(r'[\p{L}\p{M}]+', unicode: true);

/// The notebook's terms, best first, at most [max]: [concepts] as given, then
/// phrases said at least twice (a two-word phrase beats either word alone),
/// then single words said at least twice. Case-insensitive, each once.
List<String> rankTerms({
  required List<String> pageTexts,
  List<String> concepts = const [],
  int max = 10,
}) {
  final unigrams = <String, int>{};
  final bigrams = <String, int>{};
  final firstSeen = <String, int>{};
  var at = 0;
  for (final text in pageTexts) {
    for (final line in text.split('\n')) {
      String? prev;
      for (final m in _word.allMatches(line.toLowerCase())) {
        final w = m.group(0)!;
        if (w.length < 3 || kStopwords.contains(w)) {
          prev = null;
          continue;
        }
        unigrams[w] = (unigrams[w] ?? 0) + 1;
        firstSeen.putIfAbsent(w, () => at++);
        if (prev != null) {
          final b = '$prev $w';
          bigrams[b] = (bigrams[b] ?? 0) + 1;
          firstSeen.putIfAbsent(b, () => at++);
        }
        prev = w;
      }
    }
  }

  List<String> ranked(Map<String, int> counts) => [
        for (final e in counts.entries)
          if (e.value >= 2) e.key,
      ]..sort((a, b) {
          final c = counts[b]!.compareTo(counts[a]!);
          return c != 0 ? c : firstSeen[a]!.compareTo(firstSeen[b]!);
        });

  final out = <String>[];
  final seen = <String>{};
  void add(String t) {
    final key = t.trim().toLowerCase();
    if (key.isEmpty || out.length >= max || !seen.add(key)) return;
    out.add(t.trim());
  }

  concepts.forEach(add);
  final phrases = ranked(bigrams);
  phrases.forEach(add);
  // A word already inside a suggested phrase adds nothing.
  for (final w in ranked(unigrams)) {
    if (!out.any((t) => t.toLowerCase().split(' ').contains(w))) add(w);
  }
  return out;
}

/// [term] as a title: each word capitalised ("cell division" -> "Cell
/// Division"); a concept already written with capitals is kept as it is.
String asTitle(String term) => term == term.toLowerCase()
    ? term
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ')
    : term;
