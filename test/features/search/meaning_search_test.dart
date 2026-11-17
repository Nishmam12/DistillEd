import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/ai/domain/rag/note_chunk.dart';
import 'package:margo/features/ai/domain/rag/page_chunker.dart'
    show kChunkOverlapWords, kChunkWords;
import 'package:margo/features/ai/domain/rag/prompt_contract.dart';
import 'package:margo/features/ai/domain/rag/text_embedder.dart';
import 'package:margo/features/search/domain/global_search.dart';
import 'package:margo/features/search/domain/meaning_search.dart';

/// Every query points along x.
class _Embedder implements TextEmbedder {
  int calls = 0;
  @override
  PromptContract get promptContract => PromptContract.pluginGemma300m;
  @override
  String get modelId => 'm1';
  @override
  int get dimensions => 2;
  @override
  int get chunkWords => kChunkWords;
  @override
  int get chunkOverlapWords => kChunkOverlapWords;
  @override
  Future<List<double>> embedOne(String text,
      {required EmbedTaskType taskType}) async {
    calls++;
    return const [1.0, 0.0];
  }

  @override
  Future<List<List<double>>> embedAll(List<String> texts,
          {required EmbedTaskType taskType}) async =>
      [for (final _ in texts) const [1.0, 0.0]];
}

NoteChunk _chunk(int nb, int page, List<double> v, {String model = 'm1', int ordinal = 0}) =>
    NoteChunk(
      notebookId: nb,
      pageId: page,
      ordinal: ordinal,
      text: 'text of page $page',
      embedding: v,
      embeddingModelId: model,
      contentSignature: 's',
      embeddedAt: DateTime(2026),
    );

NotebookCorpus _book(int id, String title, Map<int, int> pages) => NotebookCorpus(
    notebookId: id, title: title, texts: const [], pageIndexById: pages);

void main() {
  test('one query embedding, best page first, one hit per page, across notebooks',
      () async {
    final embedder = _Embedder();
    final chunks = {
      1: [
        _chunk(1, 10, [0.9, 0.1]),
        _chunk(1, 10, [0.8, 0.2], ordinal: 1), // same page: one hit
        _chunk(1, 11, [0.0, 1.0]), // unrelated: below the bar
      ],
      2: [
        _chunk(2, 20, [1.0, 0.0]),
        _chunk(2, 21, [1.0, 0.0], model: 'old'), // other model: not comparable
      ],
    };
    final hits = await searchByMeaning(
      query: 'cell division',
      embedder: embedder,
      chunksOf: (nb) async => chunks[nb]!,
      notebooks: [_book(1, 'Bio', {10: 0, 11: 1}), _book(2, 'Chem', {20: 4, 21: 5})],
    );

    expect(embedder.calls, 1);
    expect([for (final h in hits) h.hit.pageId], [20, 10]);
    expect(hits.first.notebookTitle, 'Chem');
    expect(hits.first.hit.pageLabel, 'Page 5');
  });

  test('pages the exact search found are left out', () async {
    final hits = await searchByMeaning(
      query: 'x',
      embedder: _Embedder(),
      chunksOf: (_) async => [_chunk(1, 10, [1.0, 0.0])],
      notebooks: [_book(1, 'Bio', {10: 0})],
      exclude: {10},
    );
    expect(hits, isEmpty);
  });
}
