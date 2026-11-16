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

/// One file in the backup folder.
@immutable
class BackupFile {
  final String name;
  final int size;
  final DateTime modified;
  const BackupFile(this.name, this.size, this.modified);
}

/// How many snapshots of each notebook are kept.
const int kBackupSnapshotsKept = 5;

/// What a backup file's name says: the notebook's title and id, and when the
/// snapshot was taken (null for the older unsuffixed name).
typedef ParsedBackupName = ({String title, int id, DateTime? at});

final _snapshotName = RegExp(
    r'^(.*) \((\d+)\)(?: (\d{4})-(\d{2})-(\d{2}) (\d{2})(\d{2})(?:-\d+)?)?\.margo$');

/// The snapshot file name for [base] (from [backupFileName]) taken at [at]. A
/// second snapshot in the same minute gets "-2", "-3"… ([taken] are the names
/// already in use).
String snapshotFileName(String base, DateTime at, Iterable<String> taken) {
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp = '${at.year.toString().padLeft(4, '0')}-${two(at.month)}-'
      '${two(at.day)} ${two(at.hour)}${two(at.minute)}';
  var name = '$base $stamp.margo';
  for (var n = 2; taken.contains(name); n++) {
    name = '$base $stamp-$n.margo';
  }
  return name;
}

/// Reads a `.margo` backup name, or null when it is not one of ours.
ParsedBackupName? parseBackupName(String name) {
  final m = _snapshotName.firstMatch(name);
  if (m == null) return null;
  final id = int.tryParse(m.group(2)!);
  if (id == null) return null;
  DateTime? at;
  if (m.group(3) != null) {
    at = DateTime(int.parse(m.group(3)!), int.parse(m.group(4)!),
        int.parse(m.group(5)!), int.parse(m.group(6)!), int.parse(m.group(7)!));
  }
  return (title: m.group(1)!, id: id, at: at);
}

abstract interface class BackupTarget {
  /// Copies the file at [sourcePath] into the backup folder as [name],
  /// replacing a file of that name this app wrote earlier. Returns where the
  /// folder is, for showing the user ("Download/Margo").
  Future<String> save(String sourcePath, String name, String mimeType);

  /// Removes [name] from the backup folder, if this app wrote it.
  Future<void> delete(String name);

  /// The files this app can see in the backup folder. After a reinstall that
  /// may be none: Android shows an app only the files it wrote itself.
  Future<List<BackupFile>> list();

  /// Copies backup [name] to [destPath] so it can be read as a plain file.
  Future<void> copyOut(String name, String destPath);
}

@immutable
class BackupRecord {
  final String fingerprint;

  /// The base name (title and id) the notebook was last backed up under.
  final String fileName;

  /// The `.margo` snapshot files kept for it, oldest first. Empty for a
  /// notebook backed up before snapshots: its one file is `$fileName.margo`.
  final List<String> snapshots;
  const BackupRecord(this.fingerprint, this.fileName,
      [this.snapshots = const []]);
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
            '${r.key}': {
              'fp': r.value.fingerprint,
              'name': r.value.fileName,
              if (r.value.snapshots.isNotEmpty) 'snaps': r.value.snapshots,
            },
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
              [
                for (final n in ((r.value as Map)['snaps'] as List?) ?? const [])
                  if (n is String) n,
              ],
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
  /// notebook that has no snapshot yet). One notebook failing is recorded and
  /// the rest carry on.
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
        // Nothing changed: no new snapshot, not even for "Back up now", or a
        // few taps would replace the history with identical copies.
        if (before != null &&
            before.fingerprint == fingerprint &&
            (!force || before.snapshots.isNotEmpty) &&
            before.fileName == name) {
          unchanged++;
          continue;
        }

        // A notebook backed up before snapshots has one file, which becomes the
        // oldest snapshot.
        final kept = before == null
            ? <String>[]
            : (before.snapshots.isNotEmpty
                ? List<String>.of(before.snapshots)
                : ['${before.fileName}.margo']);
        final snapName = snapshotFileName(name, _clock(), kept);

        final bytes = await _run(NotebookArchive.encode, snapshot);
        final margo = File('$dir/backup_$id.margo');
        final md = File('$dir/backup_$id.md');
        try {
          await margo.writeAsBytes(bytes, flush: true);
          await md.writeAsString(NotebookArchive.markdown(snapshot), flush: true);
          // octet-stream: a known zip type makes Android add ".zip" to the name.
          location = await target.save(
              margo.path, snapName, 'application/octet-stream');
          await target.save(md.path, '$name.md', 'text/markdown');
        } finally {
          if (await margo.exists()) await margo.delete();
          if (await md.exists()) await md.delete();
        }
        kept.removeWhere((n) => n == snapName);
        kept.add(snapName);

        // Renamed since last time: the old readable copy goes; the snapshots
        // stay, they are the history.
        if (before != null && before.fileName != name) {
          try {
            await target.delete('${before.fileName}.md');
          } catch (_) {
            // A stale file left behind costs only a little space.
          }
        }
        // Only now, with the new snapshot safe, drop the oldest. A file that
        // will not go stays on the list for the next run to try again.
        while (kept.length > kBackupSnapshotsKept) {
          try {
            await target.delete(kept.first);
            kept.removeAt(0);
          } catch (e) {
            debugPrint('[Backup] could not remove an old snapshot: $e');
            break;
          }
        }
        records[id] = BackupRecord(fingerprint, name, kept);
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

  /// The `.margo` files in the backup folder, newest first.
  Future<List<BackupFile>> available() async {
    final all = await target.list();
    final files = [
      for (final f in all)
        if (parseBackupName(f.name) != null) f,
    ]..sort((a, b) => b.modified.compareTo(a.modified));
    return files;
  }

  /// Restores the backup file [name] from the backup folder as a new notebook.
  Future<RestoreReport> restoreNamed(String name) async {
    final dir = await tempDir();
    final copy = File('$dir/restore_${name.hashCode.toUnsigned(32)}.margo');
    try {
      await target.copyOut(name, copy.path);
      return await restore([copy.path]);
    } catch (e) {
      debugPrint('[Backup] could not read $name: $e');
      return const RestoreReport([], ['That backup could not be read.']);
    } finally {
      if (await copy.exists()) await copy.delete();
    }
  }

  Future<R> _run<Q, R>(R Function(Q) fn, Q arg) =>
      runInBackground ? compute(fn, arg) : Future.value(fn(arg));
}
