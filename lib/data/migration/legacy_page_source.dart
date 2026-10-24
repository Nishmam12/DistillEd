// Reads legacy 1.x page content for migration.
//
// The abstraction lets the migrator be tested with hand-built [LegacyPageData];
// production reads notebooks/pages from Isar and strokes from the existing
// `.ink` files via [InkFileStorage].

import 'package:isar_community/isar.dart';

import 'legacy_models/ink_file_storage.dart';
import 'legacy_models/stroke.dart';
import '../../features/home/domain/models/note_page.dart';
import '../../features/home/domain/models/notebook.dart';
import '../../shared/isar/isar_service.dart';
import 'legacy_page_data.dart';

abstract class LegacyPageSource {
  /// One page at a time: a big library is never held in memory whole.
  Stream<LegacyPageData> readPages();
}

class IsarLegacyPageSource implements LegacyPageSource {
  Isar get _isar => IsarService.instance;

  @override
  Stream<LegacyPageData> readPages() async* {
    final notebooks = await _isar.notebooks.where().findAll();
    for (final nb in notebooks) {
      final notePages =
          await _isar.notePages.filter().notebookIdEqualTo(nb.id).findAll();
      for (final p in notePages) {
        var strokes = const <Stroke>[];
        var unreadable = false;
        try {
          strokes = await InkFileStorage.loadStrokes(
            notebookId: nb.id,
            pageId: p.id,
            strict: true,
          );
        } catch (_) {
          // Corrupt or unreadable (I/O): retried next launch, not fatal to the rest.
          unreadable = true;
        }
        yield LegacyPageData(
          notebookId: nb.id,
          pageId: p.id,
          unreadable: unreadable,
          strokes: strokes,
          shapes: p.shapes,
          imported: p.importedContents,
        );
      }
    }
  }
}
