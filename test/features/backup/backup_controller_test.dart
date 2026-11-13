import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/data/backup/backup_service.dart';
import 'package:margo/data/backup/notebook_archive.dart';
import 'package:margo/features/backup/backup_controller.dart';

class _Library implements BackupLibrary {
  @override
  Future<List<int>> notebookIds() async => [1];
  @override
  Future<NotebookSnapshot?> snapshot(int id) async => NotebookSnapshot(
        sourceId: id,
        meta: NotebookMeta(
            title: 'N',
            backgroundColor: 0,
            templateIndex: 0,
            layoutMode: 0,
            tags: const [],
            createdAt: DateTime.utc(2026)),
        pages: const [PageSnapshot(elements: [])],
        media: const {},
      );

  @override
  Future<int> add(NotebookSnapshot snapshot) async => 2;
}

class _Target implements BackupTarget {
  int saves = 0;
  @override
  Future<String> save(String sourcePath, String name, String mimeType) async {
    saves++;
    return 'Download/Margo';
  }

  @override
  Future<void> delete(String name) async {}
}

class _State implements BackupStateStore {
  BackupState s = BackupState.empty;
  @override
  Future<BackupState> load() async => s;
  @override
  Future<void> save(BackupState state) async => s = state;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('margo_bc_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  ({BackupController ctl, _Target target}) make(SettingsState settings) {
    final target = _Target();
    final state = _State();
    final service = BackupService(
      library: _Library(),
      target: target,
      state: state,
      tempDir: () async => tmp.path,
      runInBackground: false,
    );
    return (
      ctl: BackupController(
          service: () => service,
          stateStore: state,
          settings: () => settings),
      target: target,
    );
  }

  test('switched off, automatic triggers do nothing', () async {
    final m = make(SettingsState(loaded: true));
    expect(await m.ctl.trigger(BackupTrigger.leftEditor), isNull);
    expect(m.target.saves, 0);
  });

  test('switched off, "Back up now" still backs up', () async {
    final m = make(SettingsState(loaded: true));
    final report = await m.ctl.trigger(BackupTrigger.manual);
    expect(report?.written, 1);
    expect(m.ctl.state.saved.lastSuccessAt, isNotNull);
    expect(m.ctl.state.running, isFalse);
  });

  test('switched on, leaving a note backs up', () async {
    final m = make(SettingsState(loaded: true, autoBackup: true));
    final report = await m.ctl.trigger(BackupTrigger.leftEditor);
    expect(report?.written, 1);
  });

  test('daily: a second check the same day does nothing', () async {
    final m = make(SettingsState(
        loaded: true, autoBackup: true, backupFrequency: BackupFrequency.daily));
    await m.ctl.trigger(BackupTrigger.appResumed);
    expect(await m.ctl.trigger(BackupTrigger.appResumed), isNull);
  });

  test('settings not read yet: no automatic backup', () async {
    final m = make(SettingsState(autoBackup: true));
    expect(await m.ctl.trigger(BackupTrigger.appResumed), isNull);
  });
}
