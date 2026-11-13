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
}
