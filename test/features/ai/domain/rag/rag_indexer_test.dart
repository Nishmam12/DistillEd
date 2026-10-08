import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/rag/note_chunk.dart';
import 'package:inkflow/features/ai/domain/rag/rag_indexer.dart';
import 'package:inkflow/features/ai/domain/rag/page_chunker.dart'
    show kChunkOverlapWords, kChunkWords;
import 'package:inkflow/features/ai/domain/rag/prompt_contract.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

/// Records what it was asked to embed, so tests can assert the EXPENSIVE call
/// was skipped — the whole point of incremental indexing.
class _FakeEmbedder implements TextEmbedder {

  @override
  PromptContract get promptContract => PromptContract.pluginGemma300m;

  @override
  int get chunkWords => kChunkWords;

  @override
  int get chunkOverlapWords => kChunkOverlapWords;

  _FakeEmbedder({this.modelId = 'fake-v1'});

  @override
  final String modelId;

  @override
  final int dimensions = 3;

  final calls = <({List<String> texts, EmbedTaskType taskType})>[];

  @override
  Future<List<List<double>>> embedAll(
    List<String> texts, {
    required EmbedTaskType taskType,
  }) async {
    calls.add((texts: texts, taskType: taskType));
    return [
      for (var i = 0; i < texts.length; i++) [i.toDouble(), 0.0, 0.0]
    ];
  }

  @override
  Future<List<double>> embedOne(String text,
          {required EmbedTaskType taskType}) async =>
      (await embedAll([text], taskType: taskType)).first;
}

class _FakeStore {
  final saved = <int, List<NoteChunk>>{};
  final deletedPages = <int>[];

  Future<void> save(int pageId, List<NoteChunk> chunks) async =>
      saved[pageId] = chunks;

  Future<void> delete(int pageId) async {
    deletedPages.add(pageId);
    saved.remove(pageId);
  }

  Future<PageIndexState?> stateOf(int pageId) async {
    final chunks = saved[pageId];
    if (chunks == null || chunks.isEmpty) return null;
    return PageIndexState(
      contentSignature: chunks.first.contentSignature,
      embeddingModelId: chunks.first.embeddingModelId,
    );
  }
}

RagIndexer _buildIndexer(_FakeEmbedder embedder, _FakeStore store) =>
    RagIndexer(
      embedder: embedder,
      saveChunks: store.save,
      deleteChunks: store.delete,
      indexStateOf: store.stateOf,
      now: () => DateTime(2026, 7, 17),
    );

