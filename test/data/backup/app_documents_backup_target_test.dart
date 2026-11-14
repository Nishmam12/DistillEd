import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/data/backup/app_documents_backup_target.dart';

void main() {
  late Directory docs;
  late File source;
  late AppDocumentsBackupTarget target;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('margo_docs');
    source = File('${docs.path}/source.bin')..writeAsStringSync('one');
    target = AppDocumentsBackupTarget(() async => docs.path);
  });
  tearDown(() => docs.deleteSync(recursive: true));

  test('save copies into Documents/Margo backups, replacing an older file',
      () async {
    final where = await target.save(source.path, 'a.margo', 'application/zip');
    expect(where, 'Margo backups');
    final saved = File('${docs.path}/Margo backups/a.margo');
    expect(saved.readAsStringSync(), 'one');

    source.writeAsStringSync('two');
    await target.save(source.path, 'a.margo', 'application/zip');
    expect(saved.readAsStringSync(), 'two');
  });

  test('delete removes the file, and a missing one is not an error', () async {
    await target.save(source.path, 'a.margo', 'application/zip');
    await target.delete('a.margo');
    expect(File('${docs.path}/Margo backups/a.margo').existsSync(), isFalse);
    await target.delete('a.margo');
  });

  test('always reports app storage', () {
    expect(target.savedToAppStorage, isTrue);
  });
}
