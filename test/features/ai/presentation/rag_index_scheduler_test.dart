import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/rag/note_chunk.dart';
import 'package:inkflow/features/ai/domain/rag/rag_indexer.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';
import 'package:inkflow/features/ai/presentation/rag_index_scheduler.dart';

class _RecordingEmbedder implements TextEmbedder {
  @override
  final String modelId = 'fake-v1';

  @override
  final int dimensions = 3;

  final batches = <List<String>>[];

  @override
  Future<List<List<double>>> embedAll(
    List<String> texts, {
    required EmbedTaskType taskType,
  }) async {
    batches.add(texts);
    return [
      for (final _ in texts) const [1.0, 0.0, 0.0]
    ];
  }

  @override
  Future<List<double>> embedOne(String text,
          {required EmbedTaskType taskType}) async =>
      (await embedAll([text], taskType: taskType)).first;
}

class _ThrowingEmbedder implements TextEmbedder {
  @override
  final String modelId = 'fake-v1';

  @override
  final int dimensions = 3;

  @override
  Future<List<List<double>>> embedAll(List<String> texts,
          {required EmbedTaskType taskType}) async =>
      throw StateError('model not downloaded');

  @override
  Future<List<double>> embedOne(String text,
          {required EmbedTaskType taskType}) async =>
      throw StateError('model not downloaded');
}

/// Short idle delay so the tests don't sit for 20 seconds.
const _idle = Duration(milliseconds: 20);

RagIndexScheduler buildScheduler(
  TextEmbedder embedder, {
  Map<int, List<NoteChunk>>? saved,
}) {
  final store = saved ?? <int, List<NoteChunk>>{};
  return RagIndexScheduler(
    idleDelay: _idle,
    indexer: RagIndexer(
      embedder: embedder,
      saveChunks: (pageId, chunks) async => store[pageId] = chunks,
      deleteChunks: (pageId) async => store.remove(pageId),
      indexStateOf: (pageId) async {
        final chunks = store[pageId];
        if (chunks == null || chunks.isEmpty) return null;
        return PageIndexState(
          contentSignature: chunks.first.contentSignature,
          embeddingModelId: chunks.first.embeddingModelId,
        );
      },
    ),
  );
}

Future<void> settle() =>
    Future<void>.delayed(_idle * 3, () => Future<void>.delayed(_idle));

void main() {
  test('a page is indexed once its text settles', () async {
    final embedder = _RecordingEmbedder();
    final scheduler = buildScheduler(embedder);

    scheduler.schedule(notebookId: 1, pageId: 7, text: 'a stable note');
    expect(embedder.batches, isEmpty, reason: 'must not embed immediately');

    await settle();
    expect(embedder.batches, hasLength(1));
  });

  test('typing does not re-embed on every pause', () async {
    final embedder = _RecordingEmbedder();
    final scheduler = buildScheduler(embedder);

    // Three Context Engine passes in quick succession, as when writing.
    scheduler.schedule(notebookId: 1, pageId: 7, text: 'draft one');
    scheduler.schedule(notebookId: 1, pageId: 7, text: 'draft one two');
    scheduler.schedule(notebookId: 1, pageId: 7, text: 'draft one two three');

    await settle();

    // One model load, for the final text — not one per pause.
    expect(embedder.batches, hasLength(1));
    expect(embedder.batches.single.single, contains('three'));
  });

  test('editing one page does not cancel another', () async {
    final embedder = _RecordingEmbedder();
    final scheduler = buildScheduler(embedder);

    scheduler.schedule(notebookId: 1, pageId: 7, text: 'page seven');
    scheduler.schedule(notebookId: 1, pageId: 8, text: 'page eight');

    await settle();
    expect(embedder.batches, hasLength(2));
  });

  test('an indexing failure never escapes — the model is usually just missing',
      () async {
    final scheduler = buildScheduler(_ThrowingEmbedder());

    // The timer callback runs outside this frame, so a leaked exception would
    // surface as an unhandled async error and fail the test.
    scheduler.schedule(notebookId: 1, pageId: 7, text: 'some note');
    await settle();
  });

  test('a failed page is retried rather than marked done', () async {
    final store = <int, List<NoteChunk>>{};
    buildScheduler(_ThrowingEmbedder(), saved: store)
        .schedule(notebookId: 1, pageId: 7, text: 'some note');
    await settle();

    // Nothing stored means no signature, so the next attempt re-embeds.
    expect(store, isEmpty);

    final embedder = _RecordingEmbedder();
    buildScheduler(embedder, saved: store)
        .schedule(notebookId: 1, pageId: 7, text: 'some note');
    await settle();
    expect(embedder.batches, hasLength(1));
  });

  test('dispose drops pending work', () async {
    final embedder = _RecordingEmbedder();
    final scheduler = buildScheduler(embedder);

    scheduler.schedule(notebookId: 1, pageId: 7, text: 'note');
    scheduler.dispose();

    await settle();
    expect(embedder.batches, isEmpty);
  });
}
