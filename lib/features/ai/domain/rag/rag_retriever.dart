// Semantic search over a notebook's embedded chunks — the read half of RAG
// (Phase 2, Loop 2.2). Loop 2.3 feeds these passages to Summarize and
// "Ask your notes".
//
// Storage-agnostic: chunks arrive through a loader callback, so this is unit
// tested with a list and no Isar.

import 'package:flutter/foundation.dart';

import '../ai_exception.dart';
import 'hybrid_search.dart';
import 'note_chunk.dart';
import 'page_chunker.dart';
import 'text_embedder.dart';
import 'vector_math.dart';

/// How many passages a search returns by default. Small on purpose — these are
/// destined for an LLM prompt with a finite token budget (see `text_budget.dart`).
const int kRetrievalTopK = 5;

/// Cosine floor below which a chunk is treated as unrelated.
///
/// PROVISIONAL — this is the one number here that cannot be derived, only
/// measured, and no on-device numbers exist yet. It is set conservatively so
/// the common failure is "found nothing" (visible, honest) rather than "found
/// something irrelevant and stated it confidently". Tune against real
/// EmbeddingGemma vectors on the target device before Loop 2.3 relies on it.
const double kMinRelevance = 0.45;

/// A chunk that matched a query, with its score.
class RetrievedChunk {
  final NoteChunk chunk;

  /// How well it matched — only comparable within one result list. Cosine
  /// similarity (0..1 in practice) when only the vector search ran; the
  /// reciprocal-rank-fusion score (a few hundredths) when keyword search took
  /// part, because the two searches' own scores cannot be added.
  final double score;

  const RetrievedChunk({required this.chunk, required this.score});
}

/// One page's plain, searchable text — what [RagRetriever] reads for pages that
/// have no embeddings yet.
typedef PageTextEntry = ({int pageId, String text});

/// Loads the plain text of every page in a notebook.
typedef PageTextLoader = Future<List<PageTextEntry>> Function(int notebookId);

/// Fixed stand-in time for chunks built on the fly for keyword search; they are
/// never stored, so it is never read.
final DateTime _notStored = DateTime.fromMillisecondsSinceEpoch(0);

class RagRetriever {
  final TextEmbedder _embedder;
  final Future<List<NoteChunk>> Function(int notebookId) _loadChunks;

  /// Where to read page text for the keyword half of the search. Null turns the
  /// keyword half off, leaving vector search exactly as it was.
  final PageTextLoader? _loadPageTexts;

  const RagRetriever({
    required this._embedder,
    required this._loadChunks,
    this._loadPageTexts,
  });

