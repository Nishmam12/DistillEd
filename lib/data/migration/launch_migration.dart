// One-shot launch wiring for [SceneMigratorV2] against the live Isar database.
//
// Called once from main() after the database is open. It is gated (runs only
// while AppMeta.schemaVersion < 2), non-destructive (reads legacy `.ink` +
// NotePage.shapes/importedContents, never deletes them) and idempotent, so it is
// safe to call on every launch. The migrator's logic is unit-tested with
// in-memory doubles; this is the thin production binding.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/isar/isar_service.dart';

import '../persistence/isar_scene_element_store.dart';
import 'legacy_page_source.dart';
import 'migration_gate.dart';
import 'scene_migrator.dart';

/// A consistent copy of the database, taken once before the first migration, so
/// a migration that goes wrong can be undone by hand. Never blocks the migration
/// itself: with no copy the data is still untouched (the migration only adds).
Future<void> _backupBeforeMigrating() async {
  try {
    final dir = (await getApplicationDocumentsDirectory()).path;
    final backup = File('$dir/inkflow_before_v2.isar');
    if (await backup.exists()) return;
    await IsarService.instance.copyToFile(backup.path);
  } catch (e) {
    debugPrint('Pre-migration backup skipped: $e');
  }
}

/// Runs the v1→v2 migration if needed. Never throws: a migration failure must
/// not block app start (legacy data is untouched and the app keeps working on
/// the old screens). Returns true if the migration actually ran.
Future<bool> runLaunchMigration() async {
  try {
    final gate = IsarMigrationGate();
    if (await gate.currentVersion() < SceneMigratorV2.targetVersion) {
      await _backupBeforeMigrating();
    }
    final migrator = SceneMigratorV2(
      source: IsarLegacyPageSource(),
      store: IsarSceneElementStore(),
      gate: gate,
    );
    return await migrator.run();
  } catch (e, st) {
    debugPrint('Scene migration skipped (non-fatal): $e\n$st');
    return false;
  }
}
