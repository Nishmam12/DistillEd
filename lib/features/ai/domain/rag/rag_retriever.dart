// Semantic search over a notebook's embedded chunks — the read half of RAG
// (Phase 2, Loop 2.2). Loop 2.3 feeds these passages to Summarize and
// "Ask your notes".
//
// Storage-agnostic: chunks arrive through a loader callback, so this is unit
// tested with a list and no Isar.

import 'package:flutter/foundation.dart';

import 'note_chunk.dart';
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

/// A chunk that matched a query, with its similarity.
class RetrievedChunk {
  final NoteChunk chunk;

  /// Cosine similarity to the query, 0..1 in practice.
  final double score;

  const RetrievedChunk({required this.chunk, required this.score});
}

class RagRetriever {
  final TextEmbedder _embedder;
  final Future<List<NoteChunk>> Function(int notebookId) _loadChunks;

  const RagRetriever({
    required TextEmbedder embedder,
    required Future<List<NoteChunk>> Function(int notebookId) loadChunks,
  })  : _embedder = embedder,
        _loadChunks = loadChunks;

  /// The passages in [notebookId] most relevant to [query], best first.
  ///
  /// Returns empty — rather than throwing — when the notebook has nothing
  /// searchable, so a caller can always ask.
  Future<List<RetrievedChunk>> search({
    required String query,
    required int notebookId,
    int topK = kRetrievalTopK,
    double minScore = kMinRelevance,
  }) async {
    if (query.trim().isEmpty) return const [];

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
        if (chunk.embeddingModelId == _embedder.modelId) chunk
    ];
    // Before embedding: an empty or fully-stale notebook must not pay a model
    // load just to compare the query against nothing.
    if (searchable.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[RAG] search: 0/${chunks.length} chunks searchable for notebook '
          '$notebookId (embedder modelId=${_embedder.modelId}, stored '
          'modelIds=${chunks.map((c) => c.embeddingModelId).toSet()})',
        );
      }
      return const [];
    }

    final embedWatch = kDebugMode ? (Stopwatch()..start()) : null;
    final queryVector = await _embedder.embedOne(
      query,
      taskType: EmbedTaskType.query,
    );
    embedWatch?.stop();

    final sweepWatch = kDebugMode ? (Stopwatch()..start()) : null;
    final hits = topKSimilar<NoteChunk>(
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
        'top score ${hits.isEmpty ? "n/a" : hits.first.score.toStringAsFixed(3)}',
      );
    }

    return [
      for (final hit in hits) RetrievedChunk(chunk: hit.item, score: hit.score)
    ];
  }
}
