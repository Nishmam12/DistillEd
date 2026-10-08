import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_exception.dart';
import 'package:inkflow/features/ai/domain/rag/note_chunk.dart';
import 'package:inkflow/features/ai/domain/rag/rag_retriever.dart';
import 'package:inkflow/features/ai/domain/rag/page_chunker.dart'
    show kChunkOverlapWords, kChunkWords;
import 'package:inkflow/features/ai/domain/rag/prompt_contract.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

/// Maps canned text → canned vectors, and counts calls so tests can prove the
/// retriever avoided a ~175 MB model load.
class _FakeEmbedder implements TextEmbedder {

  @override
  PromptContract get promptContract => PromptContract.pluginGemma300m;

  _FakeEmbedder({
    this.modelId = 'fake-v1',
    Map<String, List<double>>? vectors,
    this.chunkWords = kChunkWords,
    this.chunkOverlapWords = kChunkOverlapWords,
  }) : _vectors = vectors ?? const {};

  @override
  final int chunkWords;

  @override
  final int chunkOverlapWords;

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

/// One page's plain text, as the keyword search is fed it.
typedef Page = ({int pageId, String text});

/// An embedder whose model is not downloaded.
class _NotReadyEmbedder implements TextEmbedder {

  @override
  PromptContract get promptContract => PromptContract.pluginGemma300m;

  @override
  int get chunkWords => kChunkWords;

  @override
  int get chunkOverlapWords => kChunkOverlapWords;

  @override
  final String modelId = 'fake-v1';

  @override
  final int dimensions = 3;

  var calls = 0;

  @override
  Future<List<double>> embedOne(String text,
      {required EmbedTaskType taskType}) async {
    calls++;
    throw const AiModelNotReadyException('Embedding model is not downloaded.');
  }

