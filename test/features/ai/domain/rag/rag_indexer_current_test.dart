// Whether a page's chunks are current for a model, without embedding anything
// (docs/TECH_MIGRATION_PLAN.md, phase 4.5). The rollout asks this of every page.

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/ai/domain/rag/note_chunk.dart';
import 'package:distill_ed/features/ai/domain/rag/prompt_contract.dart';
import 'package:distill_ed/features/ai/domain/rag/rag_indexer.dart';
import 'package:distill_ed/features/ai/domain/rag/text_embedder.dart';

class _Embedder implements TextEmbedder {
  _Embedder(this.modelId);

  @override
  final String modelId;

  @override
  int get dimensions => 3;

  @override
  PromptContract get promptContract => PromptContract.pluginGemma300m;

  @override
  int get chunkWords => 250;

  @override
  int get chunkOverlapWords => 30;

  @override
  Future<List<List<double>>> embedAll(
    List<String> texts, {
    required EmbedTaskType taskType,
  }) async =>
      [for (final _ in texts) [1.0, 0.0, 0.0]];

  @override
  Future<List<double>> embedOne(String text,
          {required EmbedTaskType taskType}) async =>
      [1.0, 0.0, 0.0];
}

/// Chunks by page, as the store keeps them.
class _Store {
  final saved = <int, List<NoteChunk>>{};

  Future<void> replace(int pageId, List<NoteChunk> chunks) async =>
      saved[pageId] = chunks;

  Future<void> delete(int pageId) async => saved.remove(pageId);

  Future<PageIndexState?> stateOf(int pageId, String modelId) async {
    final chunks = [
      for (final c in saved[pageId] ?? const <NoteChunk>[])
        if (c.embeddingModelId == modelId) c,
    ];
    if (chunks.isEmpty) return null;
    return PageIndexState(
      contentSignature: chunks.first.contentSignature,
      embeddingModelId: chunks.first.embeddingModelId,
    );
  }
}

RagIndexer _indexer(_Embedder embedder, _Store store) => RagIndexer(
      embedder: embedder,
      saveChunks: store.replace,
      deleteChunks: store.delete,
      indexStateOf: store.stateOf,
      now: () => DateTime(2026, 10, 9),
    );

void main() {
  test('a page nothing has indexed yet is not current', () async {
    final store = _Store();
    final indexer = _indexer(_Embedder('target'), store);

    expect(
      await indexer.isCurrent(notebookId: 1, pageId: 1, text: 'Cells divide.'),
      isFalse,
    );
  });

  test('a page indexed for the model is current until its text changes', () async {
    final store = _Store();
    final embedder = _Embedder('target');
    final indexer = _indexer(embedder, store);
    await indexer.indexPage(notebookId: 1, pageId: 1, text: 'Cells divide.');

    expect(
      await indexer.isCurrent(notebookId: 1, pageId: 1, text: 'Cells divide.'),
      isTrue,
    );
    expect(
      await indexer.isCurrent(notebookId: 1, pageId: 1, text: 'Cells fuse.'),
      isFalse,
    );
  });

  test('chunks built with another model do not make a page current', () async {
    final store = _Store();
    await _indexer(_Embedder('serving'), store)
        .indexPage(notebookId: 1, pageId: 1, text: 'Cells divide.');

    expect(
      await _indexer(_Embedder('target'), store)
          .isCurrent(notebookId: 1, pageId: 1, text: 'Cells divide.'),
      isFalse,
    );
  });

  test('a blank page is current only when it has no chunks for the model',
      () async {
    final store = _Store();
    final indexer = _indexer(_Embedder('target'), store);
    expect(await indexer.isCurrent(notebookId: 1, pageId: 2, text: '   '), isTrue);

    await indexer.indexPage(notebookId: 1, pageId: 2, text: 'Cells divide.');

    expect(await indexer.isCurrent(notebookId: 1, pageId: 2, text: '   '), isFalse);
  });
}
