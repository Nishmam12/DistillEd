// An embedded passage of a note — the unit RAG stores and retrieves.
//
// Pure: this is what [chunkPage] produces once a [TextEmbedder] has given each
// draft a vector. Persistence lives in `data/rag/note_chunk_store.dart`.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'page_chunker.dart';

/// A chunk of a page, with its embedding, ready to be searched.
class NoteChunk {
  /// Stable identity for this chunk: `<pageId>:<ordinal>`.
  ///
  /// Derived rather than random so re-indexing a page overwrites its chunks
  /// in place instead of accumulating orphans — chunk 3 of page 7 is always
  /// the same row.
  String get id => '$pageId:$ordinal';

  final int notebookId;
  final int pageId;

  /// Position within the page, preserving reading order.
  final int ordinal;

  /// The passage itself — kept so a hit can be shown/quoted without re-reading
  /// the page (and so "insert as note" works offline).
  final String text;

  final List<double> embedding;

  /// [TextEmbedder.modelId] that produced [embedding]. Vectors from different
  /// models are not comparable, so retrieval filters on this rather than
  /// silently ranking across incompatible spaces.
  final String embeddingModelId;

  /// [pageTextSignature] of the page text this chunk was built from. Lets
  /// indexing skip a page whose content hasn't changed since it was embedded.
  final String contentSignature;

  final DateTime embeddedAt;

  const NoteChunk({
    required this.notebookId,
    required this.pageId,
    required this.ordinal,
    required this.text,
    required this.embedding,
    required this.embeddingModelId,
    required this.contentSignature,
    required this.embeddedAt,
  });

  /// Pairs a [NoteChunkDraft] with the vector just computed for it.
  factory NoteChunk.fromDraft(
    NoteChunkDraft draft, {
    required List<double> embedding,
    required String embeddingModelId,
    required String contentSignature,
    required DateTime embeddedAt,
  }) =>
      NoteChunk(
        notebookId: draft.source.notebookId,
        pageId: draft.source.pageId,
        ordinal: draft.source.ordinal,
        text: draft.text,
        embedding: embedding,
        embeddingModelId: embeddingModelId,
        contentSignature: contentSignature,
        embeddedAt: embeddedAt,
      );
}

/// What a page's stored chunks were built from — enough for [RagIndexer] to
/// decide whether re-embedding is needed, without loading a single vector.
class PageIndexState {
  final String contentSignature;
  final String embeddingModelId;

  const PageIndexState({
    required this.contentSignature,
    required this.embeddingModelId,
  });
}

/// Fingerprint of a page's extracted text, used to decide whether re-embedding
/// is needed.
///
/// Deliberately over the TEXT, not over [sceneContentSignature]'s scene shape:
/// the scene signature changes when a stroke is added, but two scenes can
/// extract to identical text (a stroke redrawn, an element reordered without
/// affecting reading order). Embedding is the expensive step, so the cheapest
/// correct question is "would the chunks come out the same?" — and that depends
/// only on the text.
String pageTextSignature(String text) =>
    sha1.convert(utf8.encode(text.trim())).toString();
