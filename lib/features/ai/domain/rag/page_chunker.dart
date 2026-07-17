// Splitting a page into overlapping, embeddable chunks — the front half of the
// RAG pipeline (Phase 2, Loop 2.2).
//
// Pure and Isar-free: chunking is deterministic text math, so it's unit-tested
// without a model or a database. Embedding and retrieval build on this.
//
// Two properties matter for retrieval quality:
//   • Coherence — a chunk should be a readable passage, not an arbitrary cut.
//     Paragraph packing is reused wholesale from [chunkByWords] so there is ONE
//     definition of how text is divided (and over-long paragraphs hard-split
//     for free).
//   • Overlap — a concept explained across a paragraph boundary would otherwise
//     be split so that neither chunk states it fully, and neither retrieves.
//     Each chunk after the first is prefixed with the tail of the previous one.
//
// Sizing is in WORDS, like every other budget in this codebase (see
// `text_budget.dart`); the words↔tokens math lives in [AiRouter]. ~250 words is
// roughly 330 tokens at the usual ~0.75 words/token, which sits inside the
// phase spec's 200–400 token target AND inside EmbeddingGemma's 512-token
// sequence variant with headroom.

import 'dart:math' as math;

import '../text_budget.dart';

/// Total words per chunk, including its overlap prefix.
const int kChunkWords = 250;

/// Words of the previous chunk repeated at the start of the next (~12%, the
/// middle of the phase spec's 10–15% band).
const int kChunkOverlapWords = 30;

final RegExp _whitespace = RegExp(r'\s+');

/// Where a chunk came from. Enough to link a retrieved passage back to its
/// page for "jump to source" / "insert as note", and to re-chunk one page
/// without touching the rest of the notebook.
class ChunkSourceRef {
  final int notebookId;
  final int pageId;

  /// 0-based position of this chunk within its page, so a page's chunks keep
  /// their reading order.
  final int ordinal;

  const ChunkSourceRef({
    required this.notebookId,
    required this.pageId,
    required this.ordinal,
  });
}

/// A chunk before it has been embedded.
class NoteChunkDraft {
  final String text;
  final ChunkSourceRef source;

  const NoteChunkDraft({required this.text, required this.source});
}

/// Splits [text] into overlapping chunks tagged with their source page.
///
/// Blank input yields no chunks. Text that fits in one chunk yields exactly one
/// (with no overlap prefix — there's nothing to overlap with).
List<NoteChunkDraft> chunkPage({
  required String text,
  required int notebookId,
  required int pageId,
  int maxWords = kChunkWords,
  int overlapWords = kChunkOverlapWords,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];

  // Budget the NEW content per chunk so that prepending the overlap keeps the
  // total within [maxWords] rather than overflowing it.
  final int overlap = overlapWords.clamp(0, math.max(0, maxWords - 1)).toInt();
  final int bodyBudget = math.max(1, maxWords - overlap);
  final bodies = chunkByWords(trimmed, bodyBudget);

  final chunks = <NoteChunkDraft>[];
  for (var i = 0; i < bodies.length; i++) {
    // Overlap is taken from the previous BODY, not the previous chunk, so it
    // can't compound across a long page.
    final prefix = i == 0 ? '' : _lastWords(bodies[i - 1], overlap);
    chunks.add(NoteChunkDraft(
      text: prefix.isEmpty ? bodies[i] : '$prefix ${bodies[i]}',
      source: ChunkSourceRef(
        notebookId: notebookId,
        pageId: pageId,
        ordinal: i,
      ),
    ));
  }
  return chunks;
}

String _lastWords(String text, int count) {
  if (count <= 0) return '';
  final words = text.trim().split(_whitespace);
  if (words.length <= count) return words.join(' ');
  return words.sublist(words.length - count).join(' ');
}
