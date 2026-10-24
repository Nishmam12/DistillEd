// Gates one-time data migrations by persisting a schema version.

import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/isar/isar_service.dart';
import '../persistence/scene_element_record.dart';

abstract class MigrationGate {
  Future<int> currentVersion();
  Future<void> setVersion(int version);

  /// Whether this page's legacy content has been carried over. A recorded fact,
  /// not inferred from the page having elements: a student who erased a migrated
  /// page would otherwise get the old drawing back on the next launch.
  Future<bool> isPageMigrated(int pageId);
  Future<void> markPageMigrated(int pageId);

  /// Counts a launch that ended with unreadable pages; returns the new total.
  Future<int> bumpIncompleteRuns();
}

/// In-memory gate for tests.
class InMemoryMigrationGate implements MigrationGate {
  int _version;
  InMemoryMigrationGate([this._version = 0]);

  @override
  Future<int> currentVersion() async => _version;

  @override
  Future<void> setVersion(int version) async => _version = version;

  final _pages = <int>{};

  @override
  Future<bool> isPageMigrated(int pageId) async => _pages.contains(pageId);

  @override
  Future<void> markPageMigrated(int pageId) async => _pages.add(pageId);

  int _runs = 0;

  @override
  Future<int> bumpIncompleteRuns() async => ++_runs;
}

/// Isar-backed gate using the singleton [AppMeta] row.
class IsarMigrationGate implements MigrationGate {
  Isar get _isar => IsarService.instance;

  @override
  Future<int> currentVersion() async {
    final meta = await _isar.appMetas.get(0);
    return meta?.schemaVersion ?? 0;
  }

  @override
  Future<void> setVersion(int version) async {
    await _isar.writeTxn(() async {
      await _isar.appMetas.put(AppMeta()
        ..id = 0
        ..schemaVersion = version);
    });
  }

  // Kept in SharedPreferences rather than a new Isar field: it is a small set of
  // ids, and an Isar schema change here would mean regenerating code for nothing.
  static const _pagesKey = 'migration.v2.pages';

  @override
  Future<bool> isPageMigrated(int pageId) async =>
      ((await SharedPreferences.getInstance()).getStringList(_pagesKey) ??
              const [])
          .contains('$pageId');

  @override
  Future<void> markPageMigrated(int pageId) async {
    final prefs = await SharedPreferences.getInstance();
    final pages = prefs.getStringList(_pagesKey) ?? <String>[];
    if (!pages.contains('$pageId')) {
      await prefs.setStringList(_pagesKey, [...pages, '$pageId']);
    }
  }

  static const _runsKey = 'migration.v2.incompleteRuns';

  @override
  Future<int> bumpIncompleteRuns() async {
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt(_runsKey) ?? 0) + 1;
    await prefs.setInt(_runsKey, n);
    return n;
  }
}