  @override
  Future<List<List<double>>> embedAll(List<String> texts,
          {required EmbedTaskType taskType}) =>
      throw UnimplementedError();
}

NoteChunk chunk(
  String text,
  List<double> embedding, {
  String modelId = 'fake-v1',
  int ordinal = 0,
  int pageId = 7,
}) =>
    NoteChunk(
      notebookId: 1,
      pageId: pageId,
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

  group('scoping to pages (domain/ai_scope.dart)', () {
    // The notebook holds a hand-written page (1) and a 3-page PDF (2, 3, 4).
    List<NoteChunk> notebook() => [
          chunk('handwritten revision note', [1.0, 0.0, 0.0], pageId: 1),
          chunk('pdf slide one', [1.0, 0.0, 0.0], pageId: 2, ordinal: 1),
          chunk('pdf slide two', [1.0, 0.0, 0.0], pageId: 3, ordinal: 2),
          chunk('pdf slide three', [1.0, 0.0, 0.0], pageId: 4, ordinal: 3),
        ];

    test('no page filter searches the whole notebook, as before', () async {
      final hits = await build(_FakeEmbedder(), notebook())
          .search(query: 'q', notebookId: 1, minScore: 0.0);
      expect(hits, hasLength(4));
    });

    test('a single-page scope returns only that page', () async {
      final hits = await build(_FakeEmbedder(), notebook()).search(
          query: 'q', notebookId: 1, pageIds: {3}, minScore: 0.0);

      expect([for (final h in hits) h.chunk.pageId], [3]);
    });

    test('a PDF scope returns that PDF and not the hand-written page',
        () async {
      final hits = await build(_FakeEmbedder(), notebook()).search(
          query: 'q', notebookId: 1, pageIds: {2, 3, 4}, minScore: 0.0);

      expect([for (final h in hits) h.chunk.pageId]..sort(), [2, 3, 4]);
    });

    test('an empty page set finds nothing rather than widening to the notebook',
        () async {
      // A scope that resolved to no pages must produce a grounded "not found".
      // Falling back to the notebook would answer from pages the student
      // explicitly scoped out.
      final embedder = _FakeEmbedder();
      final hits = await build(embedder, notebook()).search(
          query: 'q', notebookId: 1, pageIds: const {}, minScore: 0.0);

      expect(hits, isEmpty);
      expect(embedder.queries, isEmpty, reason: 'no model load for no pages');
    });

    test('a scope whose pages hold nothing indexed embeds nothing', () async {
      final embedder = _FakeEmbedder();
      final hits = await build(embedder, notebook()).search(
          query: 'q', notebookId: 1, pageIds: {99}, minScore: 0.0);

      expect(hits, isEmpty);
      expect(embedder.queries, isEmpty);
    });

    test('the model-id filter still applies inside a scope', () async {
      final hits = await build(_FakeEmbedder(modelId: 'fake-v2'), [
        chunk('stale', [1.0, 0.0, 0.0], pageId: 3, modelId: 'fake-v1'),
        chunk('current', [1.0, 0.0, 0.0],
            pageId: 3, modelId: 'fake-v2', ordinal: 1),
      ]).search(query: 'q', notebookId: 1, pageIds: {3}, minScore: 0.0);

      expect([for (final h in hits) h.chunk.text], ['current']);
    });
  });

  group('hybrid search (keywords + vectors)', () {
    RagRetriever hybrid(
      TextEmbedder embedder, {
      List<NoteChunk> chunks = const [],
      List<Page> pages = const [],
    }) =>
        RagRetriever(
          embedder: embedder,
          loadChunks: (_) async => chunks,
          loadPageTexts: (_) async => pages,
        );

    List<String> texts(List<RetrievedChunk> hits) =>
        [for (final h in hits) h.chunk.text];

    test('an exact term the embedding blurred is still found', () async {
      // X is what the vectors like; Y holds the course code the student typed
      // but sits far from the query in embedding space (cosine ≈ 0.1, under the
      // relevance floor), so on vectors alone it would never be retrieved.
      final hits = await hybrid(
        _FakeEmbedder(),
        chunks: [
          chunk('general course overview', [1.0, 0.0, 0.0]),
          chunk('CSE-101 syllabus and grading', [0.1, 1.0, 0.0], ordinal: 1),
        ],
      ).search(query: 'CSE 101 grading', notebookId: 1);

      expect(texts(hits),
          ['general course overview', 'CSE-101 syllabus and grading']);
    });

    test('a passage both searches found outranks ones only one found', () async {
      final hits = await hybrid(
        _FakeEmbedder(),
        chunks: [
          // Vector rank 1, no keyword match.
          chunk('unrelated but close', [1.0, 0.0, 0.0]),
          // Vector rank 2 AND the keyword match.
          chunk('Gibbs free energy', [0.9, 0.3, 0.0], ordinal: 1),
        ],
      ).search(query: 'Gibbs free energy', notebookId: 1);

      expect(texts(hits).first, 'Gibbs free energy',
          reason: 'agreement between the two searches wins');
    });

    test('search works before the embedding model is downloaded', () async {
      final embedder = _NotReadyEmbedder();
      final hits = await hybrid(
        embedder,
        pages: [(pageId: 7, text: 'Notes on CSE-101 grading policy')],
      ).search(query: 'CSE 101', notebookId: 1);

      expect(texts(hits), ['Notes on CSE-101 grading policy']);
      expect(hits.single.chunk.pageId, 7);
      expect(embedder.calls, 0, reason: 'nothing is embedded yet, so no load');
    });

    test('a model that cannot load does not hide what keywords found',
        () async {
      // Something IS indexed (so the vector search is attempted), the embedder
      // fails, and the keyword search finds a different page: return that.
      final hits = await hybrid(
        _NotReadyEmbedder(),
        chunks: [chunk('indexed page', [1.0, 0.0, 0.0], pageId: 1)],
        pages: [(pageId: 2, text: 'the CSE-101 syllabus')],
      ).search(query: 'CSE 101', notebookId: 1);

      expect(texts(hits), ['the CSE-101 syllabus']);
    });

    test('with nothing found by keywords either, a missing model still raises',
        () async {
      // The Ask flow turns this into the "download the search model" offer; if
      // it were swallowed the student would just see "not in your notes" and
      // never learn semantic search was off.
      await expectLater(
        hybrid(
          _NotReadyEmbedder(),
          chunks: [chunk('indexed page', [1.0, 0.0, 0.0])],
        ).search(query: 'completely different', notebookId: 1),
        throwsA(isA<AiModelNotReadyException>()),
      );
    });

    test('unindexed pages are read from their text, indexed ones from chunks',
        () async {
      final hits = await hybrid(
        _FakeEmbedder(),
        chunks: [chunk('alpha beta', [1.0, 0.0, 0.0], pageId: 1)],
        pages: [
          (pageId: 1, text: 'alpha beta'), // already indexed: must not repeat
          (pageId: 2, text: 'alpha gamma'),
        ],
      ).search(query: 'alpha', notebookId: 1);

      expect([for (final h in hits) h.chunk.pageId], [1, 2]);
      expect(texts(hits), ['alpha beta', 'alpha gamma']);
    });

    test('keyword search cuts an unindexed page to the embedder\'s own window',
        () async {
      // An unindexed page is cut on the fly for keyword search. With four-word
      // chunks the hit is the passage that holds the term, not the whole page;
      // the default 250-word window would return all twelve words.
      final hits = await hybrid(
        _FakeEmbedder(chunkWords: 4, chunkOverlapWords: 0),
        pages: [
          (
            pageId: 7,
            text: 'one two three four five six seven eight nine ten eleven twelve',
          ),
        ],
      ).search(query: 'eleven', notebookId: 1);

      expect(texts(hits), ['nine ten eleven twelve']);
    });

    test('a scope narrows the keyword search too', () async {
      final hits = await hybrid(
        _NotReadyEmbedder(),
        pages: [
          (pageId: 1, text: 'alpha one'),
          (pageId: 2, text: 'alpha two'),
        ],
      ).search(query: 'alpha', notebookId: 1, pageIds: {2});

      expect([for (final h in hits) h.chunk.pageId], [2]);
    });

    test('an empty scope still finds nothing', () async {
      final hits = await hybrid(
        _FakeEmbedder(),
        pages: [(pageId: 1, text: 'alpha')],
      ).search(query: 'alpha', notebookId: 1, pageIds: const {});

      expect(hits, isEmpty);
    });

    test('chunks from another embedding model do not hide the page text',
        () async {
      // Page 5 was indexed by an older model, so for this one it is unindexed:
      // its stale vectors are skipped, and its text is searched instead.
      final hits = await hybrid(
        _FakeEmbedder(modelId: 'fake-v2'),
        chunks: [chunk('old stale words', [1.0, 0.0, 0.0], pageId: 5, modelId: 'fake-v1')],
        pages: [(pageId: 5, text: 'fresh handwriting about enthalpy')],
      ).search(query: 'enthalpy', notebookId: 1);

      expect(texts(hits), ['fresh handwriting about enthalpy']);
    });

    test('no page-text loader leaves retrieval exactly as it was', () async {
      final hits = await build(_FakeEmbedder(), [
        chunk('CSE-101 syllabus and grading', [0.1, 1.0, 0.0]),
      ]).search(query: 'CSE 101 grading', notebookId: 1);

      expect(hits, isEmpty,
          reason: 'vectors alone, with the relevance floor, find nothing here');
    });
  });
}
