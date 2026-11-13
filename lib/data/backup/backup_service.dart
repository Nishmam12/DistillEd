// Automatic backup: every notebook written to the backup folder as a `.margo`
// file (lossless, restorable) and a `.md` file (readable anywhere), only when
// it changed since the last backup.
//
// The parts it needs are interfaces so the logic is testable without a
// database, a platform channel or a clock:
//   BackupLibrary     reads notebooks out of the app, adds them back
//   BackupTarget      the folder backups go to (Download/Margo on Android)
//   BackupStateStore  what was backed up last time, and how the last run went

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/settings_provider.dart' show BackupFrequency;
import 'notebook_archive.dart';

export '../../core/providers/settings_provider.dart' show BackupFrequency;

/// What prompted a backup check.
enum BackupTrigger { appResumed, leftEditor, manual }

/// Whether a backup should run now. A notebook that has never been backed up
/// is always due; "after each note" runs when a note is left, and also once a
/// day on start-up so a note left open is still covered.
bool isBackupDue(
  BackupFrequency frequency,
  DateTime? lastRunAt,
  DateTime now,
  BackupTrigger trigger,
) {
  if (trigger == BackupTrigger.manual || lastRunAt == null) return true;
  if (frequency == BackupFrequency.afterEditing &&
      trigger == BackupTrigger.leftEditor) {
    return true;
  }
  return now.difference(lastRunAt) >= frequency.period;
}

/// The file name (without extension) a notebook is backed up under: its title,
/// made safe for a file name, and its id so two notebooks with one title do not
/// overwrite each other.
String backupFileName(String title, int notebookId) {
  var name = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (name.isEmpty) name = 'Notebook';
  if (name.length > 60) name = name.substring(0, 60).trim();
  return '$name ($notebookId)';
}

abstract interface class BackupLibrary {
  /// The notebooks to back up (the ones not in the trash).
  Future<List<int>> notebookIds();

  /// Everything in notebook [id]; null when it is gone.
  Future<NotebookSnapshot?> snapshot(int id);

  /// Adds [snapshot] to the app as a new notebook; returns its id.
  Future<int> add(NotebookSnapshot snapshot);
}

abstract interface class BackupTarget {
  /// Copies the file at [sourcePath] into the backup folder as [name],
  /// replacing a file of that name this app wrote earlier. Returns where the
  /// folder is, for showing the user ("Download/Margo").
  Future<String> save(String sourcePath, String name, String mimeType);

  /// Removes [name] from the backup folder, if this app wrote it.
  Future<void> delete(String name);
}

@immutable
class BackupRecord {
  final String fingerprint;
  final String fileName;
  const BackupRecord(this.fingerprint, this.fileName);
}

@immutable
class BackupState {
  /// Per notebook id: what was last written for it.
  final Map<int, BackupRecord> records;
  final DateTime? lastRunAt;

  /// The last run in which every notebook was backed up.
  final DateTime? lastSuccessAt;
  final String? lastError;
  final String? location;

  const BackupState({
    required this.records,
    this.lastRunAt,
    this.lastSuccessAt,
    this.lastError,
    this.location,
  });

  static const empty = BackupState(records: {});

  Map<String, Object?> toJson() => {
        'records': {
          for (final r in records.entries)
            '${r.key}': {'fp': r.value.fingerprint, 'name': r.value.fileName},
        },
        'lastRunAt': lastRunAt?.toIso8601String(),
        'lastSuccessAt': lastSuccessAt?.toIso8601String(),
        'lastError': lastError,
        'location': location,
      };

  static BackupState fromJson(Map<String, dynamic> j) => BackupState(
        records: {
          for (final r in (j['records'] as Map<String, dynamic>? ?? {}).entries)
            ?int.tryParse(r.key): BackupRecord(
              (r.value as Map)['fp'] as String,
              (r.value as Map)['name'] as String,
            ),
        },
        lastRunAt: DateTime.tryParse(j['lastRunAt'] as String? ?? ''),
        lastSuccessAt: DateTime.tryParse(j['lastSuccessAt'] as String? ?? ''),
        lastError: j['lastError'] as String?,
        location: j['location'] as String?,
      );
}

abstract interface class BackupStateStore {
  Future<BackupState> load();
  Future<void> save(BackupState state);
}

class SharedPrefsBackupStateStore implements BackupStateStore {
  const SharedPrefsBackupStateStore();
  static const _key = 'backup.state';

