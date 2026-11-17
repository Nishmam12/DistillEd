// Search by meaning for the home search (Evernote's semantic results, but on
// the device): the query is embedded once and compared with the chunk
// embeddings the tutor already keeps for every notebook. Results come back as
// [GlobalSearchHit]s, so the panel lists and opens them like exact matches.

import '../../ai/domain/rag/note_chunk.dart';
import '../../ai/domain/rag/rag_retriever.dart' show kMinRelevance;
import '../../ai/domain/rag/text_embedder.dart';
import '../../ai/domain/rag/vector_math.dart';
import 'global_search.dart';
import 'note_search.dart';

/// Pages of [notebooks] whose notes mean what [query] asks — at most one hit
/// per page, best first, [maxTotal] in all — leaving out [exclude] (pages the
/// exact search already found). The snippet is the start of the best chunk.
///
/// Throws what the embedder throws (e.g. its model is not downloaded yet);
/// callers show no meaning results then.
Future<List<GlobalSearchHit>> searchByMeaning({
  required String query,
  required TextEmbedder embedder,
  required Future<List<NoteChunk>> Function(int notebookId) chunksOf,
  required List<NotebookCorpus> notebooks,
  Set<int> exclude = const {},
  int maxTotal = 8,
  double minScore = kMinRelevance,
}) async {
  if (query.trim().isEmpty || notebooks.isEmpty) return const [];
  final vector = await embedder.embedOne(
    embedder.promptContract.queryInput(query),
    taskType: EmbedTaskType.query,
  );

  final scored = <({NotebookCorpus book, ScoredItem<NoteChunk> hit})>[];
  for (final book in notebooks) {
    final chunks = [
      for (final c in await chunksOf(book.notebookId))
        // Only chunks embedded by the model that embedded the query compare.
        if (c.embeddingModelId == embedder.modelId && !exclude.contains(c.pageId))
          c,
    ];
    for (final hit in topKSimilar<NoteChunk>(
      query: vector,
      candidates: chunks,
      embeddingOf: (c) => c.embedding,
      topK: maxTotal,
      minScore: minScore,
    )) {
      scored.add((book: book, hit: hit));
    }
  }
  scored.sort((a, b) => b.hit.score.compareTo(a.hit.score));

  final seenPages = <int>{};
  final out = <GlobalSearchHit>[];
  for (final s in scored) {
    final chunk = s.hit.item;
    if (!seenPages.add(chunk.pageId)) continue;
    final pageIndex = s.book.pageIndexById[chunk.pageId];
    if (pageIndex == null) continue; // a page since deleted
    out.add(GlobalSearchHit(
      notebookId: s.book.notebookId,
      notebookTitle: s.book.title,
      hit: NoteSearchHit(
        pageId: chunk.pageId,
        pageIndex: pageIndex,
        snippet: _snippet(chunk.text),
        matchStart: 0,
        matchLength: 0,
      ),
    ));
    if (out.length >= maxTotal) break;
  }
  return out;
}

String _snippet(String text) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length <= 120 ? flat : '${flat.substring(0, 120)}…';
}
