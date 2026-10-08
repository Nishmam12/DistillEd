// Gates one-time data migrations by persisting a schema version.

import 'package:isar_community/isar.dart';

import '../../shared/isar/isar_service.dart';
import '../persistence/scene_element_record.dart';

abstract class MigrationGate {
  Future<int> currentVersion();
  Future<void> setVersion(int version);
}

/// In-memory gate for tests.
class InMemoryMigrationGate implements MigrationGate {
  int _version;
  InMemoryMigrationGate([this._version = 0]);

  @override
  Future<int> currentVersion() async => _version;

  @override
  Future<void> setVersion(int version) async => _version = version;
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
}
