// Isar-backed [SceneElementStore], the editor's persistence. Methods resolve
// `IsarService.instance` lazily, so constructing the store never touches the
// database; `main.dart` registers SceneElementRecordSchema when it opens Isar.

import 'package:isar_community/isar.dart';

import '../../domain/model/scene_element.dart';
import '../../shared/isar/isar_service.dart';
import 'scene_element_record.dart';
import 'scene_element_record_mapper.dart';
import 'scene_element_store.dart';

class IsarSceneElementStore implements SceneElementStore {
  /// [isar] lets a test point the store at its own database.
  IsarSceneElementStore({Isar Function()? isar}) : _isarOverride = isar;

  final Isar Function()? _isarOverride;

  Isar get _isar => _isarOverride?.call() ?? IsarService.instance;

  @override
  Future<List<SceneElement>> loadForPage(int pageId) async {
    final rows = await _isar.sceneElementRecords
        .filter()
        .pageIdEqualTo(pageId)
        .findAll();
    rows.sort((a, b) => a.zOrder.compareTo(b.zOrder));
    return rows.map(SceneElementRecordMapper.fromRecord).toList();
  }

  @override
  Future<void> upsertForPage(
    int notebookId,
    int pageId,
    List<SceneElement> elements,
  ) async {
    await _isar.writeTxn(() => _upsert(notebookId, pageId, elements));
  }

  /// Must run inside a write transaction.
  Future<void> _upsert(
    int notebookId,
    int pageId,
    List<SceneElement> elements,
  ) async {
    {
      // Map existing rows by elementId so re-running replaces rather than dupes.
      // Only the two columns, not the rows: a drawn element's points are the big
      // part, and this runs on every pen-up. Both queries share a filter and so
      // an order, which pairs the lists up.
      final pageRows = _isar.sceneElementRecords.filter().pageIdEqualTo(pageId);
      final rowIds = await pageRows.idProperty().findAll();
      final elementIds = await pageRows.elementIdProperty().findAll();
      final existingIdByElementId = <String, int>{
        for (var i = 0; i < rowIds.length; i++) elementIds[i]: rowIds[i],
      };

      final records = elements.map((e) {
        final record = SceneElementRecordMapper.toRecord(
          e,
          notebookId: notebookId,
          pageId: pageId,
        );
        final prior = existingIdByElementId[e.id];
        if (prior != null) record.id = prior;
        return record;
      }).toList();

      await _isar.sceneElementRecords.putAll(records);
    }
  }

  @override
  Future<void> clearForPage(int pageId) async {
    await _isar.writeTxn(() async {
      final ids = await _isar.sceneElementRecords
          .filter()
          .pageIdEqualTo(pageId)
          .idProperty()
          .findAll();
      await _isar.sceneElementRecords.deleteAll(ids);
    });
  }

  @override
  Future<void> deleteElements(int pageId, Set<String> elementIds) async {
    if (elementIds.isEmpty) return;
    await _isar.writeTxn(() async {
      await _isar.sceneElementRecords
          .filter()
          .pageIdEqualTo(pageId)
          .anyOf(elementIds, (q, id) => q.elementIdEqualTo(id))
          .deleteAll();
    });
  }

  @override
  Future<void> replaceForPage(
    int notebookId,
    int pageId,
    List<SceneElement> elements,
  ) async {
    await _isar.writeTxn(() async {
      await _isar.sceneElementRecords
          .filter()
          .pageIdEqualTo(pageId)
          .deleteAll();
      await _upsert(notebookId, pageId, elements);
    });
  }
}
