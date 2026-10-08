// One-time migration of legacy 1.x page content into the unified
// [SceneElementStore].
//
// Safety properties:
//   * Non-destructive — reads legacy data only; never deletes `.ink` files or
//     clears NotePage.shapes/importedContents.
//   * Idempotent — upserts are keyed by element id, and the [MigrationGate]
//     short-circuits once the target version is reached.
//   * Resumable — a page that already has scene rows is skipped, so a run
//     that died midway never overwrites edits made since on pages it finished.
//   * Honest — a page whose ink file is unreadable is left for the next launch
//     and the gate stays open, instead of being migrated as an empty page.
//   * Decoupled — depends on abstractions so it is fully unit-testable without
//     a native Isar database.

import '../persistence/scene_element_store.dart';
import 'legacy_adapters.dart';
import 'legacy_page_source.dart';
import 'migration_gate.dart';

class SceneMigratorV2 {
  static const int targetVersion = 2;

  final LegacyPageSource source;
  final SceneElementStore store;
  final MigrationGate gate;

  SceneMigratorV2({
    required this.source,
    required this.store,
    required this.gate,
  });

  /// Runs the migration if needed. Returns true if it actually ran, false if it
  /// was already at (or past) [targetVersion].
  Future<bool> run() async {
    if (await gate.currentVersion() >= targetVersion) return false;

    final pages = await source.loadAllPages();
    var incomplete = false;
    for (final page in pages) {
      if (page.unreadable) {
        incomplete = true;
        continue;
      }
      final elements = LegacyAdapters.pageToSceneElements(page);
      if (elements.isEmpty) continue;
      if ((await store.loadForPage(page.pageId)).isNotEmpty) continue;
      await store.upsertForPage(page.notebookId, page.pageId, elements);
    }

    if (incomplete) return true;
    await gate.setVersion(targetVersion);
    return true;
  }
}
