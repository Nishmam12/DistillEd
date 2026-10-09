import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_exception.dart';
import 'package:inkflow/features/ai/domain/device_state.dart';
import 'package:inkflow/features/ai/domain/rag/bulk_indexer.dart';
import 'package:inkflow/features/ai/domain/rag/note_chunk.dart';
import 'package:inkflow/features/ai/domain/rag/rag_indexer.dart';
import 'package:inkflow/features/ai/domain/rag/rag_retriever.dart';
import 'package:inkflow/features/ai/domain/rag/page_chunker.dart'
    show kChunkOverlapWords, kChunkWords;
import 'package:inkflow/features/ai/domain/rag/prompt_contract.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

/// Deterministic stand-in: each distinct text gets its own axis, so cosine
/// similarity is 1.0 for the same text and 0.0 for any other. Enough to prove
/// which PAGE a hit came from, which is what these tests are about.
class _AxisEmbedder implements TextEmbedder {

  @override
  PromptContract get promptContract => PromptContract.pluginGemma300m;

  @override
  int get chunkWords => kChunkWords;

  @override
  int get chunkOverlapWords => kChunkOverlapWords;

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

/// Logs each page it embeds as `embed:<first word's page id>` — the text starts
/// with nothing page-specific, so it identifies pages by the order they arrive.
class _LoggingEmbedder implements TextEmbedder {

  @override
  PromptContract get promptContract => PromptContract.pluginGemma300m;

  @override
  int get chunkWords => kChunkWords;

  @override
  int get chunkOverlapWords => kChunkOverlapWords;

  _LoggingEmbedder(this.events, {this.missing = false});

  final List<String> events;
  final bool missing;

  @override
  final String modelId = 'fake-v1';

  @override
  final int dimensions = 3;

  /// Page ids by the text they were given, so the log can name them.
  static const _ids = {
    'Mitosis': 10,
    'Meiosis': 11,
    'Cytokinesis': 12,
    'page': 0,
  };

  @override
  Future<List<List<double>>> embedAll(List<String> texts,
      {required EmbedTaskType taskType}) async {
    if (missing) throw const AiModelNotReadyException('embedding model missing');
    for (final text in texts) {
      final first = text.trim().split(RegExp(r'\s+')).first;
      events.add('embed:${_ids[first] ?? first}');
    }
    return [for (final _ in texts) const [1.0, 0.0, 0.0]];
  }

  @override
  Future<List<double>> embedOne(String text,
          {required EmbedTaskType taskType}) async =>
      (await embedAll([text], taskType: taskType)).first;
}

/// In-memory chunk storage with the same replace-by-page semantics as Isar.
class _MemoryStore {
  final byPage = <int, List<NoteChunk>>{};

  Future<void> save(int pageId, List<NoteChunk> chunks) async =>
      byPage[pageId] = chunks;

  Future<void> delete(int pageId) async => byPage.remove(pageId);

