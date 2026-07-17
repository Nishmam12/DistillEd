// Isar persistence for [NoteChunk]. The rules live in the pure domain; this
// entity only converts to/from it.
//
// A page's chunks are rewritten wholesale (delete-by-page then insert, in one
// [Isar.writeTxn]), so the domain's natural key [NoteChunk.id] is deliberately
// NOT stored: nothing looks a chunk up by it, and the atomic replace already
// makes duplicate (pageId, ordinal) pairs unreachable. A unique index on it
// would be a redundant column whose only other effect is to make the generator
// emit Isar's `@experimental` by-index helpers, which the analyzer then flags.
// `id` is Isar's local autoincrement and is not identity either (same
// sync-ready boundary as `domain/memory/concept_mastery.dart`).
//
// NOTE: multiple `@Index()` fields means `.where()` loses findAll()/deleteAll()
// — the store uses `.filter()` throughout (same gotcha as FlashcardRecord,
// ConceptMasteryRecord, and SummaryCache).

import 'package:isar/isar.dart';

import '../../domain/rag/note_chunk.dart';

part 'note_chunk_record.g.dart';

@collection
class NoteChunkRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late int notebookId;

  @Index()
  late int pageId;

  late int ordinal;
  late String text;

  /// Stored as 32-bit floats, not 64-bit doubles — that is what Isar's `float`
  /// typedef means here (it IS `double`, so the domain still speaks
  /// `List<double>`; only the on-disk width changes).
  ///
  /// Not a lossy tradeoff: LiteRT emits float32, so the wider column would
  /// persist zero extra information — it would just double the cost of the one
  /// field that dominates this table (768 dims → 3 KB/chunk instead of 6 KB,
  /// so ~2,000 chunks is ~6 MB instead of ~12 MB).
  late List<float> embedding;

  late String embeddingModelId;
  late String contentSignature;
  late DateTime embeddedAt;

  NoteChunk toDomain() => NoteChunk(
        notebookId: notebookId,
        pageId: pageId,
        ordinal: ordinal,
        text: text,
        embedding: embedding,
        embeddingModelId: embeddingModelId,
        contentSignature: contentSignature,
        embeddedAt: embeddedAt,
      );

  static NoteChunkRecord fromDomain(NoteChunk chunk) => NoteChunkRecord()
    ..notebookId = chunk.notebookId
    ..pageId = chunk.pageId
    ..ordinal = chunk.ordinal
    ..text = chunk.text
    ..embedding = chunk.embedding
    ..embeddingModelId = chunk.embeddingModelId
    ..contentSignature = chunk.contentSignature
    ..embeddedAt = chunk.embeddedAt;
}
