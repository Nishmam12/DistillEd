import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/rag/note_chunk.dart';
import 'package:inkflow/features/ai/domain/rag/rag_retriever.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

/// Maps canned text → canned vectors, and counts calls so tests can prove the
/// retriever avoided a ~175 MB model load.
class _FakeEmbedder implements TextEmbedder {
  _FakeEmbedder({this.modelId = 'fake-v1', Map<String, List<double>>? vectors})
      : _vectors = vectors ?? const {};

  final Map<String, List<double>> _vectors;

  @override
  final String modelId;

  @override
  final int dimensions = 3;

  final queries = <({String text, EmbedTaskType taskType})>[];

  @override
  Future<List<double>> embedOne(
    String text, {
    required EmbedTaskType taskType,
  }) async {
    queries.add((text: text, taskType: taskType));
    return _vectors[text] ?? const [1.0, 0.0, 0.0];
  }

  @override
  Future<List<List<double>>> embedAll(
    List<String> texts, {
    required EmbedTaskType taskType,
  }) async =>
      [for (final t in texts) await embedOne(t, taskType: taskType)];
}

NoteChunk chunk(
  String text,
  List<double> embedding, {
  String modelId = 'fake-v1',
  int ordinal = 0,
}) =>
    NoteChunk(
      notebookId: 1,
      pageId: 7,
      ordinal: ordinal,
      text: text,
      embedding: embedding,
      embeddingModelId: modelId,
      contentSignature: 'sig',
      embeddedAt: DateTime(2026, 7, 17),
    );

void main() {
  RagRetriever build(_FakeEmbedder embedder, List<NoteChunk> chunks) =>
      RagRetriever(embedder: embedder, loadChunks: (_) async => chunks);

  test('returns the closest chunks, best first', () async {
    final embedder = _FakeEmbedder();
    final retriever = build(embedder, [
      // Weakly related rather than orthogonal: topKSimilar drops non-positive
      // scores outright, so a 0.0 chunk would test that rule, not the ordering.
      chunk('far', [0.1, 1.0, 0.0]),
      chunk('exact', [1.0, 0.0, 0.0], ordinal: 1),
      chunk('near', [0.9, 0.1, 0.0], ordinal: 2),
    ]);

    final hits =
        await retriever.search(query: 'anything', notebookId: 1, minScore: 0.0);

    expect([for (final h in hits) h.chunk.text], ['exact', 'near', 'far']);
    expect(hits.first.score, closeTo(1.0, 1e-9));
  });

  test('the query is embedded with QUERY semantics, not document', () async {
    final embedder = _FakeEmbedder();
    await build(embedder, [chunk('a', [1.0, 0.0, 0.0])])
        .search(query: 'what is a cell?', notebookId: 1);

    expect(embedder.queries.single.taskType, EmbedTaskType.query);
    expect(embedder.queries.single.text, 'what is a cell?');
  });

  test('chunks embedded by a DIFFERENT model are never ranked', () async {
    final embedder = _FakeEmbedder(modelId: 'fake-v2');
    final retriever = build(embedder, [
      chunk('stale', [1.0, 0.0, 0.0], modelId: 'fake-v1'),
      chunk('current', [0.9, 0.1, 0.0], modelId: 'fake-v2', ordinal: 1),
    ]);

    final hits =
        await retriever.search(query: 'q', notebookId: 1, minScore: 0.0);

    // Cosine across two models' spaces returns a confident-looking number
    // rather than an error, so the filter is the only thing standing between
    // a model swap and nonsense results.
    expect([for (final h in hits) h.chunk.text], ['current']);
  });

  test('an unrelated notebook returns nothing rather than its best guess',
      () async {
    final embedder = _FakeEmbedder(vectors: {
      'q': [1.0, 0.0, 0.0]
    });
    final retriever = build(embedder, [
      chunk('orthogonal', [0.0, 1.0, 0.0]),
    ]);

    expect(await retriever.search(query: 'q', notebookId: 1), isEmpty);
  });

  test('topK caps the number of hits', () async {
    final embedder = _FakeEmbedder();
    final retriever = build(embedder, [
      for (var i = 0; i < 10; i++) chunk('c$i', [1.0, i / 100, 0.0], ordinal: i)
    ]);

    final hits = await retriever.search(
        query: 'q', notebookId: 1, topK: 3, minScore: 0.0);
    expect(hits, hasLength(3));
  });

  test('a blank query embeds nothing', () async {
    final embedder = _FakeEmbedder();
    final retriever = build(embedder, [chunk('a', [1.0, 0.0, 0.0])]);

    expect(await retriever.search(query: '   ', notebookId: 1), isEmpty);
    expect(embedder.queries, isEmpty);
  });

  test('an empty notebook embeds nothing — no model load to search nothing',
      () async {
    final embedder = _FakeEmbedder();
    expect(await build(embedder, []).search(query: 'q', notebookId: 1), isEmpty);
    expect(embedder.queries, isEmpty);
  });

  test('a fully stale notebook embeds nothing either', () async {
    final embedder = _FakeEmbedder(modelId: 'fake-v2');
    final retriever = build(embedder, [
      chunk('stale', [1.0, 0.0, 0.0], modelId: 'fake-v1'),
    ]);

    expect(await retriever.search(query: 'q', notebookId: 1), isEmpty);
    expect(embedder.queries, isEmpty,
        reason: 'nothing is comparable, so the query need not be embedded');
  });
}