  Future<PageIndexState?> stateOf(int pageId, String modelId) async {
    final chunks = [
      for (final c in byPage[pageId] ?? const <NoteChunk>[])
        if (c.embeddingModelId == modelId) c,
    ];
    if (chunks.isEmpty) return null;
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

  group('batched by model — all the vision work, then all the embedding', () {
    // One log shared by the reader, the embedder and the release hook, so the
    // ORDER of work is what gets asserted — which is the whole point: a 40-page
    // import used to alternate Gemma and the embedder page by page.
    ({
      BulkRagIndexer bulk,
      List<String> events,
      List<(int, int, String)> saved,
    }) logged(
      Map<int, String> pageText, {
      bool batch = true,
      bool embedderReady = true,
      Set<int> unreadable = const {},
      Set<int> modelMissingOnRead = const {},
      bool embedderMissing = false,
    }) {
      final events = <String>[];
      final saved = <(int, int, String)>[];
      final store = _MemoryStore();
      final embedder = _LoggingEmbedder(events, missing: embedderMissing);
      final indexer = RagIndexer(
        embedder: embedder,
        saveChunks: store.save,
        deleteChunks: store.delete,
        indexStateOf: store.stateOf,
      );
      final bulk = BulkRagIndexer(
        indexer: indexer,
        batchByModel: batch,
        readPage: (pageId) async {
          events.add('read:$pageId');
          if (modelMissingOnRead.contains(pageId)) {
            throw const AiModelNotReadyException('vision model missing');
          }
          if (unreadable.contains(pageId)) throw StateError('unreadable');
          return pageText[pageId] ?? '';
        },
        embedderReady: () async {
          events.add('ready?');
          return embedderReady;
        },
        releaseVisionModel: () async => events.add('release'),
        onPageRead: (notebookId, pageId, text) async =>
            saved.add((notebookId, pageId, text)),
      );
      return (bulk: bulk, events: events, saved: saved);
    }

    final pages = {
      10: 'Mitosis splits one nucleus into two.',
      11: 'Meiosis halves the chromosome number.',
      12: 'Cytokinesis divides the cytoplasm.',
    };

    test('every page is read before any is embedded, Gemma released between',
        () async {
      final b = logged(pages);

      final report = await b.bulk.indexPages(notebookId: 1, pageIds: [10, 11, 12]);

      expect(report.indexed, 3);
      expect(b.events, [
        'ready?',
        'read:10', 'read:11', 'read:12',
        'release',
        'embed:10', 'embed:11', 'embed:12',
      ]);
    });

    test('a missing search model stops before a single expensive read',
        () async {
      // Reading 40 pages with the vision model only to find the embedder is not
      // downloaded would throw all of that work away.
      final b = logged(pages, embedderReady: false);

      final report = await b.bulk.indexPages(notebookId: 1, pageIds: [10, 11, 12]);

      expect(report.stoppedModelNotReady, isTrue);
      expect(b.events, ['ready?'], reason: 'no read, no release, no embed');
    });

    test('each page\'s text is saved as it is read — before any embedding',
        () async {
      // So search works for a page the moment it has been read, and keeps
      // working for someone who has never downloaded the embedding model.
      final b = logged(pages, embedderMissing: true);

      final report = await b.bulk.indexPages(notebookId: 1, pageIds: [10, 11, 12]);

      expect(report.stoppedModelNotReady, isTrue);
      expect(b.saved, [
        (1, 10, pages[10]!),
        (1, 11, pages[11]!),
        (1, 12, pages[12]!),
      ]);
    });

    test('the vision model is not released when nothing was read', () async {
      final b = logged(pages, unreadable: {10, 11, 12});

      final report = await b.bulk.indexPages(notebookId: 1, pageIds: [10, 11, 12]);

      expect(report.failedPageIds, [10, 11, 12]);
      expect(b.events, isNot(contains('release')));
    });

    test('an unreadable page is skipped; the rest are still embedded', () async {
      final b = logged(pages, unreadable: {11});

      final report = await b.bulk.indexPages(notebookId: 1, pageIds: [10, 11, 12]);

      expect(report.indexed, 2);
      expect(report.failedPageIds, [11]);
      expect(b.events.where((e) => e.startsWith('embed')), ['embed:10', 'embed:12']);
    });

    test('a model missing partway through the reads still embeds what was read',
        () async {
      final b = logged(pages, modelMissingOnRead: {12});

      final report = await b.bulk.indexPages(notebookId: 1, pageIds: [10, 11, 12]);

      expect(report.stoppedModelNotReady, isTrue);
      expect(report.stoppedVisionNotReady, isTrue);
      expect(report.indexed, 2, reason: 'pages 10 and 11 were read first');
    });

    test('cancelling during the reads still embeds the pages already read',
        () async {
      final b = logged(pages);
      var polls = 0;

      final report = await b.bulk.indexPages(
        notebookId: 1,
        pageIds: [10, 11, 12],
        isCancelled: () => polls++ >= 2, // page 10 and 11 read, then cancel
      );

      // Cancel means stop reading — the expensive part — not throw away pages
      // that are already read and cost almost nothing to embed.
      expect(report.indexed, 2);
      expect(b.events.where((e) => e.startsWith('read:')), ['read:10', 'read:11']);
    });

    test('cancelling during the embedding stops it at the next page', () async {
      final b = logged(pages);
      var polls = 0;
      // Three reads poll three times (no cancel); the embedding then cancels.
      final report = await b.bulk.indexPages(
        notebookId: 1,
        pageIds: [10, 11, 12],
        isCancelled: () => polls++ >= 4,
      );

      expect(report.indexed, lessThan(3));
      expect(report.indexed, greaterThan(0));
    });

    test('progress reports the reading, then the indexing', () async {
      final b = logged(pages);
      final seen = <(BulkIndexPhase, int, int)>[];

      await b.bulk.indexPages(
        notebookId: 1,
        pageIds: [10, 11, 12],
        onProgress: (p) => seen.add((p.phase, p.pagesDone, p.pagesTotal)),
      );

      expect(seen, [
        (BulkIndexPhase.reading, 0, 3),
        (BulkIndexPhase.reading, 1, 3),
        (BulkIndexPhase.reading, 2, 3),
        (BulkIndexPhase.reading, 3, 3),
        (BulkIndexPhase.indexing, 0, 3),
        (BulkIndexPhase.indexing, 1, 3),
        (BulkIndexPhase.indexing, 2, 3),
        (BulkIndexPhase.indexing, 3, 3),
      ]);
    });

    test('with batching off, pages go through one at a time as before',
        () async {
      final b = logged(pages, batch: false);

      await b.bulk.indexPages(notebookId: 1, pageIds: [10, 11]);

      expect(b.events, [
        'read:10', 'embed:10',
        'read:11', 'embed:11',
      ], reason: 'no pre-check, no release, no batching');
      expect(b.saved, isEmpty);
    });
  });

  group('waiting for a hot or low-battery device', () {
    // Sustained inference on a tablet throttles: a read that takes 2 s cold can
    // take far longer after ten minutes of indexing, and a phone on 10% battery
    // should not be spending it on a background job.
    BulkRagIndexer gated(
      List<String> events,
      PauseReason? Function() reason, {
      bool batch = true,
    }) {
      final store = _MemoryStore();
      return BulkRagIndexer(
        batchByModel: batch,
        indexer: RagIndexer(
          embedder: _LoggingEmbedder(events),
          saveChunks: store.save,
          deleteChunks: store.delete,
          indexStateOf: store.stateOf,
        ),
        readPage: (id) async {
          events.add('read:$id');
          return 'Mitosis splits one nucleus into two.';
        },
        pauseReason: () async => reason(),
        pollInterval: const Duration(milliseconds: 5),
      );
    }

    test('waits while the device is hot, then carries on', () async {
      final events = <String>[];
      PauseReason? now = PauseReason.hot;
      final bulk = gated(events, () => now);

      final run = bulk.indexPages(notebookId: 1, pageIds: [10, 11]);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(events, isEmpty, reason: 'nothing may be read while it is hot');

      now = null; // it has cooled
      final report = await run;

      expect(report.indexed, 2);
      expect(events.where((e) => e.startsWith('read:')), ['read:10', 'read:11']);
    });

    test('says why it is waiting, so the UI can tell the student', () async {
      final events = <String>[];
      PauseReason? now = PauseReason.lowBattery;
      final seen = <PauseReason?>[];
      final bulk = gated(events, () => now);

      final run = bulk.indexPages(
        notebookId: 1,
        pageIds: [10],
        onProgress: (p) => seen.add(p.paused),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      now = null;
      await run;

      expect(seen, contains(PauseReason.lowBattery));
      expect(seen.last, isNull, reason: 'the final report is not a paused one');
    });

    test('is checked before EVERY read, not just the first', () async {
      final events = <String>[];
      final clock = Stopwatch()..start();
      // Cool for the first read; hot for the next 50 ms once one page is read.
      PauseReason? check() {
        final reads = events.where((e) => e.startsWith('read:')).length;
        return reads == 1 && clock.elapsedMilliseconds < 50
            ? PauseReason.hot
            : null;
      }

      final report = await gated(events, check)
          .indexPages(notebookId: 1, pageIds: [10, 11]);

      expect(report.indexed, 2);
      expect(clock.elapsedMilliseconds, greaterThanOrEqualTo(45),
          reason: 'the second read waited out the pause');
    });

    test('a cancel ends the wait instead of waiting for ever', () async {
      final events = <String>[];
      final bulk = gated(events, () => PauseReason.hot); // never cools
      var polls = 0;

      await bulk.indexPages(
        notebookId: 1,
        pageIds: [10, 11],
        isCancelled: () => polls++ >= 3,
      );

      expect(events, isEmpty);
    });

    test('the one-at-a-time loop waits too', () async {
      final events = <String>[];
      PauseReason? now = PauseReason.hot;
      final bulk = gated(events, () => now, batch: false);

      final run = bulk.indexPages(notebookId: 1, pageIds: [10]);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(events, isEmpty);

      now = null;
      await run;
      expect(events, contains('read:10'));
    });
  });
}
