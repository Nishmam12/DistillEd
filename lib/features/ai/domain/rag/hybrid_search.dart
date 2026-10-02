// The model-free half of retrieval: keyword ranking and rank fusion.
//
// Embeddings blur exactly what a student searches for by name — a course code,
// a formula, a defined term — and handwriting recognition blurs it further. A
// keyword pass catches those, needs no model (so it works before the embedding
// model is downloaded), and its misses are the embeddings' hits and vice versa;
// reciprocal rank fusion merges the two without having to make their scores
// comparable.
//
// Pure and storage-free, like the rest of `domain/rag`.

import 'dart:math' as math;

/// Function words that say nothing about what a question is about. English
/// only — Bengali and the like are matched exactly, which is the right default
/// for a name or a term.
const Set<String> _stopwords = {
  'a', 'an', 'the', 'and', 'or', 'but', 'if', 'so', 'of', 'to', 'in', 'on',
  'at', 'by', 'for', 'with', 'from', 'as', 'into', 'about', 'than', 'then',
  'that', 'this', 'these', 'those', 'it', 'its', 'is', 'are', 'was', 'were',
  'be', 'been', 'being', 'am', 'do', 'does', 'did', 'done', 'can', 'could',
  'should', 'would', 'will', 'shall', 'may', 'might', 'must', 'have', 'has',
  'had', 'what', 'which', 'who', 'whom', 'whose', 'how', 'why', 'when',
  'where', 'there', 'their', 'they', 'them', 'you', 'your', 'i', 'me', 'my',
  'we', 'our', 'us', 'he', 'she', 'his', 'her', 'not', 'no', 'any', 'some',
};

/// A run of letters, combining marks and digits in any script. Marks are part
/// of the word: Bengali vowel signs are combining characters, and splitting on
/// them would cut every word into pieces.
final RegExp _word = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);
final RegExp _digit = RegExp(r'^\p{N}$', unicode: true);

/// Lowercased word tokens of [text]. A stray single letter is dropped — the "s"
/// left over from "Bernoulli's" would match half of any notebook — but a lone
/// digit stays, because "type 2 diabetes" means it.
List<String> keywordTokens(String text) {
  final tokens = <String>[];
  for (final match in _word.allMatches(text.toLowerCase())) {
    final token = match.group(0)!;
    if (token.length == 1 && !_digit.hasMatch(token)) continue;
    tokens.add(token);
  }
  return tokens;
}

/// The distinct tokens of a search [query] that carry meaning, in the order they
/// were asked.
List<String> queryTerms(String query) {
  final seen = <String>{};
  return [
    for (final token in keywordTokens(query))
      if (!_stopwords.contains(token) && seen.add(token)) token,
  ];
}

/// BM25's usual saturation and length-normalisation constants.
const double _k1 = 1.2;
const double _b = 0.75;

/// Ranks [passages] against [query] and returns the INDEXES of those that match,
/// best first.
///
/// A passage must contain at least 60% of the query's terms (rounded up). Without
/// that floor a question like "what is the powerhouse of the cell" would pull in
/// every passage that merely mentions "cell"; with it the keyword side stays
/// high-precision, which is the job it has next to the high-recall embeddings.
/// Within the passages that qualify, BM25 weighs a rare term above a common one.
///
/// The statistics are taken over [passages] themselves, so pass the whole
/// searchable set rather than a pre-filtered slice.
List<int> keywordRank(List<String> passages, String query) {
  final terms = queryTerms(query);
  if (terms.isEmpty || passages.isEmpty) return const [];

  final termCounts = <Map<String, int>>[];
  final lengths = <int>[];
  final docFreq = <String, int>{};
  var totalLength = 0;
  for (final passage in passages) {
    final tokens = keywordTokens(passage);
    final counts = <String, int>{};
    for (final token in tokens) {
      counts[token] = (counts[token] ?? 0) + 1;
    }
    termCounts.add(counts);
    lengths.add(tokens.length);
    totalLength += tokens.length;
    for (final term in terms) {
      if (counts.containsKey(term)) docFreq[term] = (docFreq[term] ?? 0) + 1;
    }
  }

  final n = passages.length;
  final averageLength = totalLength == 0 ? 1.0 : totalLength / n;
  // 60% of the terms, rounded up, in integer arithmetic.
  final needed = (terms.length * 3 + 4) ~/ 5;

  final scored = <({int index, double score})>[];
  for (var i = 0; i < n; i++) {
    var matched = 0;
    var score = 0.0;
    for (final term in terms) {
      final frequency = termCounts[i][term];
      if (frequency == null) continue;
      matched++;
      final df = docFreq[term]!;
      final idf = math.log(1 + (n - df + 0.5) / (df + 0.5));
      score += idf *
          (frequency * (_k1 + 1)) /
          (frequency + _k1 * (1 - _b + _b * lengths[i] / averageLength));
    }
    if (matched > 0 && matched >= needed) scored.add((index: i, score: score));
  }

  // Ties go to the earlier passage: Dart's sort is not guaranteed stable, and a
  // result order that shifts between runs is a maddening thing to debug.
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return [for (final s in scored) s.index];
}

/// Reciprocal rank fusion: merges several best-first lists into one.
///
/// Each list contributes `1 / (k + rank)` for every item it holds (rank from 1),
/// so an item that several lists agree on beats one that a single list put
/// first. Only RANKS matter, which is the point — a cosine similarity and a BM25
/// score live on different scales and cannot be added or compared.
///
/// Returns every item in any list, best first, with its fused score. Ties keep
/// first-seen order.
List<({K item, double score})> reciprocalRankFusion<K>(
  List<List<K>> rankings, {
  int k = 60,
}) {
  // A LinkedHashMap, so iteration order is first-seen order.
  final scores = <K, double>{};
  for (final ranking in rankings) {
    for (var rank = 0; rank < ranking.length; rank++) {
      scores.update(
        ranking[rank],
        (score) => score + 1 / (k + rank + 1),
        ifAbsent: () => 1 / (k + rank + 1),
      );
    }
  }

  final entries = [
    for (final entry in scores.entries) (item: entry.key, score: entry.value),
  ];
  final order = [for (var i = 0; i < entries.length; i++) i];
  order.sort((a, b) {
    final byScore = entries[b].score.compareTo(entries[a].score);
    return byScore != 0 ? byScore : a.compareTo(b);
  });
  return [for (final i in order) entries[i]];
}
