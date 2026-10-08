// The rollout's indexing job over the notebooks' pages (docs/TECH_MIGRATION_PLAN.md,
// phase 4.5): it counts what is not yet current for the target, and brings it current.

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/domain/rag/note_chunk.dart';
import 'package:inkflow/features/ai/domain/rag/notebook_rollout_index.dart';
import 'package:inkflow/features/ai/domain/rag/prompt_contract.dart';
import 'package:inkflow/features/ai/domain/rag/rag_indexer.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

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

void main() {
  late List<RolloutPage> pages;
  late _Store store;
  late NotebookRolloutIndex index;

  setUp(() {
    pages = [
      const RolloutPage(notebookId: 1, pageId: 1, text: 'Cells divide.'),
      const RolloutPage(notebookId: 1, pageId: 2, text: 'Plants photosynthesize.'),
    ];
    store = _Store();
    index = NotebookRolloutIndex(
      pages: () async => pages,
      indexerFor: (target) => RagIndexer(
        embedder: target,
        saveChunks: store.replace,
        deleteChunks: store.delete,
        indexStateOf: store.stateOf,
        now: () => DateTime(2026, 10, 9),
      ),
    );
  });

  test('every page with text is counted, and each is pending until indexed',
      () async {
    final target = _Embedder('target');

    expect(await index.indexablePages(), 2);
    expect(await index.pendingPages(target), 2);

    await index.indexPending(target);

    expect(await index.pendingPages(target), 0);
  });

  test('an edited page becomes pending again, and only that page', () async {
    final target = _Embedder('target');
    await index.indexPending(target);

    pages[1] = const RolloutPage(
        notebookId: 1, pageId: 2, text: 'Plants respire too.');

    expect(await index.pendingPages(target), 1);
    await index.indexPending(target);
    expect(await index.pendingPages(target), 0);
  });

  test('chunks built with the serving model do not count for the target',
      () async {
    await index.indexPending(_Embedder('serving'));

    expect(await index.pendingPages(_Embedder('target')), 2);
  });
}
