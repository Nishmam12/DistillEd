// Save and load strokes to/from .ink JSON files in the app documents directory.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'stroke.dart';

class InkFileStorage {
  /// Returns the directory path for a notebook's ink files.
  /// Created only when [create] (saving); read and delete must not make dirs.
  static Future<String> _notebookDir(
    int notebookId, {
    bool create = false,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = '${appDir.path}/notes/$notebookId';
    if (create) await Directory(dir).create(recursive: true);
    return dir;
  }

  /// Returns the file path for a specific page's ink data.
  static Future<String> _pageFilePath(
    int notebookId,
    int pageId, {
    bool create = false,
  }) async {
    final dir = await _notebookDir(notebookId, create: create);
    return '$dir/page_$pageId.ink';
  }

  static void saveStrokesSync({
    required String notebookDir,
    required int pageId,
    required List<Stroke> strokes,
  }) {
    final filePath = '$notebookDir/page_$pageId.ink';
    final tmpFile = File('$filePath.tmp');
    final finalFile = File(filePath);
    final bakFile = File('$filePath.bak');

    final data = strokes.map((s) => s.toMap()).toList();
    final jsonString = jsonEncode(data);

    try {
      if (finalFile.existsSync()) {
        finalFile.copySync(bakFile.path);
      }

      tmpFile.writeAsStringSync(jsonString, flush: true);
      tmpFile.renameSync(finalFile.path);

      // Remove backup only after a confirmed successful rename.
      if (bakFile.existsSync()) {
        bakFile.deleteSync();
      }
    } catch (e) {
      // Clean up a partial temp file; leave .ink / .bak intact for recovery.
      if (tmpFile.existsSync()) {
        try {
          tmpFile.deleteSync();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// [strict]: throw [FormatException] when a file exists with content but none
  /// of them parses, instead of returning [] (which reads as "empty page").
  /// The migrator uses it so a corrupt page is retried, not marked migrated.
  static Future<List<Stroke>> loadStrokes({
    required int notebookId,
    required int pageId,
    bool strict = false,
  }) async {
    final filePath = await _pageFilePath(notebookId, pageId);
    final finalFile = File(filePath);
    final bakFile = File('$filePath.bak');
    final tmpFile = File('$filePath.tmp');

    var sawContent = false;
    // Attempt to load from the main file, then backup, then temp.
    for (final file in [finalFile, bakFile, tmpFile]) {
      if (!await file.exists()) continue;

      try {
        final jsonString = await file.readAsString();
        if (jsonString.trim().isEmpty) continue;
        sawContent = true;

        final data = jsonDecode(jsonString) as List<dynamic>;
        return data
            .map((item) => Stroke.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // Corrupted file, try the next one
        continue;
      }
    }

    if (strict && sawContent) {
      throw FormatException('No readable ink file for page $pageId');
    }
    return [];
  }
}
