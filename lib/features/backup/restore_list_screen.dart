// "Restore from a backup": the backups in Download/Margo, grouped by notebook,
// newest first. Tapping one adds it back as a new notebook (nothing is
// overwritten). After a reinstall Android may show none of them, so picking a
// file by hand stays on the screen.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/backup/backup_service.dart';
import '../home/presentation/home_notifier.dart';
import 'backup_controller.dart';

/// The backups, as groups of snapshots of one notebook (newest group first).
class BackupGroup {
  final int id;
  final String title;
  final List<BackupFile> files; // newest first
  const BackupGroup(this.id, this.title, this.files);
}

/// Groups [files] by the notebook id in their names. The title shown is the
/// newest file's.
List<BackupGroup> groupBackups(List<BackupFile> files) {
  final byId = <int, List<BackupFile>>{};
  for (final f in files) {
    final parsed = parseBackupName(f.name);
    if (parsed != null) (byId[parsed.id] ??= []).add(f);
  }
  final groups = [
    for (final e in byId.entries)
      BackupGroup(
        e.key,
        parseBackupName((e.value
              ..sort((a, b) => b.modified.compareTo(a.modified)))
            .first
            .name)!.title,
        e.value,
      ),
  ]..sort((a, b) => b.files.first.modified.compareTo(a.files.first.modified));
  return groups;
}

String backupSizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _when(BackupFile f) {
  final at = parseBackupName(f.name)?.at ?? f.modified;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
}

class RestoreListScreen extends ConsumerStatefulWidget {
  const RestoreListScreen({super.key});

  @override
  ConsumerState<RestoreListScreen> createState() => _RestoreListScreenState();
}

class _RestoreListScreenState extends ConsumerState<RestoreListScreen> {
  List<BackupGroup>? _groups;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final files =
          await ref.read(backupControllerProvider.notifier).available();
      if (mounted) setState(() => _groups = groupBackups(files));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _restoreNamed(BackupFile file) async {
    final label = parseBackupName(file.name)?.title ?? file.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text('"$label" from ${_when(file)} comes back as a new '
            'notebook. Nothing you have now is changed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              key: const ValueKey('confirmRestore'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => ref
        .read(backupControllerProvider.notifier)
        .restoreNamed(file.name));
  }

  Future<void> _pickFile() async {
    // FileType.any: Android maps no MIME type to ".margo".
    final picked = await FilePicker.pickFiles(type: FileType.any);
    if (picked.isEmpty) return;
    final paths = [
      for (final f in picked)
        if (f.path case final p? when p.toLowerCase().endsWith('.margo')) p,
    ];
    if (paths.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Pick a .margo file — a Margo backup or shared notebook.')));
      return;
    }
    await _run(() => ref.read(backupControllerProvider.notifier).restore(paths));
  }

  Future<void> _run(Future<RestoreReport> Function() restore) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    // Read before the awaits: the screen may be left while this runs.
    final home = ref.read(homeNotifierProvider.notifier);
    final RestoreReport report;
    try {
      report = await restore();
      await home.loadNotebooks();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final restored = report.restored.length;
    messenger.showSnackBar(SnackBar(
      content: Text([
        if (restored > 0)
          'Restored $restored notebook${restored == 1 ? '' : 's'}.',
        if (report.failed.isNotEmpty) report.failed.first,
      ].join(' ')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groups = _groups;
    return Scaffold(
      appBar: AppBar(title: const Text('Restore from a backup')),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: groups == null && !_failed
                ? const Center(child: CircularProgressIndicator())
                : (groups == null || groups.isEmpty)
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            _failed
                                ? 'The backup folder could not be read. You '
                                    'can still pick a file.'
                                : 'No backups to show. After a reinstall, '
                                    'Android hides earlier backups from the app: '
                                    'pick a .margo file from Download/Margo instead.',
                            key: const ValueKey('restoreEmpty'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.textSecondary),
                          ),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final g in groups) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                              child: Text(g.title,
                                  style: Theme.of(context).textTheme.titleSmall),
                            ),
                            for (final f in g.files)
                              ListTile(
                                key: ValueKey('backup:${f.name}'),
                                title: Text(_when(f)),
                                subtitle: Text(
                                    parseBackupName(f.name)?.title == g.title
                                        ? backupSizeLabel(f.size)
                                        : '${parseBackupName(f.name)?.title} · '
                                            '${backupSizeLabel(f.size)}'),
                                enabled: !_busy,
                                onTap: () => _restoreNamed(f),
                              ),
                          ],
                        ],
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton(
                key: const ValueKey('pickBackupFile'),
                onPressed: _busy ? null : _pickFile,
                child: const Text('Pick a file instead…'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
