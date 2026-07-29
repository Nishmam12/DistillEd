// Plain, searchable text for one page.
//
// Deliberately SEPARATE from NoteChunkRecord. A chunk is only written once
// EmbeddingGemma has produced a vector for it, so building search on chunks
// would make search silently unavailable to anyone who has not downloaded the
// embedding model — search must not be gated on AI. This table holds the same
// extracted text with no embedding attached, and the RAG indexer is free to
// read from the same extraction independently.
//
// NOTE: multiple `@Index()` fields means `.where()` loses findAll()/deleteAll()
// — use `.filter()` throughout (same gotcha as NoteChunkRecord).

import 'package:isar/isar.dart';

part 'page_text_record.g.dart';

@collection
class PageTextRecord {
  Id id = Isar.autoIncrement;

  /// One row per page, enforced by the store's delete-then-insert rather than a
  /// unique index: a unique index makes the generator emit Isar's
  /// `@experimental` by-index helpers, which the analyzer then flags (the same
  /// reason NoteChunkRecord does not store its natural key).
  @Index()
  late int pageId;

  @Index()
  late int notebookId;

  /// Everything readable on the page: handwriting recognition, image/PDF OCR,
  /// and typed text, exactly as the Context Engine extracted it.
  late String text;

  late DateTime updatedAt;
}
