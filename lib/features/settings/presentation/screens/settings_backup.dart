part of 'settings_screen.dart';

/// "Backup": automatic backup on/off, how often, Back up now, when it last
/// ran and where, and restoring notebooks from `.margo` files.
class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final c = context.colors;

    return _SettingsCard(
      icon: AppIcons.cloud,
      title: 'Backup',
      children: [
        _SettingsRow(
          icon: AppIcons.cloud,
          title: 'Back up automatically',
          subtitle: 'Each notebook as a .margo file you can restore, plus a '
              'readable .md copy, in Download/Margo',
          trailing: _AccentSwitch(
            value: settings.autoBackup,
            onChanged: notifier.setAutoBackup,
          ),
          onTap: () => notifier.setAutoBackup(!settings.autoBackup),
        ),
        if (settings.autoBackup)
          // Label, then the chips below it (like the language row): four options
          // are wider than a trailing slot leaves on a narrow phone.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SettingsRow(icon: AppIcons.clock, title: 'How often'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppChipGroup<BackupFrequency>(
                    key: const ValueKey('backupFrequency'),
                    value: settings.backupFrequency,
                    options: [
                      for (final f in BackupFrequency.values) (f, f.label),
                    ],
                    onChanged: notifier.setBackupFrequency,
                  ),
                ),
              ),
            ],
          ),
        const _BackupStatusRow(),
        _SettingsRow(
          icon: AppIcons.folder,
          title: 'Restore from a backup…',
          subtitle: 'Pick .margo files. Each comes back as a new notebook; '
              'nothing is overwritten.',
          onTap: () => _restore(context, ref),
          trailing: AppIcon(
            AppIcons.arrowRight,
            size: 20,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }

  static Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    // FileType.any: Android maps no MIME type to ".margo", so a custom filter
    // would refuse to open. The extension is checked here instead.
    // Several files may be picked; empty when the user cancels.
    final picked = await FilePicker.pickFiles(type: FileType.any);
    if (picked.isEmpty) return;
    final paths = [
      for (final f in picked)
        if (f.path case final p? when p.toLowerCase().endsWith('.margo')) p,
    ];
    if (paths.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Pick a .margo file — a Margo backup or shared notebook.')));
      return;
    }

    final report =
        await ref.read(backupControllerProvider.notifier).restore(paths);
    await ref.read(homeNotifierProvider.notifier).loadNotebooks();
    final restored = report.restored.length;
    messenger.showSnackBar(SnackBar(
      content: Text([
        if (restored > 0)
          'Restored $restored notebook${restored == 1 ? '' : 's'}.',
        if (report.failed.isNotEmpty) report.failed.first,
      ].join(' ')),
    ));
  }
}

/// When the last backup ran and where, or what went wrong, with Back up now.
class _BackupStatusRow extends ConsumerWidget {
  const _BackupStatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(backupControllerProvider);
    final saved = status.saved;
    final error = saved.lastError;
    final when = saved.lastSuccessAt;

    final String subtitle;
    if (status.running) {
      subtitle = 'Backing up…';
    } else if (error != null) {
      subtitle = error;
    } else if (when == null) {
      subtitle = 'Not backed up yet';
    } else {
      final where = saved.location ?? 'Download/Margo';
      subtitle = 'Last backed up ${_ago(when)} · $where'
          '${status.inAppStorage ? '\nOn this Android version backups stay in '
              'Margo\'s own folder and are removed if the app is uninstalled.' : ''}';
    }

    return _SettingsRow(
      icon: error != null ? AppIcons.infoCircle : AppIcons.saved,
      title: 'Back up now',
      subtitle: subtitle,
      trailing: status.running
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              key: const ValueKey('backupNow'),
              onPressed: () => ref
                  .read(backupControllerProvider.notifier)
                  .trigger(BackupTrigger.manual),
              child: const Text('Back up'),
            ),
    );
  }

  static String _ago(DateTime when) {
    final d = DateTime.now().difference(when);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays == 1) return 'yesterday';
    return '${d.inDays} days ago';
  }
}