void main() {
  late _FakeEmbedder embedder;
  late _FakeStore store;
  late RagIndexer indexer;

  setUp(() {
    embedder = _FakeEmbedder();
    store = _FakeStore();
    indexer = _buildIndexer(embedder, store);
  });

  Future<RagIndexOutcome> index(String text) => indexer.indexPage(
        notebookId: 1,
        pageId: 7,
        text: text,
      );

  test('a page with text is chunked, embedded, and stored', () async {
    expect(await index('Mitochondria are the powerhouse of the cell.'),
        RagIndexOutcome.indexed);

    expect(store.saved[7], hasLength(1));
    final chunk = store.saved[7]!.single;
    expect(chunk.pageId, 7);
    expect(chunk.notebookId, 1);
    expect(chunk.embedding, hasLength(3));
    expect(chunk.embeddingModelId, 'fake-v1');
  });

  test('chunks are embedded with DOCUMENT semantics, not query', () async {
    await index('Mitochondria are the powerhouse of the cell.');

    // The failure this guards is silent: query-prefixed vectors still embed,
    // still store, and still rank — just worse. See [EmbedTaskType].
    expect(embedder.calls.single.taskType, EmbedTaskType.document);
  });

  test('re-indexing unchanged text embeds nothing', () async {
    const text = 'Photosynthesis converts light into chemical energy.';
    await index(text);
    expect(embedder.calls, hasLength(1));

    expect(await index(text), RagIndexOutcome.unchanged);
    expect(embedder.calls, hasLength(1), reason: 'the model must not reload');
  });

  test('changed text re-embeds', () async {
    await index('First version of the note.');
    expect(await index('Second, quite different version of the note.'),
        RagIndexOutcome.indexed);
    expect(embedder.calls, hasLength(2));
  });

  test('unchanged text still re-embeds after the model changes', () async {
    const text = 'Stable text that never gets edited.';
    await index(text);

    // A page whose text never changes again would otherwise keep vectors the
    // retriever refuses to search, and so become permanently invisible.
    final upgraded = _buildIndexer(_FakeEmbedder(modelId: 'fake-v2'), store);
    expect(
      await upgraded.indexPage(notebookId: 1, pageId: 7, text: text),
      RagIndexOutcome.indexed,
    );
    expect(store.saved[7]!.first.embeddingModelId, 'fake-v2');
  });

  test('an emptied page loses its chunks and embeds nothing', () async {
    await index('Something worth remembering.');
    embedder.calls.clear();

    expect(await index('   '), RagIndexOutcome.cleared);
    expect(store.saved.containsKey(7), isFalse);
    expect(store.deletedPages, contains(7));
    expect(embedder.calls, isEmpty);
  });

  test('a blank page that was never indexed is a no-op, not a crash', () async {
    expect(await index(''), RagIndexOutcome.cleared);
    expect(embedder.calls, isEmpty);
  });

  test('every chunk of a page shares one signature and timestamp', () async {
    // Long enough to split into several chunks.
    await index(List.generate(700, (i) => 'word$i').join(' '));

    final chunks = store.saved[7]!;
    expect(chunks.length, greaterThan(1));
    expect(chunks.map((c) => c.contentSignature).toSet(), hasLength(1));
    expect(chunks.map((c) => c.embeddedAt).toSet(), hasLength(1));
    expect([for (final c in chunks) c.ordinal],
        List.generate(chunks.length, (i) => i));
  });

  test('a page is embedded in ONE batch, not one call per chunk', () async {
    await index(List.generate(700, (i) => 'word$i').join(' '));

    // One model load for the page; the load is the expensive part.
    expect(embedder.calls, hasLength(1));
    expect(embedder.calls.single.texts.length, store.saved[7]!.length);
  });

  group('titles', () {
    RagIndexer titled(Future<String?> Function(int notebookId, int pageId) of) =>
        RagIndexer(
          embedder: embedder,
          saveChunks: store.save,
          deleteChunks: store.delete,
          indexStateOf: store.stateOf,
          titleOf: of,
          now: () => DateTime(2026, 7, 17),
        );

    Future<RagIndexOutcome> indexWith(RagIndexer i, String text) =>
        i.indexPage(notebookId: 1, pageId: 7, text: text);

    test('the embedded text leads with the title; the stored passage does not',
        () async {
      // Which notebook a passage came from is signal for ranking across
      // notebooks, but it is not part of what the student wrote, so it must not
      // turn up inside the quoted source card.
      await indexWith(titled((_, __) async => 'Biology 101'),
          'Mitochondria make ATP.');

      expect(embedder.calls.single.texts,
          ['Biology 101\n\nMitochondria make ATP.']);
      expect(store.saved[7]!.single.text, 'Mitochondria make ATP.');
    });

    test('every chunk of a long page carries the title', () async {
      final longPage = List.generate(600, (i) => 'word$i').join(' ');
      await indexWith(titled((_, __) async => 'Biology 101'), longPage);

      final texts = embedder.calls.single.texts;
      expect(texts.length, greaterThan(1));
      for (final text in texts) {
        expect(text, startsWith('Biology 101\n\n'));
      }
    });

    test('the title lookup is given the page it is for', () async {
      int? seenNotebook, seenPage;
      await indexWith(titled((n, p) async {
        seenNotebook = n;
        seenPage = p;
        return null;
      }), 'Some text on the page.');

      expect((seenNotebook, seenPage), (1, 7));
    });

    test('no title embeds the bare passage, exactly as before', () async {
      await indexWith(titled((_, __) async => null), 'Mitochondria make ATP.');
      expect(embedder.calls.single.texts, ['Mitochondria make ATP.']);

      embedder.calls.clear();
      await index('Mitochondria make ATP too.'); // no lookup wired at all
      expect(embedder.calls.single.texts, ['Mitochondria make ATP too.']);
    });

    test('a failing title lookup indexes the page untitled rather than not at all',
        () async {
      final outcome = await indexWith(
          titled((_, __) async => throw StateError('repository closed')),
          'Mitochondria make ATP.');

      expect(outcome, RagIndexOutcome.indexed);
      expect(embedder.calls.single.texts, ['Mitochondria make ATP.']);
    });

    test('renaming the notebook re-embeds a page whose text did not change',
        () async {
      var name = 'Biology 101';
      final i = titled((_, __) async => name);
      const text = 'Mitochondria make ATP.';

      expect(await indexWith(i, text), RagIndexOutcome.indexed);
      expect(await indexWith(i, text), RagIndexOutcome.unchanged,
          reason: 'same title, same text: nothing to do');

      name = 'Cell Biology';
      expect(await indexWith(i, text), RagIndexOutcome.indexed,
          reason: 'the old vectors were built with the old title');
      expect(embedder.calls.last.texts, ['Cell Biology\n\n$text']);
    });
  });
}
