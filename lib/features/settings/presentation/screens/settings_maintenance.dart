part of 'settings_screen.dart';

/// Offers to reclaim model files sitting on disk that no installed model
/// claims — see [ModelStorageCleaner] for how they come about.
///
/// Renders NOTHING when there is nothing to reclaim, which is the normal case.
/// A permanently-visible "0 B to free" row would be noise in a settings screen,
/// and this is a recovery affordance, not a feature.
class _ReclaimSpaceRow extends ConsumerStatefulWidget {
  /// Called after a cleanup so the parent re-queries every model row — freeing
  /// space can change what is installed.
  final VoidCallback onChanged;

  const _ReclaimSpaceRow({super.key, required this.onChanged});

  @override
  ConsumerState<_ReclaimSpaceRow> createState() => _ReclaimSpaceRowState();
}

class _ReclaimSpaceRowState extends ConsumerState<_ReclaimSpaceRow> {
  /// Cached for the same reason as the model rows': this is a directory scan
  /// behind a platform channel, not something to re-run on every rebuild.
  late Future<List<OrphanedModelFile>> _orphans = _findOrphans();

  bool _busy = false;
  String? _error;

  Future<List<OrphanedModelFile>> _findOrphans() =>
      ref.read(modelStorageCleanerProvider).findOrphans();

  Future<void> _cleanup(List<OrphanedModelFile> orphans) async {
    final freed = orphans.fold<int>(0, (sum, o) => sum + o.sizeBytes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Free up space?'),
        content: Text(
          '${orphans.length} leftover file${orphans.length == 1 ? '' : 's'} '
          '(${_formatBytes(freed)}) will be deleted. These are remnants of '
          'downloads that did not finish — the models you have installed are '
          'not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(modelStorageCleanerProvider).cleanup();
      if (!mounted) return;
      // A block, not an arrow, for the same reason as _refreshInstalled.
      setState(() {
        _orphans = _findOrphans();
      });
      widget.onChanged();
    } on LlmException catch (e) {
      // Includes the refuse-to-delete guard, whose message is the whole point
      // of it firing — surface it rather than silently doing nothing.
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't free up space. Try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _formatBytes(int bytes) {
    const mb = 1024 * 1024;
    if (bytes >= 1024 * mb) {
      return '${(bytes / (1024 * mb)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / mb).round()} MB';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OrphanedModelFile>>(
      future: _orphans,
      builder: (context, snapshot) {
        final orphans = snapshot.data ?? const <OrphanedModelFile>[];
        // Stay invisible until there is genuinely something to offer. A failed
        // scan returns empty too, which is the right silence: we have nothing
        // useful to say and nothing safe to do.
        if (orphans.isEmpty && _error == null) return const SizedBox.shrink();

        final freed = orphans.fold<int>(0, (sum, o) => sum + o.sizeBytes);
        return _SettingsRow(
          icon: PhosphorIconsRegular.broom,
          title: 'Leftover download files',
          subtitle: _error ??
              '${_formatBytes(freed)} from downloads that did not finish',
          trailing: _busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed:
                      orphans.isEmpty ? null : () => _cleanup(orphans),
                  child: const Text('Free up'),
                ),
        );
      },
    );
  }
}

/// The shadow re-index's progress while a rollout runs (docs/TECH_MIGRATION_PLAN.md,
/// phase 4.5), with Continue and Cancel. Empty when no rollout is running.
class _RolloutRow extends ConsumerWidget {
  const _RolloutRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rollout = ref.watch(embedderRolloutStatusProvider).value;
    if (rollout == null || !rollout.isRunning) return const SizedBox.shrink();
    final runner = ref.read(embedderRolloutRunnerProvider);
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    // A transparent Material gives the tile its ink over the card's background.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        key: const ValueKey('rollout-progress'),
        title: Text(
          'Upgrading search model: ${rollout.indexedPages} of '
          '${rollout.totalPages} pages',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              key: const ValueKey('rollout-continue'),
              onPressed: runner.isAdvancing
                  ? null
                  : () => _advanceRollout(
                      container, messenger, rollout.servingModelId),
              child: const Text('Continue'),
            ),
            TextButton(
              key: const ValueKey('rollout-cancel'),
              // Offered only when no pass runs here: a pass saves its own state
              // after each step, which would overwrite a cancel made during one.
              onPressed: runner.isAdvancing
                  ? null
                  : () async {
                      await runner.cancel(rollout.servingModelId);
                      container.invalidate(embedderRolloutStatusProvider);
                    },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Runs the rollout from its saved state until it is idle, or until a step fails.
/// A failure is shown, and the saved state lets the next press resume it.
Future<void> _advanceRollout(
  ProviderContainer container,
  ScaffoldMessengerState messenger,
  String servingModelId,
) async {
  try {
    await container.read(embedderRolloutRunnerProvider).advance(servingModelId);
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Search model upgrade stopped. Press Continue to resume.')));
  } finally {
    container.invalidate(embedderRolloutStatusProvider);
  }
}
