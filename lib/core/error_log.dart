// A small on-device record of unexpected errors, so a user can send it with a bug
// report. Nothing leaves the device: there is no crash-reporting service here.
// (Remote reporting would be a new dependency and a privacy decision.)

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ErrorLog {
  ErrorLog._();

  static const _name = 'error_log.txt';
  static const _maxBytes = 100 * 1024;

  /// Appends one entry. Never throws: logging must not become the next error.
  static Future<void> record(Object error, StackTrace? stack) async {
    try {
      final file = await _file();
      final entry = '${DateTime.now().toIso8601String()}\n$error\n'
          '${stack ?? ''}\n----\n';
      if (await file.exists() && await file.length() > _maxBytes) {
        // Keep the newest half rather than growing without bound.
        final text = await file.readAsString();
        await file.writeAsString(text.substring(text.length ~/ 2));
      }
      await file.writeAsString(entry, mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('error log unavailable: $e');
    }
  }

  /// The log file if one exists, for sharing.
  static Future<File?> existing() async {
    try {
      final file = await _file();
      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  }

  static Future<File> _file() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/$_name');
}
