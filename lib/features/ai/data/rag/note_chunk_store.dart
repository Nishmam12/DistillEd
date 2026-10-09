// A seam over Isar for embedded chunks, so the RAG flow is unit-testable (fake
// the store) and features/ai never talks to IsarService outside data/.

import 'package:isar_community/isar.dart';


import '../../../../shared/isar/isar_service.dart';
import '../../domain/rag/note_chunk.dart';
import '../../domain/rag/embedder_rollout_runner.dart';
import 'note_chunk_record.dart';

abstract class NoteChunkStore implements RolloutChunks {
  /// Replaces the chunks a page has FROM THE MODELS in [chunks], in one
  /// transaction. The page's chunks from other models stay: during a rollout the
  /// serving model's chunks are what questions read, and must survive the target
  /// model's chunks being written beside them.
  ///
  /// Atomic on purpose: a half-written page would leave chunks whose
  /// [NoteChunk.contentSignature] claims they're current when they aren't, and
  /// indexing would then skip the page forever.
  ///
  /// An empty [chunks] clears every model's chunks for the page, as it always did.
  Future<void> replaceForPage(int pageId, List<NoteChunk> chunks);

  /// Drops a page's chunks from every model — for a page emptied or deleted.
  Future<void> deleteForPage(int pageId);

  /// Drops every chunk built with [modelId], on every page.
  @override
  Future<void> deleteModel(String modelId);

  /// Drops every chunk built with a model that is not in [keep].
  @override
  Future<void> deleteModelsExcept(Set<String> keep);

  /// Every chunk in a notebook, for a brute-force similarity sweep.
  Future<List<NoteChunk>> forNotebook(int notebookId);

  /// What [pageId]'s chunks built with [modelId] were built from, or null if it
  /// has none built with that model.
  Future<PageIndexState?> indexStateForPage(int pageId, String modelId);
}

class IsarNoteChunkStore implements NoteChunkStore {
  /// [isar] is the database to use. The app shares its one instance; a test
  /// passes a database of its own.
  IsarNoteChunkStore({Isar Function()? isar})
      : _isar = isar ?? (() => IsarService.instance);

  final Isar Function() _isar;

  @override
  Future<void> replaceForPage(int pageId, List<NoteChunk> chunks) {
    final db = _isar();
    final models = {for (final c in chunks) c.embeddingModelId};
    return db.writeTxn(() async {
      final collection = db.noteChunkRecords;
      if (models.isEmpty) {
        await collection.filter().pageIdEqualTo(pageId).deleteAll();
      }
      for (final model in models) {
        await collection
            .filter()
            .pageIdEqualTo(pageId)
            .and()
            .embeddingModelIdEqualTo(model)
            .deleteAll();
      }
      await collection
          .putAll([for (final c in chunks) NoteChunkRecord.fromDomain(c)]);
    });
  }

  @override
  Future<void> deleteForPage(int pageId) {
    final db = _isar();
    return db.writeTxn(() async {
      await db.noteChunkRecords.filter().pageIdEqualTo(pageId).deleteAll();
    });
  }

  @override
  Future<void> deleteModel(String modelId) {
    final db = _isar();
    return db.writeTxn(() async {
      await db.noteChunkRecords.filter().embeddingModelIdEqualTo(modelId).deleteAll();
    });
  }

  @override
  Future<void> deleteModelsExcept(Set<String> keep) {
    final db = _isar();
    return db.writeTxn(() async {
      final collection = db.noteChunkRecords;
      final models = {
        for (final row in await collection.filter().idGreaterThan(Isar.minId).findAll())
          row.embeddingModelId,
      };
      for (final model in models) {
        if (!keep.contains(model)) {
          await collection.filter().embeddingModelIdEqualTo(model).deleteAll();
        }
      }
    });
  }

  /// Decoded chunks of the most recently searched notebooks. Decoding every
  /// embedding (768 floats a chunk) on every question was most of a search's cost.
  /// A notebook is served from here while its chunk ids are unchanged; ids are
  /// auto-incremented, so any page re-indexed, added or deleted — by this store or
  /// by `content_purge.dart` writing around it — changes (count, highest id).
  final _cache = <int, ({int count, int maxId, List<NoteChunk> chunks})>{};
  static const _cachedNotebooks = 2;

  @override
  Future<List<NoteChunk>> forNotebook(int notebookId) async {
    final query =
        _isar().noteChunkRecords.filter().notebookIdEqualTo(notebookId);
    final ids = await query.idProperty().findAll();
    final maxId = ids.fold<int>(0, (m, id) => id > m ? id : m);
    final cached = _cache[notebookId];
    if (cached != null && cached.count == ids.length && cached.maxId == maxId) {
      return cached.chunks;
    }
    final rows = await query.findAll();
    final chunks = List<NoteChunk>.unmodifiable([for (final r in rows) r.toDomain()]);
    _cache.remove(notebookId);
    _cache[notebookId] = (count: ids.length, maxId: maxId, chunks: chunks);
    while (_cache.length > _cachedNotebooks) {
      _cache.remove(_cache.keys.first);
    }
    return chunks;
  }

  @override
  Future<PageIndexState?> indexStateForPage(int pageId, String modelId) async {
    final row = await _isar()
        .noteChunkRecords
        .filter()
        .pageIdEqualTo(pageId)
        .and()
        .embeddingModelIdEqualTo(modelId)
        .findFirst();
    if (row == null) return null;
    return PageIndexState(
      contentSignature: row.contentSignature,
      embeddingModelId: row.embeddingModelId,
    );
  }
}
