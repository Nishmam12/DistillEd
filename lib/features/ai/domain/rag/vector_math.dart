// Brute-force vector search, in Dart, over Isar-stored embeddings.
//
// The phase spec's option (a), chosen deliberately: Isar has no native vector
// search, but a single learner's notebooks are thousands of chunks, not
// millions. At 768 dimensions a chunk is ~6 KB, so ~2,000 chunks is ~12 MB and
// one query sweep is ~1.5M multiply-adds — cheap enough that adding a second
// storage engine (qdrant / sqlite-vec) would buy nothing but risk. If profiling
// on a real device ever says otherwise, THAT is when to reach for more (and the
// spec wants the numbers reported first).
//
// Pure math, no I/O — fully unit-tested.

import 'dart:math' as math;

/// Cosine similarity of two equal-length vectors, in −1.0..1.0.
///
/// Returns 0.0 for mismatched lengths, empty vectors, or a zero vector — an
/// undefined comparison ranks as "unrelated" rather than throwing or producing
/// NaN, which would poison a sort.
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return 0.0;

  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    dot += x * y;
    normA += x * x;
    normB += y * y;
  }
  if (normA == 0 || normB == 0) return 0.0;

  final similarity = dot / (math.sqrt(normA) * math.sqrt(normB));
  // Guard float drift so callers can trust the stated range.
  return similarity.clamp(-1.0, 1.0);
}

/// A scored candidate from a similarity sweep.
class ScoredItem<T> {
  final T item;
  final double score;
  const ScoredItem(this.item, this.score);
}

/// The [topK] entries of [candidates] most similar to [query], best first.
///
/// [embeddingOf] reads each candidate's vector, so this works for any record
/// shape without the math knowing about storage. Entries scoring below
/// [minScore] are dropped — a notebook that simply doesn't discuss the query
/// should return nothing rather than its least-irrelevant passage.
List<ScoredItem<T>> topKSimilar<T>({
  required List<double> query,
  required Iterable<T> candidates,
  required List<double> Function(T) embeddingOf,
  int topK = 5,
  double minScore = 0.0,
}) {
  if (query.isEmpty || topK <= 0) return const [];

  final scored = <ScoredItem<T>>[];
  for (final candidate in candidates) {
    final score = cosineSimilarity(query, embeddingOf(candidate));
    if (score > minScore) scored.add(ScoredItem(candidate, score));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  return scored.length <= topK ? scored : scored.sublist(0, topK);
}
