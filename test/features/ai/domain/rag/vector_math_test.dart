import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/rag/vector_math.dart';

/// A tiny named vector, so ranking assertions read clearly.
class _Doc {
  final String name;
  final List<double> embedding;
  const _Doc(this.name, this.embedding);
}

void main() {
  group('cosineSimilarity', () {
    test('identical direction scores 1, opposite -1, orthogonal 0', () {
      expect(cosineSimilarity([1, 0], [1, 0]), closeTo(1.0, 1e-9));
      expect(cosineSimilarity([1, 0], [-1, 0]), closeTo(-1.0, 1e-9));
      expect(cosineSimilarity([1, 0], [0, 1]), closeTo(0.0, 1e-9));
    });

    test('is magnitude-independent — only direction matters', () {
      expect(cosineSimilarity([1, 1], [10, 10]), closeTo(1.0, 1e-9));
    });

    test('is symmetric', () {
      expect(cosineSimilarity([1, 2, 3], [4, 5, 6]),
          closeTo(cosineSimilarity([4, 5, 6], [1, 2, 3]), 1e-12));
    });

    test('undefined comparisons score 0 rather than throwing or NaN', () {
      expect(cosineSimilarity([1, 0], [1, 0, 0]), 0.0, reason: 'length mismatch');
      expect(cosineSimilarity(const [], const []), 0.0, reason: 'empty');
      expect(cosineSimilarity([0, 0], [1, 1]), 0.0, reason: 'zero vector');
    });

    test('stays inside -1..1 despite float drift', () {
      final v = List<double>.filled(768, 0.12345);
      expect(cosineSimilarity(v, v), lessThanOrEqualTo(1.0));
      expect(cosineSimilarity(v, v), closeTo(1.0, 1e-9));
    });
  });

  group('topKSimilar', () {
    const docs = [
      _Doc('exact', [1, 0, 0]),
      _Doc('close', [0.9, 0.1, 0]),
      _Doc('orthogonal', [0, 1, 0]),
      _Doc('opposite', [-1, 0, 0]),
    ];

    List<ScoredItem<_Doc>> run({
      List<double> query = const [1, 0, 0],
      int topK = 5,
      double minScore = 0.0,
    }) =>
        topKSimilar<_Doc>(
          query: query,
          candidates: docs,
          embeddingOf: (d) => d.embedding,
          topK: topK,
          minScore: minScore,
        );

    test('ranks best first and drops non-positive matches', () {
      final hits = run();
      expect([for (final h in hits) h.item.name], ['exact', 'close']);
      expect(hits.first.score, greaterThan(hits.last.score));
    });

    test('respects topK', () {
      expect(run(topK: 1).single.item.name, 'exact');
    });

    test('minScore filters weak matches', () {
      // 'close' scores ~0.9939 against this query, so the cut has to sit above
      // it to isolate the exact match.
      expect([for (final h in run(minScore: 0.995)) h.item.name], ['exact']);
      expect([for (final h in run(minScore: 0.9)) h.item.name],
          ['exact', 'close']);
    });

    test('an empty query or non-positive topK retrieves nothing', () {
      expect(run(query: const []), isEmpty);
      expect(run(topK: 0), isEmpty);
    });

    test('no candidates retrieves nothing', () {
      expect(
        topKSimilar<_Doc>(
          query: const [1, 0, 0],
          candidates: const [],
          embeddingOf: (d) => d.embedding,
        ),
        isEmpty,
      );
    });

    test('a query about something the notes never cover returns nothing', () {
      // Orthogonal to every doc that has positive similarity.
      expect(run(query: const [0, 0, 1]), isEmpty);
    });
  });
}
