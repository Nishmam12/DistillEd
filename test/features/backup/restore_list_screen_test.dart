import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/data/backup/backup_service.dart';
import 'package:margo/data/backup/notebook_archive.dart';
import 'package:margo/features/backup/backup_controller.dart';
import 'package:margo/features/backup/restore_list_screen.dart';

class _Library implements BackupLibrary {
  @override
  Future<List<int>> notebookIds() async => [];
  @override
  Future<NotebookSnapshot?> snapshot(int id) async => null;
  @override
  Future<int> add(NotebookSnapshot snapshot) async => 1;
}

class _Target implements BackupTarget {
  _Target(this.found);
  final List<BackupFile> found;
  @override
  Future<String> save(String sourcePath, String name, String mimeType) async => '';
  @override
  Future<void> delete(String name) async {}
  @override
  Future<List<BackupFile>> list() async => found;
  @override
  Future<void> copyOut(String name, String destPath) async =>
      File(destPath).writeAsBytesSync(Uint8List(0));
}

class _State implements BackupStateStore {
  @override
  Future<BackupState> load() async => BackupState.empty;
  @override
  Future<void> save(BackupState state) async {}
}

BackupFile _f(String name, int day, {int size = 2048}) =>
    BackupFile(name, size, DateTime(2026, 11, day, 10));

void main() {
  test('backups group by notebook id, newest group and file first', () {
    final groups = groupBackups([
      _f('Bio (1) 2026-11-02 1000.margo', 2),
      _f('Maths (2) 2026-11-05 1000.margo', 5),
      _f('Bio (1) 2026-11-03 1000.margo', 3),
      _f('Bio (1).md', 9),
      _f('stray.margo', 9),
    ]);
    expect(groups.map((g) => g.title), ['Maths', 'Bio']);
    expect(groups.last.files.map((f) => f.name), [
      'Bio (1) 2026-11-03 1000.margo',
      'Bio (1) 2026-11-02 1000.margo',
    ]);
  });

  test('sizes read plainly', () {
    expect(backupSizeLabel(10), '10 B');
    expect(backupSizeLabel(2048), '2 KB');
    expect(backupSizeLabel(3 * 1024 * 1024), '3.0 MB');
  });

  Future<void> pump(WidgetTester tester, List<BackupFile> files) async {
    final svc = BackupService(
      library: _Library(),
      target: _Target(files),
      state: _State(),
      tempDir: () async => Directory.systemTemp.path,
      runInBackground: false,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [backupServiceProvider.overrideWithValue(svc)],
      child: const MaterialApp(home: RestoreListScreen()),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lists the snapshots; tapping one asks first', (tester) async {
    await pump(tester, [
      _f('Bio (1) 2026-11-02 1000.margo', 2),
      _f('Bio (1) 2026-11-03 1000.margo', 3),
    ]);
    expect(find.text('Bio'), findsOneWidget);
    expect(find.byKey(const ValueKey('backup:Bio (1) 2026-11-03 1000.margo')),
        findsOneWidget);
    await tester.tap(
        find.byKey(const ValueKey('backup:Bio (1) 2026-11-02 1000.margo')));
    await tester.pump();
    expect(find.text('Restore this backup?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Restore this backup?'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('with nothing visible it says why and keeps the file picker',
      (tester) async {
    await pump(tester, const []);
    expect(find.byKey(const ValueKey('restoreEmpty')), findsOneWidget);
    expect(find.byKey(const ValueKey('pickBackupFile')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
