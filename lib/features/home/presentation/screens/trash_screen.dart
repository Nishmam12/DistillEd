// The trash: notebooks deleted from the home screen, restorable until their
// retention window runs out. This is the only place a note is erased for good.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/repositories/note_repository.dart';
import '../../domain/models/notebook.dart';
import '../home_notifier.dart';
import '../notes_palette.dart';
import '../trash_notifier.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashed = ref.watch(trashNotifierProvider);

    return Scaffold(
      backgroundColor: NotesPalette.background,
      appBar: AppBar(
        backgroundColor: NotesPalette.background,
        title: const Text('Trash'),
        actions: [
          if (trashed.isNotEmpty)
            TextButton(
              onPressed: () => _confirmEmpty(context, ref, trashed.length),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentRed,
              ),
              child: const Text('Empty'),
            ),
        ],
      ),
      body: trashed.isEmpty
          ? const _EmptyTrash()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: trashed.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _TrashRow(notebook: trashed[i]),
            ),
    );
  }

  Future<void> _confirmEmpty(
      BuildContext context, WidgetRef ref, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NotesPalette.card,
        title: const Text('Empty trash'),
        content: Text(
          'Permanently delete $count ${count == 1 ? 'note' : 'notes'}? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentRed),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(trashNotifierProvider.notifier).emptyTrash();
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline,
              size: 48, color: NotesPalette.textSecondary),
          const SizedBox(height: 12),
          const Text(
            'Trash is empty',
            style: TextStyle(
              fontSize: 16,
              color: NotesPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Deleted notes stay here for '
            '${NoteRepository.trashRetention.inDays} days',
            style: TextStyle(
              fontSize: 13,
              color: NotesPalette.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrashRow extends ConsumerWidget {
  final Notebook notebook;

  const _TrashRow({required this.notebook});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = TrashNotifier.daysUntilPurge(notebook);

    return ListTile(
      title: Text(
        notebook.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: NotesPalette.textPrimary),
      ),
      subtitle: Text(
        days == 0
            ? 'Deletes today'
            : 'Deletes in $days ${days == 1 ? 'day' : 'days'}',
        style: const TextStyle(
            color: NotesPalette.textSecondary, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Restore',
            icon: const Icon(Icons.restore_from_trash_outlined),
            onPressed: () => _restore(context, ref),
          ),
          IconButton(
            tooltip: 'Delete forever',
            icon: const Icon(Icons.delete_forever_outlined),
            color: AppColors.accentRed,
            onPressed: () => _confirmDeleteForever(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(trashNotifierProvider.notifier).restore(notebook.id);
    // The home list is already built and would otherwise not show the note
    // again until it happened to reload.
    await ref.read(homeNotifierProvider.notifier).loadNotebooks();
    messenger.showSnackBar(
      SnackBar(content: Text('Restored "${notebook.title}"')),
    );
  }

  Future<void> _confirmDeleteForever(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NotesPalette.card,
        title: const Text('Delete forever'),
        content: Text(
          'Permanently delete "${notebook.title}" and everything in it? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentRed),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(trashNotifierProvider.notifier).deleteForever(notebook.id);
  }
}
