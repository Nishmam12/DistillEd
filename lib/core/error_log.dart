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

  static Future<void> _last = Future.value();

  /// Appends one entry. Never throws: logging must not become the next error.
  /// Calls are chained so concurrent errors cannot interleave or race the trim.
  static Future<void> record(Object error, StackTrace? stack) =>
      _last = _last.then((_) => _record(error, stack));

  static Future<void> _record(Object error, StackTrace? stack) async {
    try {
      final file = await _file();
      final entry = '${DateTime.now().toIso8601String()}\n$error\n'
          '${stack ?? ''}\n----\n';
      if (await file.exists() && await file.length() > _maxBytes) {
        // Keep the newest half rather than growing without bound.
        final text = await file.readAsString();
        // Cut at an entry boundary so no half entry is left at the top.
        final cut = text.indexOf('----\n', text.length ~/ 2);
        await file.writeAsString(cut < 0 ? '' : text.substring(cut + 5));
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
