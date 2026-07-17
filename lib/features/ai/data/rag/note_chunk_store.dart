// A seam over Isar for embedded chunks, so the RAG flow is unit-testable (fake
// the store) and features/ai never talks to IsarService outside data/.

import 'package:isar/isar.dart';

import '../../../../shared/isar/isar_service.dart';
import '../../domain/rag/note_chunk.dart';
import 'note_chunk_record.dart';

abstract class NoteChunkStore {
  /// Replaces a page's chunks with [chunks] in one transaction.
  ///
  /// Atomic on purpose: a half-written page would leave chunks whose
  /// [NoteChunk.contentSignature] claims they're current when they aren't, and
  /// indexing would then skip the page forever.
  Future<void> replaceForPage(int pageId, List<NoteChunk> chunks);

  /// Drops a page's chunks — for a page emptied or deleted.
  Future<void> deleteForPage(int pageId);

  /// Every chunk in a notebook, for a brute-force similarity sweep.
  Future<List<NoteChunk>> forNotebook(int notebookId);

  /// What [pageId]'s chunks were built from, or null if it has none.
  Future<PageIndexState?> indexStateForPage(int pageId);
}

class IsarNoteChunkStore implements NoteChunkStore {
  @override
  Future<void> replaceForPage(int pageId, List<NoteChunk> chunks) {
    return IsarService.instance.writeTxn(() async {
      final collection = IsarService.instance.noteChunkRecords;
      await collection.filter().pageIdEqualTo(pageId).deleteAll();
      await collection
          .putAll([for (final c in chunks) NoteChunkRecord.fromDomain(c)]);
    });
  }

  @override
  Future<void> deleteForPage(int pageId) {
    return IsarService.instance.writeTxn(() async {
      await IsarService.instance.noteChunkRecords
          .filter()
          .pageIdEqualTo(pageId)
          .deleteAll();
    });
  }

  @override
  Future<List<NoteChunk>> forNotebook(int notebookId) async {
    final rows = await IsarService.instance.noteChunkRecords
        .filter()
        .notebookIdEqualTo(notebookId)
        .findAll();
    return [for (final r in rows) r.toDomain()];
  }

  @override
  Future<PageIndexState?> indexStateForPage(int pageId) async {
    final row = await IsarService.instance.noteChunkRecords
        .filter()
        .pageIdEqualTo(pageId)
        .findFirst();
    if (row == null) return null;
    return PageIndexState(
      contentSignature: row.contentSignature,
      embeddingModelId: row.embeddingModelId,
    );
  }
}
