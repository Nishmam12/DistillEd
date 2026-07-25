// Save and load strokes to/from .ink JSON files in the app documents directory.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'stroke.dart';

class InkFileStorage {
  /// Returns the directory path for a notebook's ink files.
  static Future<String> _notebookDir(int notebookId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = '${appDir.path}/notes/$notebookId';
    await Directory(dir).create(recursive: true);
    return dir;
  }

  /// Returns the file path for a specific page's ink data.
  static Future<String> _pageFilePath(int notebookId, int pageId) async {
    final dir = await _notebookDir(notebookId);
    return '$dir/page_$pageId.ink';
  }

  static Future<void> saveStrokes({
    required int notebookId,
    required int pageId,
    required List<Stroke> strokes,
  }) async {
    final filePath = await _pageFilePath(notebookId, pageId);
    final tmpFile = File('$filePath.tmp');
    final finalFile = File(filePath);
    final bakFile = File('$filePath.bak');

    final data = strokes.map((s) => s.toMap()).toList();
    final jsonString = jsonEncode(data);

    try {
      // 1. Create a backup of the current file if it exists
      if (await finalFile.exists()) {
        await finalFile.copy(bakFile.path);
      }

      // 2. Write to the temporary file
      await tmpFile.writeAsString(jsonString);

      // 3. Atomically replace the final file
      await tmpFile.rename(finalFile.path);

      // 4. Remove backup only after a confirmed successful rename
      if (await bakFile.exists()) {
        await bakFile.delete();
      }
    } catch (e) {
      // On failure, remove a partial temp file so it cannot be mistaken for a
      // valid page by the load fallback. The original .ink / .bak are left
      // intact for recovery. Rethrow so the caller is aware the save failed.
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
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

      tmpFile.writeAsStringSync(jsonString);
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

  static Future<List<Stroke>> loadStrokes({
    required int notebookId,
    required int pageId,
  }) async {
    final filePath = await _pageFilePath(notebookId, pageId);
    final finalFile = File(filePath);
    final bakFile = File('$filePath.bak');
    final tmpFile = File('$filePath.tmp');

    // Attempt to load from the main file, then backup, then temp.
    for (final file in [finalFile, bakFile, tmpFile]) {
      if (!await file.exists()) continue;

      try {
        final jsonString = await file.readAsString();
        if (jsonString.trim().isEmpty) continue;

        final data = jsonDecode(jsonString) as List<dynamic>;
        return data
            .map((item) => Stroke.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // Corrupted file, try the next one
        continue;
      }
    }

    return [];
  }

  /// Deletes all ink files for a given notebook.
  static Future<void> deleteNotebookInkFiles(int notebookId) async {
    final dir = await _notebookDir(notebookId);
    final directory = Directory(dir);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /// Deletes the ink file for a specific page.
  static Future<void> deletePageInkFile({
    required int notebookId,
    required int pageId,
  }) async {
    final filePath = await _pageFilePath(notebookId, pageId);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
