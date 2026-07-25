// Reads legacy 1.x page content for migration.
//
// The abstraction lets the migrator be tested with hand-built [LegacyPageData];
// production reads notebooks/pages from Isar and strokes from the existing
// `.ink` files via [InkFileStorage].

import 'package:isar/isar.dart';

import 'legacy_models/ink_file_storage.dart';
import '../../features/home/domain/models/note_page.dart';
import '../../features/home/domain/models/notebook.dart';
import '../../shared/isar/isar_service.dart';
import 'legacy_page_data.dart';

abstract class LegacyPageSource {
  Future<List<LegacyPageData>> loadAllPages();
}

class IsarLegacyPageSource implements LegacyPageSource {
  Isar get _isar => IsarService.instance;

  @override
  Future<List<LegacyPageData>> loadAllPages() async {
    final notebooks = await _isar.notebooks.where().findAll();
    final pages = <LegacyPageData>[];
    for (final nb in notebooks) {
      final notePages =
          await _isar.notePages.filter().notebookIdEqualTo(nb.id).findAll();
      for (final p in notePages) {
        final strokes = await InkFileStorage.loadStrokes(
          notebookId: nb.id,
          pageId: p.id,
        );
        pages.add(LegacyPageData(
          notebookId: nb.id,
          pageId: p.id,
          strokes: strokes,
          shapes: p.shapes,
          imported: p.importedContents,
        ));
      }
    }
    return pages;
  }
}