  @override
  Future<BackupState> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return BackupState.empty;
      return BackupState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[Backup] could not read backup state: $e');
      return BackupState.empty;
    }
  }

  @override
  Future<void> save(BackupState state) async {
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(state.toJson()));
  }
}

@immutable
class BackupReport {
  final int written;
  final int unchanged;
  final int failed;
  final String? location;
  const BackupReport({
    required this.written,
    required this.unchanged,
    required this.failed,
    this.location,
  });
}

@immutable
class RestoreReport {
  /// Titles of the notebooks added.
  final List<String> restored;

  /// Why each file that could not be restored was refused.
  final List<String> failed;
  const RestoreReport(this.restored, this.failed);
}

class BackupService {
  BackupService({
    required this.library,
    required this.target,
    required this.state,
    required this.tempDir,
    DateTime Function()? clock,
    this.runInBackground = true,
  }) : _clock = clock ?? DateTime.now;

  final BackupLibrary library;
  final BackupTarget target;
  final BackupStateStore state;
  final Future<String> Function() tempDir;
  final DateTime Function() _clock;

  /// Zips on a background isolate, so a big notebook does not stall the UI.
  final bool runInBackground;

  /// Backs up every notebook that changed since the last run ([force]: every
  /// notebook). One notebook failing is recorded and the rest carry on.
  Future<BackupReport> run({bool force = false}) async {
    final previous = await state.load();
    final records = Map<int, BackupRecord>.of(previous.records);
    final dir = await tempDir();
    var written = 0, unchanged = 0;
    final failures = <String>[];
    String? location = previous.location;

    for (final id in await library.notebookIds()) {
      try {
        final snapshot = await library.snapshot(id);
        if (snapshot == null) continue;
        final name = backupFileName(snapshot.meta.title, id);
        final fingerprint = await _run(NotebookArchive.fingerprint, snapshot);
        final before = records[id];
        if (!force &&
            before != null &&
            before.fingerprint == fingerprint &&
            before.fileName == name) {
          unchanged++;
          continue;
        }

        final bytes = await _run(NotebookArchive.encode, snapshot);
        final margo = File('$dir/backup_$id.margo');
        final md = File('$dir/backup_$id.md');
        try {
          await margo.writeAsBytes(bytes, flush: true);
          await md.writeAsString(NotebookArchive.markdown(snapshot), flush: true);
          // octet-stream: a known zip type makes Android add ".zip" to the name.
          location = await target.save(
              margo.path, '$name.margo', 'application/octet-stream');
          await target.save(md.path, '$name.md', 'text/markdown');
        } finally {
          if (await margo.exists()) await margo.delete();
          if (await md.exists()) await md.delete();
        }

        // Renamed since last time: the files under the old name go.
        if (before != null && before.fileName != name) {
          for (final ext in const ['margo', 'md']) {
            try {
              await target.delete('${before.fileName}.$ext');
            } catch (_) {
              // A stale file left behind costs only a little space.
            }
          }
        }
        records[id] = BackupRecord(fingerprint, name);
        written++;
      } catch (e, st) {
        debugPrint('[Backup] notebook $id failed: $e\n$st');
        failures.add('$id');
      }
    }

    final now = _clock();
    await state.save(BackupState(
      records: records,
      lastRunAt: now,
      lastSuccessAt: failures.isEmpty ? now : previous.lastSuccessAt,
      lastError: failures.isEmpty
          ? null
          : '${failures.length} notebook${failures.length == 1 ? '' : 's'} '
              'could not be backed up.',
      location: location,
    ));
    return BackupReport(
      written: written,
      unchanged: unchanged,
      failed: failures.length,
      location: location,
    );
  }

  /// Adds the notebook in each `.margo` file at [paths] as a new notebook.
  /// Never overwrites anything.
  Future<RestoreReport> restore(List<String> paths) async {
    final restored = <String>[];
    final failed = <String>[];
    for (final path in paths) {
      try {
        final bytes = await File(path).readAsBytes();
        final snapshot = await _run(NotebookArchive.decode, bytes);
        await library.add(snapshot);
        restored.add(snapshot.meta.title);
      } on NotebookArchiveException catch (e) {
        failed.add(e.message);
      } catch (e) {
        debugPrint('[Backup] restore of $path failed: $e');
        failed.add('A notebook could not be restored.');
      }
    }
    return RestoreReport(restored, failed);
  }

  Future<R> _run<Q, R>(R Function(Q) fn, Q arg) =>
      runInBackground ? compute(fn, arg) : Future.value(fn(arg));
}
