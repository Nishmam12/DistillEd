import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/ai/domain/rag/bulk_indexer.dart';
import 'package:distill_ed/features/ai/domain/rag/prompt_contract.dart';
import 'package:distill_ed/features/ai/domain/rag/rag_indexer.dart';
import 'package:distill_ed/features/ai/domain/rag/text_embedder.dart';
import 'package:distill_ed/features/ai/presentation/notebook_index_notifier.dart';

class _Embedder implements TextEmbedder {
  @override
  String get modelId => 'm';
  @override
  int get dimensions => 1;
  @override
  PromptContract get promptContract => PromptContract.pluginGemma300m;
  @override
  int get chunkWords => 250;
  @override
  int get chunkOverlapWords => 30;
  @override
  Future<List<double>> embedOne(String text,
          {required EmbedTaskType taskType}) async =>
      [0];
  @override
  Future<List<List<double>>> embedAll(List<String> texts,
          {required EmbedTaskType taskType}) async =>
      [for (final _ in texts) [0.0]];
}

void main() {
  test('a run asked for during another waits for it, then runs', () async {
    final reads = <int>[];
    final gate = Completer<void>();
    final notifier = NotebookIndexNotifier(
      indexer: BulkRagIndexer(
        indexer: RagIndexer(
          embedder: _Embedder(),
          saveChunks: (_, _) async {},
          deleteChunks: (_) async {},
          indexStateOf: (_, _) async => null,
        ),
        readPage: (pageId) async {
          reads.add(pageId);
          if (reads.length == 1) await gate.future;
          return 'text';
        },
      ),
    );

    final first = notifier.run(notebookId: 1, pageIds: [1]);
    await Future<void>.delayed(Duration.zero);
    expect(await notifier.run(notebookId: 1, pageIds: [2]), isNull,
        reason: 'plain run is dropped while another is in flight');

    final later = notifier.runWhenFree(
        notebookId: 1, pageIds: [2], pollEvery: const Duration(milliseconds: 1));
    gate.complete();
    await first;
    await later;

    expect(reads, [1, 2]);
  });
}
