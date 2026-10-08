// Isar-backed [SceneElementStore]. Methods resolve `IsarService.instance`
// lazily, so constructing the store never touches the database; it is only
// exercised once the editor/migration runtime is wired (a later phase registers
// SceneElementRecordSchema in the Isar open call).

import 'package:isar_community/isar.dart';

import '../../domain/model/scene_element.dart';
import '../../shared/isar/isar_service.dart';
import 'scene_element_record.dart';
import 'scene_element_record_mapper.dart';
import 'scene_element_store.dart';

class IsarSceneElementStore implements SceneElementStore {
  Isar get _isar => IsarService.instance;

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
    await _isar.writeTxn(() async {
      // Map existing rows by elementId so re-running replaces rather than dupes.
      final existing = await _isar.sceneElementRecords
          .filter()
          .pageIdEqualTo(pageId)
          .findAll();
      final existingIdByElementId = <String, int>{
        for (final r in existing) r.elementId: r.id,
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
    });
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
}
