// Keeping a page's embedded chunks current — the write half of RAG (Phase 2,
// Loop 2.2).
//
// Incremental by [pageTextSignature]: embedding is by far the most expensive
// thing the app does per page, so the work is skipped whenever the page's text
// would produce the chunks already stored.

import '../rag/note_chunk.dart';
import '../rag/page_chunker.dart';
import '../rag/text_embedder.dart';

/// What [RagIndexer.indexPage] actually did — returned rather than logged so
/// tests can assert the incremental path, and a debug UI can show it.
enum RagIndexOutcome {
  /// Chunks were embedded and stored.
  indexed,

  /// The page's stored chunks were already current; nothing was embedded.
  unchanged,

  /// The page has no readable text; any stored chunks were dropped.
  cleared,
}

/// Writes a page's chunks. Storage arrives as callbacks, so this is unit tested
/// with fakes and no Isar.
class RagIndexer {
  final TextEmbedder _embedder;
  final Future<void> Function(int pageId, List<NoteChunk> chunks) _saveChunks;
  final Future<void> Function(int pageId) _deleteChunks;

  /// What a page's stored chunks were built with, or null if it has none.
  final Future<PageIndexState?> Function(int pageId) _indexStateOf;

  final DateTime Function() _now;

  RagIndexer({
    required TextEmbedder embedder,
    required Future<void> Function(int pageId, List<NoteChunk> chunks)
        saveChunks,
    required Future<void> Function(int pageId) deleteChunks,
    required Future<PageIndexState?> Function(int pageId) indexStateOf,
    DateTime Function() now = DateTime.now,
  })  : _embedder = embedder,
        _saveChunks = saveChunks,
        _deleteChunks = deleteChunks,
        _indexStateOf = indexStateOf,
        _now = now;

  /// Brings [pageId]'s chunks in line with [text].
  ///
  /// Throws whatever [TextEmbedder] throws (typically
  /// [AiModelNotReadyException] when the model isn't downloaded) — callers
  /// decide whether that's worth surfacing. Indexing is background work, so the
  /// wiring treats it as fire-and-forget; nothing is stored on failure, so the
  /// next attempt simply retries.
  Future<RagIndexOutcome> indexPage({
    required int notebookId,
    required int pageId,
    required String text,
  }) async {
    final drafts = chunkPage(text: text, notebookId: notebookId, pageId: pageId);
    if (drafts.isEmpty) {
      // Emptied pages must lose their chunks, or deleted content stays
      // searchable — and would be quoted back as if it were still on the page.
      await _deleteChunks(pageId);
      return RagIndexOutcome.cleared;
    }

    final signature = pageTextSignature(text);
    final state = await _indexStateOf(pageId);
    // The model check is as load-bearing as the signature: after a model swap
    // the old vectors are unusable, and RagRetriever ignores them, so a page
    // whose text never changes again would otherwise stay invisible forever.
    if (state != null &&
        state.contentSignature == signature &&
        state.embeddingModelId == _embedder.modelId) {
      return RagIndexOutcome.unchanged;
    }

    final vectors = await _embedder.embedAll(
      [for (final draft in drafts) draft.text],
      taskType: EmbedTaskType.document,
    );

    final embeddedAt = _now();
    final chunks = [
      for (var i = 0; i < drafts.length; i++)
        NoteChunk.fromDraft(
          drafts[i],
          embedding: vectors[i],
          embeddingModelId: _embedder.modelId,
          contentSignature: signature,
          embeddedAt: embeddedAt,
        ),
    ];
    await _saveChunks(pageId, chunks);
    return RagIndexOutcome.indexed;
  }
}
