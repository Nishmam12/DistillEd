// [BackupTarget] on Android: Download/Margo, through the app's backup channel
// (MainActivity.kt). On Android 8–9 the files go to the app's own external
// folder instead, which a reinstall erases; [savedToAppStorage] says so.

import 'package:flutter/services.dart';

import 'backup_service.dart';

class DownloadsBackupTarget implements BackupTarget {
  DownloadsBackupTarget({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.margo.margo/backup');

  final MethodChannel _channel;

  /// True once a save has landed in app storage rather than Downloads.
  bool savedToAppStorage = false;

  @override
  Future<String> save(String sourcePath, String name, String mimeType) async {
    final reply = await _channel.invokeMapMethod<String, Object?>('save', {
      'sourcePath': sourcePath,
      'name': name,
      'mimeType': mimeType,
    });
    savedToAppStorage = reply?['appStorage'] == true;
    return reply?['location'] as String? ?? 'Download/Margo';
  }

  @override
  Future<void> delete(String name) =>
      _channel.invokeMethod<void>('delete', {'name': name});

  @override
  Future<List<BackupFile>> list() async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>('list');
    return [
      for (final r in rows ?? const <Map<Object?, Object?>>[])
        if (r['name'] case final String name)
          BackupFile(
            name,
            (r['size'] as num?)?.toInt() ?? 0,
            DateTime.fromMillisecondsSinceEpoch(
                (r['modified'] as num?)?.toInt() ?? 0),
          ),
    ];
  }

  @override
  Future<void> copyOut(String name, String destPath) =>
      _channel.invokeMethod<void>('copyOut', {'name': name, 'destPath': destPath});
}
