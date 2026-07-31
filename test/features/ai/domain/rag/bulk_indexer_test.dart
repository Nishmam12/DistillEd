import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_exception.dart';
import 'package:inkflow/features/ai/domain/rag/bulk_indexer.dart';
import 'package:inkflow/features/ai/domain/rag/note_chunk.dart';
import 'package:inkflow/features/ai/domain/rag/rag_indexer.dart';
import 'package:inkflow/features/ai/domain/rag/rag_retriever.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

/// Deterministic stand-in: each distinct text gets its own axis, so cosine
/// similarity is 1.0 for the same text and 0.0 for any other. Enough to prove
/// which PAGE a hit came from, which is what these tests are about.
class _AxisEmbedder implements TextEmbedder {
  @override
  final String modelId = 'fake-v1';

  @override
  final int dimensions = 8;

  final _axes = <String, int>{};
  var embedCalls = 0;

  int _axisFor(String text) {
    final key = text.trim().split(RegExp(r'\s+')).first.toLowerCase();
    return _axes.putIfAbsent(key, () => _axes.length % dimensions);
  }

  @override
  Future<List<double>> embedOne(String text,
      {required EmbedTaskType taskType}) async {
    embedCalls++;
    final v = List<double>.filled(dimensions, 0);
    v[_axisFor(text)] = 1;
    return v;
  }

  @override
  Future<List<List<double>>> embedAll(List<String> texts,
          {required EmbedTaskType taskType}) async =>
      [for (final t in texts) await embedOne(t, taskType: taskType)];
}

/// In-memory chunk storage with the same replace-by-page semantics as Isar.
class _MemoryStore {
  final byPage = <int, List<NoteChunk>>{};

  Future<void> save(int pageId, List<NoteChunk> chunks) async =>
      byPage[pageId] = chunks;

  Future<void> delete(int pageId) async => byPage.remove(pageId);

  Future<PageIndexState?> stateOf(int pageId) async {
    final chunks = byPage[pageId];
    if (chunks == null || chunks.isEmpty) return null;
    return PageIndexState(
      contentSignature: chunks.first.contentSignature,
      embeddingModelId: chunks.first.embeddingModelId,
    );
  }

  List<NoteChunk> get all => [for (final c in byPage.values) ...c];
}

({BulkRagIndexer bulk, _MemoryStore store, _AxisEmbedder embedder}) build(
  Map<int, String> pageText, {
  Set<int> failing = const {},
  Set<int> notReady = const {},
}) {
  final store = _MemoryStore();
  final embedder = _AxisEmbedder();
  final indexer = RagIndexer(
    embedder: embedder,
    saveChunks: store.save,
    deleteChunks: store.delete,
    indexStateOf: store.stateOf,
  );
  final bulk = BulkRagIndexer(
    indexer: indexer,
    readPage: (pageId) async {
      if (notReady.contains(pageId)) {
        throw const AiModelNotReadyException('embedding model missing');
      }
      if (failing.contains(pageId)) throw StateError('unreadable page');
      return pageText[pageId] ?? '';
    },
  );
  return (bulk: bulk, store: store, embedder: embedder);
}

