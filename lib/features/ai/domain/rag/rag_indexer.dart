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
  final Future<PageIndexState?> Function(int pageId, String modelId) _indexStateOf;

  /// What to call a page's notebook (and imported document) when embedding its
  /// chunks — see [chunkTitle]. Null embeds every chunk bare, as before.
  final Future<String?> Function(int notebookId, int pageId)? _titleOf;

  final DateTime Function() _now;

  RagIndexer({
    required TextEmbedder embedder,
    required Future<void> Function(int pageId, List<NoteChunk> chunks)
        saveChunks,
    required Future<void> Function(int pageId) deleteChunks,
    required Future<PageIndexState?> Function(int pageId, String modelId)
        indexStateOf,
    Future<String?> Function(int notebookId, int pageId)? titleOf,
    DateTime Function() now = DateTime.now,
  })  : _embedder = embedder,
        _saveChunks = saveChunks,
        _deleteChunks = deleteChunks,
        _indexStateOf = indexStateOf,
        _titleOf = titleOf,
        _now = now;

  /// A title helps ranking; it is never a precondition for indexing, so a lookup
  /// that fails (a repository closing mid-run) costs the title and nothing else.
  Future<String?> _titleFor(int notebookId, int pageId) async {
    final lookup = _titleOf;
    if (lookup == null) return null;
    try {
      final title = (await lookup(notebookId, pageId))?.trim();
      return title == null || title.isEmpty ? null : title;
    } catch (_) {
      return null;
    }
  }

  /// Whether [pageId]'s chunks, built with this embedder, are current for [text].
  /// Nothing is embedded or stored, so every page can be asked cheaply. A blank
  /// page is current when it has no chunks for this model.
  Future<bool> isCurrent({
    required int notebookId,
    required int pageId,
    required String text,
  }) async {
    final state = await _indexStateOf(pageId, _embedder.modelId);
    final drafts = chunkPage(
      text: text,
      notebookId: notebookId,
      pageId: pageId,
      maxWords: _embedder.chunkWords,
      overlapWords: _embedder.chunkOverlapWords,
    );
    if (drafts.isEmpty) return state == null;
    final title = await _titleFor(notebookId, pageId);
    final signature = pageTextSignature(
      _embedder.promptContract.embeddingInput(title, text),
    );
    return state != null &&
        state.contentSignature == signature &&
        state.embeddingModelId == _embedder.modelId;
  }

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
    final drafts = chunkPage(
      text: text,
      notebookId: notebookId,
      pageId: pageId,
      maxWords: _embedder.chunkWords,
      overlapWords: _embedder.chunkOverlapWords,
    );
    if (drafts.isEmpty) {
      // Emptied pages must lose their chunks, or deleted content stays
      // searchable — and would be quoted back as if it were still on the page.
      await _deleteChunks(pageId);
      return RagIndexOutcome.cleared;
    }

    final title = await _titleFor(notebookId, pageId);
    // The title is part of what the vectors were built from, so a rename must
    // re-embed a page whose own text never changed. With no title this is the
    // same signature as before titles existed.
    final signature = pageTextSignature(
      _embedder.promptContract.embeddingInput(title, text),
    );
    final state = await _indexStateOf(pageId, _embedder.modelId);
    // The model check is as load-bearing as the signature: after a model swap
    // the old vectors are unusable, and RagRetriever ignores them, so a page
    // whose text never changes again would otherwise stay invisible forever.
    if (state != null &&
        state.contentSignature == signature &&
        state.embeddingModelId == _embedder.modelId) {
      return RagIndexOutcome.unchanged;
    }

    final vectors = await _embedder.embedAll(
      [
        for (final draft in drafts)
          _embedder.promptContract.embeddingInput(title, draft.text),
      ],
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