  /// The passages in [notebookId] most relevant to [query], best first.
  ///
  /// [pageIds] narrows the sweep to those pages — this is how a scoped request
  /// ("this page", "this PDF"; see `domain/ai_scope.dart`) stays inside what
  /// the user asked for. Null means the whole notebook, which is what every
  /// caller did before scopes existed. An EMPTY set means "no pages", and
  /// returns nothing rather than silently widening to the notebook: a scope
  /// that resolved to nothing must produce a grounded "not found", never an
  /// answer drawn from pages outside it.
  ///
  /// When [PageTextLoader] is wired, the vector search is joined by a keyword
  /// search and the two are merged by reciprocal rank fusion (see
  /// `hybrid_search.dart`). Keywords catch what embeddings blur — a course code,
  /// a formula name, a defined term — hold up when handwriting misreads a word,
  /// and keep working before the embedding model is downloaded. If the model is
  /// missing, keyword hits are returned alone; with none, the missing-model
  /// error still reaches the caller, so the download is still offered.
  ///
  /// Returns empty — rather than throwing — when there is nothing searchable,
  /// so a caller can always ask.
  Future<List<RetrievedChunk>> search({
    required String query,
    required int notebookId,
    Set<int>? pageIds,
    int topK = kRetrievalTopK,
    double minScore = kMinRelevance,
  }) async {
    if (query.trim().isEmpty) return const [];
    if (pageIds != null && pageIds.isEmpty) return const [];

    // Debug-only: real device numbers for the open STOP CONDITION (tune
    // kMinRelevance / decide on a heavier vector store) don't exist yet.
    // Remove once that's settled — see rag_retriever.dart's kMinRelevance doc.
    final loadWatch = kDebugMode ? (Stopwatch()..start()) : null;
    final chunks = await _loadChunks(notebookId);
    loadWatch?.stop();

    // Only chunks from the CURRENT model are comparable: vectors from a
    // different embedder live in a different space, and cosine over them
    // produces confident-looking nonsense rather than an error. Stale chunks
    // are skipped here and re-embedded by RagIndexer when their page is next
    // seen — never silently ranked.
    final searchable = [
      for (final chunk in chunks)
        if (chunk.embeddingModelId == _embedder.modelId &&
            (pageIds == null || pageIds.contains(chunk.pageId)))
          chunk
    ];
    // The keyword half. Empty when it is off, which leaves everything below
    // exactly as it was before keyword search existed.
    final keywordPool = await _keywordPool(notebookId, searchable, pageIds);
    final keywordOrder =
        keywordRank([for (final c in keywordPool) c.text], query);

    // Before embedding: an empty or fully-stale notebook must not pay a model
    // load just to compare the query against nothing.
    var hits = const <ScoredItem<NoteChunk>>[];
    if (searchable.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[RAG] search: 0/${chunks.length} chunks searchable for notebook '
          '$notebookId (embedder modelId=${_embedder.modelId}, stored '
          'modelIds=${chunks.map((c) => c.embeddingModelId).toSet()}), '
          '${keywordOrder.length} keyword hits',
        );
      }
      if (_loadPageTexts == null) return const [];
    } else {
      final embedWatch = kDebugMode ? (Stopwatch()..start()) : null;
      try {
        final queryVector = await _embedder.embedOne(
          query,
          taskType: EmbedTaskType.query,
        );
        embedWatch?.stop();

        final sweepWatch = kDebugMode ? (Stopwatch()..start()) : null;
        hits = topKSimilar<NoteChunk>(
          query: queryVector,
          candidates: searchable,
          embeddingOf: (chunk) => chunk.embedding,
          topK: topK,
          minScore: minScore,
        );
        sweepWatch?.stop();

        if (kDebugMode) {
          debugPrint(
            '[RAG] search: ${searchable.length}/${chunks.length} chunks '
            '(load ${loadWatch?.elapsedMilliseconds}ms, '
            'embed ${embedWatch?.elapsedMilliseconds}ms, '
            'sweep ${sweepWatch?.elapsedMilliseconds}ms), '
            '${keywordOrder.length} keyword hits, '
            'top score ${hits.isEmpty ? "n/a" : hits.first.score.toStringAsFixed(3)}',
          );
        }
      } on AiModelNotReadyException {
        // Keyword hits stand alone when the search model is missing. With none,
        // the error must still reach the caller: it is what turns into the
        // "download the search model" offer.
        if (keywordOrder.isEmpty) rethrow;
      }
    }

    if (_loadPageTexts == null) {
      return [
        for (final hit in hits)
          RetrievedChunk(chunk: hit.item, score: hit.score)
      ];
    }

    // Both searches name chunks by id (`pageId:ordinal`); a chunk found by both
    // is one result, not two.
    final byId = {for (final chunk in keywordPool) chunk.id: chunk};
    final fused = reciprocalRankFusion<String>([
      [for (final hit in hits) hit.item.id],
      [for (final i in keywordOrder) keywordPool[i].id],
    ]);
    return [
      for (final f in fused.take(topK))
        RetrievedChunk(chunk: byId[f.item]!, score: f.score)
    ];
  }

  /// Every chunk the keyword search may read: the stored, current-model chunks
  /// of the pages in scope, plus chunks cut on the fly from the plain text of
  /// pages that have none.
  ///
  /// The second group is what lets keyword search work before the embedding
  /// model has been downloaded, and covers pages indexed by an older model
  /// (whose vectors are skipped, so for this model they are unindexed). A page
  /// is read from one source or the other, never both, so no passage can turn
  /// up twice. Empty when the keyword half is off.
  ///
  /// ponytail: every chunk is re-tokenised on every query. Fine at the size of a
  /// student's notebook; cache the tokens per chunk if one grows to thousands.
  Future<List<NoteChunk>> _keywordPool(
    int notebookId,
    List<NoteChunk> searchable,
    Set<int>? pageIds,
  ) async {
    final loadPageTexts = _loadPageTexts;
    if (loadPageTexts == null) return const [];

    final pool = [...searchable];
    final indexedPages = {for (final chunk in searchable) chunk.pageId};
    for (final page in await loadPageTexts(notebookId)) {
      if (indexedPages.contains(page.pageId)) continue;
      if (pageIds != null && !pageIds.contains(page.pageId)) continue;
      for (final draft in chunkPage(
        text: page.text,
        notebookId: notebookId,
        pageId: page.pageId,
        maxWords: _embedder.chunkWords,
        overlapWords: _embedder.chunkOverlapWords,
      )) {
        pool.add(NoteChunk.fromDraft(
          draft,
          embedding: const [],
          embeddingModelId: '',
          contentSignature: '',
          embeddedAt: _notStored,
        ));
      }
    }
    return pool;
  }
}