void main() {
  group('indexing across the pages of one import', () {
    test('every page of a multi-page import is chunked and stored', () async {
      final b = build({
        10: 'Mitosis splits one nucleus into two identical nuclei.',
        11: 'Meiosis halves the chromosome number for gametes.',
        12: 'Cytokinesis divides the cytoplasm after nuclear division.',
      });

      final report = await b.bulk
          .indexPages(notebookId: 1, pageIds: [10, 11, 12]);

      expect(report.indexed, 3);
      expect(report.isComplete, isTrue);
      expect(b.store.byPage.keys, containsAll([10, 11, 12]));
    });

    test('a re-run embeds nothing when no page changed', () async {
      final b = build({10: 'Mitosis splits a nucleus.', 11: 'Meiosis halves.'});
      await b.bulk.indexPages(notebookId: 1, pageIds: [10, 11]);
      final callsAfterFirst = b.embedder.embedCalls;

      final second =
          await b.bulk.indexPages(notebookId: 1, pageIds: [10, 11]);

      expect(second.unchanged, 2);
      expect(second.indexed, 0);
      expect(b.embedder.embedCalls, callsAfterFirst,
          reason: 'unchanged pages must not pay for a second embedding pass');
    });

    test('a blank page clears rather than storing an empty chunk', () async {
      final b = build({10: 'Mitosis splits a nucleus.', 11: '   '});
      final report = await b.bulk.indexPages(notebookId: 1, pageIds: [10, 11]);

      expect(report.indexed, 1);
      expect(report.cleared, 1);
      expect(b.store.byPage.containsKey(11), isFalse);
    });
  });

  group('failure handling', () {
    test('one unreadable page does not sink the batch', () async {
      final b = build(
        {10: 'Mitosis splits.', 11: 'unreadable', 12: 'Cytokinesis divides.'},
        failing: {11},
      );

      final report =
          await b.bulk.indexPages(notebookId: 1, pageIds: [10, 11, 12]);

      expect(report.indexed, 2);
      expect(report.failedPageIds, [11]);
      expect(report.isComplete, isFalse,
          reason: 'the notebook is not fully searchable, and must say so');
    });

    test('a missing model stops the run instead of failing 40 pages in turn',
        () async {
      final b = build(
        {for (var i = 10; i < 50; i++) i: 'page $i text'},
        notReady: {12},
      );

      final report = await b.bulk
          .indexPages(notebookId: 1, pageIds: [for (var i = 10; i < 50; i++) i]);

      expect(report.stoppedModelNotReady, isTrue);
      expect(report.indexed, 2, reason: 'pages 10 and 11 finished first');
      expect(report.failedPageIds, isEmpty,
          reason: 'the rest were never attempted, so none of them "failed"');
    });

    test('cancelling stops at the next page boundary, keeping what is done',
        () async {
      final b = build({for (var i = 10; i < 20; i++) i: 'page $i text'});
      var seen = 0;

      final report = await b.bulk.indexPages(
        notebookId: 1,
        pageIds: [for (var i = 10; i < 20; i++) i],
        isCancelled: () => seen++ >= 3,
      );

      expect(report.indexed, lessThan(10));
      expect(report.indexed, greaterThan(0));
    });
  });

  test('progress runs from 0 to the page count', () async {
    final b = build({10: 'a text', 11: 'b text', 12: 'c text'});
    final seen = <int>[];

    await b.bulk.indexPages(
      notebookId: 1,
      pageIds: [10, 11, 12],
      onProgress: (p) => seen.add(p.pagesDone),
    );

    expect(seen.first, 0);
    expect(seen.last, 3);
  });

  group('regression: a freshly imported PDF is searchable without opening it',
      () {
    // The bug this whole file exists for. RagIndexScheduler only ever fires
    // from the Context Engine's per-page edit hook, so before bulk indexing a
    // 3-page import was invisible to retrieval except for whichever single page
    // the user happened to open.
    test('every page of the import retrieves, with no page ever opened',
        () async {
      const pdf = {
        10: 'Photosynthesis converts light energy into glucose.',
        11: 'Respiration releases energy from glucose in mitochondria.',
        12: 'Transpiration moves water upward through the xylem.',
      };
      final b = build(pdf);

      // Import finished → bulk index. Nothing simulates a page being opened.
      final report = await b.bulk
          .indexPages(notebookId: 1, pageIds: pdf.keys.toList());
      expect(report.indexed, 3);

      final retriever = RagRetriever(
        embedder: b.embedder,
        loadChunks: (_) async => b.store.all,
      );

      // A question whose answer lives on the LAST page of the import — the one
      // furthest from anything the old per-page trigger would have covered.
      final hits = await retriever.search(
        query: 'Transpiration moves water upward through the xylem.',
        notebookId: 1,
      );

      expect(hits, isNotEmpty);
      expect(hits.first.chunk.pageId, 12);
    });

    test('without bulk indexing only the opened page is findable', () async {
      // The old behaviour, asserted so the regression is unambiguous: index
      // page 10 alone (as the live scheduler would) and page 12 stays invisible.
      const pdf = {
        10: 'Photosynthesis converts light energy into glucose.',
        12: 'Transpiration moves water upward through the xylem.',
      };
      final b = build(pdf);
      await b.bulk.indexPages(notebookId: 1, pageIds: [10]);

      final retriever = RagRetriever(
        embedder: b.embedder,
        loadChunks: (_) async => b.store.all,
      );
      final hits = await retriever.search(
        query: 'Transpiration moves water upward through the xylem.',
        notebookId: 1,
      );

      expect(hits, isEmpty);
    });
  });
}
