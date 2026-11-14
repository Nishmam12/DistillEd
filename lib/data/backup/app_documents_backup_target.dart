// [BackupTarget] on iOS/iPadOS: a "Margo backups" folder inside the app's own
// Documents directory. iOS has no shared Downloads folder an app can write to,
// and showing Documents in the Files app would also expose the notes database,
// so backups stay private to the app — and, like the Android 8–9 fallback, are
// removed if the app is uninstalled. Plain dart:io: no platform channel.

import 'dart:io';

import 'backup_service.dart';

class AppDocumentsBackupTarget implements BackupTarget {
  /// [documentsDir] is the app's Documents path (path_provider); injected so
  /// the target is testable without a platform.
  AppDocumentsBackupTarget(this._documentsDir);

  final Future<String> Function() _documentsDir;

  /// Backups here always live in app storage.
  bool get savedToAppStorage => true;

  Future<Directory> _folder() async {
    final dir = Directory('${await _documentsDir()}/Margo backups');
    return dir.create(recursive: true);
  }

  @override
  Future<String> save(String sourcePath, String name, String mimeType) async {
    final folder = await _folder();
    await File(sourcePath).copy('${folder.path}/$name');
    return 'Margo backups';
  }

  @override
  Future<void> delete(String name) async {
    final file = File('${(await _folder()).path}/$name');
    if (await file.exists()) await file.delete();
  }
}
