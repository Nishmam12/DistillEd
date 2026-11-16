// The bar shown while notebooks are selected on the home grid: how many, Select
// all, and what can be done to them together.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../home_notifier.dart';
import '../models/note_card_data.dart';
import '../notes_selection.dart';
import 'organize_sheets.dart';

class SelectionBar extends ConsumerWidget {
  const SelectionBar({
    super.key,
    required this.visible,
    this.padding = EdgeInsets.zero,
  });

  /// The notebooks on screen, for Select all.
  final List<NoteCardData> visible;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final selected = ref.watch(notesSelectionProvider);
    final all = visible.isNotEmpty && visible.every((n) => selected.contains(n.id));
    final anyUnpinned = visible.any((n) => selected.contains(n.id) && !n.pinned);
    // Five icon buttons and a text button need about 320 dp.
    final compact = MediaQuery.sizeOf(context).width < 520;

    void clear() => ref.read(notesSelectionProvider.notifier).state = const {};
    Future<void> pin() async {
      await _run(ref, (home, ids) => home.setPinnedMany(ids, anyUnpinned));
    }

    Future<void> move() async {
      if (await showMoveManyToFolderSheet(context, ref, ids: {...selected})) {
        clear();
      }
    }

    Future<void> tag() async {
      if (await showAddTagsDialog(context, ref, ids: {...selected})) clear();
    }

    return Padding(
      padding:
          EdgeInsets.only(left: padding.left, right: padding.right, bottom: 8),
      child: Material(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('selectionDone'),
                tooltip: 'Done',
                icon: const Icon(Icons.close_rounded),
                onPressed: () =>
                    ref.read(notesSelectionProvider.notifier).state = const {},
              ),
              Flexible(
                child: Text('${selected.length} selected',
                    key: const ValueKey('selectionCount'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'ModulusPro',
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
              ),
              const Spacer(),
              TextButton(
                key: const ValueKey('selectAll'),
                onPressed: () => ref.read(notesSelectionProvider.notifier).state =
                    all ? const {} : {for (final n in visible) n.id},
                child: Text(all ? 'None' : 'All'),
              ),
              if (!compact) ...[
                IconButton(
                  key: const ValueKey('selectionPin'),
                  tooltip: anyUnpinned ? 'Pin' : 'Unpin',
                  icon: Icon(
                      anyUnpinned ? Icons.push_pin_outlined : Icons.push_pin),
                  onPressed: pin,
                ),
                IconButton(
                  key: const ValueKey('selectionFolder'),
                  tooltip: 'Move to folder',
                  icon: const Icon(Icons.folder_outlined),
                  onPressed: move,
                ),
                IconButton(
                  key: const ValueKey('selectionTags'),
                  tooltip: 'Add tags',
                  icon: const Icon(Icons.label_outline),
                  onPressed: tag,
                ),
              ] else
                // Narrow windows: the three filing actions share one menu.
                PopupMenuButton<String>(
                  key: const ValueKey('selectionMore'),
                  tooltip: 'More',
                  onSelected: (v) => switch (v) {
                    'pin' => pin(),
                    'folder' => move(),
                    _ => tag(),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'pin', child: Text(anyUnpinned ? 'Pin' : 'Unpin')),
                    const PopupMenuItem(
                        value: 'folder', child: Text('Move to folder')),
                    const PopupMenuItem(value: 'tags', child: Text('Add tags')),
                  ],
                ),
              IconButton(
                key: const ValueKey('selectionDelete'),
                tooltip: 'Move to trash',
                icon: Icon(Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error),
                onPressed: () => _confirmDelete(context, ref, {...selected}),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _run(WidgetRef ref,
      Future<void> Function(HomeNotifier home, Set<int> ids) action) async {
    final ids = {...ref.read(notesSelectionProvider)};
    await action(ref.read(homeNotifierProvider.notifier), ids);
    ref.read(notesSelectionProvider.notifier).state = const {};
  }

  static Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Set<int> ids) async {
    final home = ref.read(homeNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final n = ids.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        title: const Text('Move to trash'),
        content: Text('Move $n notebook${n == 1 ? '' : 's'} to the trash? '
            'You can restore ${n == 1 ? 'it' : 'them'} for the next 30 days.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            key: const ValueKey('confirmTrashMany'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Move to trash'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await home.deleteMany(ids);
    ref.read(notesSelectionProvider.notifier).state = const {};
    messenger.showSnackBar(SnackBar(
      content: Text('Moved $n notebook${n == 1 ? '' : 's'} to trash'),
      action:
          SnackBarAction(label: 'Undo', onPressed: () => home.restoreMany(ids)),
    ));
  }
}
