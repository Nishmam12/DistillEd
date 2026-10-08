// The indexer takes both what the model reads and how a page is cut from the
// embedder, not from constants. Each belongs to the model's vector space: change
// either and the stored vectors stop matching the text they were built from.

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/domain/rag/note_chunk.dart';
import 'package:inkflow/features/ai/domain/rag/prompt_contract.dart';
import 'package:inkflow/features/ai/domain/rag/rag_indexer.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

class _ContractEmbedder implements TextEmbedder {
  _ContractEmbedder({
    this.promptContract = PromptContract.pluginGemma300m,
    this.chunkWords = 250,
    this.chunkOverlapWords = 30,
  });

  @override
  String get modelId => 'contract-test-${promptContract.id}';

  @override
  int get dimensions => 3;

  @override
  final PromptContract promptContract;

  @override
  final int chunkWords;

  @override
  final int chunkOverlapWords;

  final embedded = <String>[];

  @override
  Future<List<List<double>>> embedAll(
    List<String> texts, {
    required EmbedTaskType taskType,
  }) async {
    embedded.addAll(texts);
    return [
      for (final _ in texts) [0.0, 0.0, 0.0]
    ];
  }

  @override
  Future<List<double>> embedOne(
    String text, {
    required EmbedTaskType taskType,
  }) async =>
      (await embedAll([text], taskType: taskType)).first;
}

RagIndexer _indexer(
  _ContractEmbedder embedder,
  List<NoteChunk> saved, {
  Future<String?> Function(int notebookId, int pageId)? titleOf,
}) =>
    RagIndexer(
      embedder: embedder,
      saveChunks: (pageId, chunks) async => saved.addAll(chunks),
      deleteChunks: (pageId) async {},
      indexStateOf: (pageId) async => null,
      titleOf: titleOf,
      now: () => DateTime(2026, 10, 8),
    );

Future<String?> _title(int notebookId, int pageId) async => 'Biology notes';

void main() {
  test('a page with no title is embedded as its passage alone', () async {
    final embedder = _ContractEmbedder();
    await _indexer(embedder, []).indexPage(
      notebookId: 1,
      pageId: 2,
      text: 'Cells divide by mitosis.',
    );
    expect(embedder.embedded, ['Cells divide by mitosis.']);
  });

  test('a contract that puts the title in the text embeds it there', () async {
    final embedder = _ContractEmbedder();
    final saved = <NoteChunk>[];
    await _indexer(embedder, saved, titleOf: _title).indexPage(
      notebookId: 1,
      pageId: 2,
      text: 'Cells divide by mitosis.',
    );
    expect(embedder.embedded, ['Biology notes\n\nCells divide by mitosis.']);
    expect(saved.single.text, 'Cells divide by mitosis.',
        reason: 'the stored chunk keeps the bare passage');
  });

  test('a contract without a title in the text embeds the passage alone',
      () async {
    final embedder = _ContractEmbedder(
      promptContract: const PromptContract(
        id: 'bare',
        appliedBy: PromptAppliedBy.plugin,
        titleInText: false,
      ),
    );
    await _indexer(embedder, [], titleOf: _title).indexPage(
      notebookId: 1,
      pageId: 2,
      text: 'Cells divide by mitosis.',
    );
    expect(embedder.embedded, ['Cells divide by mitosis.']);
  });

  test('a page is cut to the embedder\'s own chunk window', () async {
    // Twelve words at four to a chunk, no overlap: three chunks. The default
    // 250-word window would keep the whole page as one.
    final embedder = _ContractEmbedder(chunkWords: 4, chunkOverlapWords: 0);
    final saved = <NoteChunk>[];
    await _indexer(embedder, saved).indexPage(
      notebookId: 1,
      pageId: 2,
      text: 'one two three four five six seven eight nine ten eleven twelve',
    );
    expect(saved, hasLength(3));
  });
}
