// Filing a note: the folder picker and the tag editor.
//
// Both are reached from the note's long-press menu and drive [HomeNotifier], so
// the home list refreshes itself once the change lands.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/ink_colors.dart';
import '../../data/repositories/note_repository.dart';
import '../home_notifier.dart';
import '../models/note_card_data.dart';
import '../note_cards_provider.dart';

/// Moves [note] into a folder, out of one, or into a folder created on the spot.
Future<void> showMoveToFolderSheet(
  BuildContext context,
  WidgetRef ref, {
  required NoteCardData note,
}) async {
  final folders = await ref.read(noteRepositoryProvider).getFolders();
  if (!context.mounted) return;

  // An explicit choice type, not a nullable int: Flutter reports a dismissed
  // sheet as null, so returning null for "No folder" would make swiping the
  // sheet away silently unfile the note.
  final choice = await showModalBottomSheet<_FolderChoice>(
    context: context,
    backgroundColor: context.notes.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: const Text('No folder'),
            trailing: note.folderId == null ? const Icon(Icons.check) : null,
            onTap: () =>
                Navigator.pop(sheetContext, const _FolderChoice.none()),
          ),
          const Divider(height: 1),
          for (final folder in folders)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(folder.name),
              trailing:
                  note.folderId == folder.id ? const Icon(Icons.check) : null,
              onTap: () =>
                  Navigator.pop(sheetContext, _FolderChoice.existing(folder.id)),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('New folder…'),
            onTap: () =>
                Navigator.pop(sheetContext, const _FolderChoice.create()),
          ),
        ],
      ),
    ),
  );

  // null here means the sheet was dismissed — leave the note where it is.
  if (choice == null || !context.mounted) return;

  final int? target;
  switch (choice.kind) {
    case _FolderChoiceKind.none:
      target = null;
    case _FolderChoiceKind.existing:
      target = choice.folderId;
    case _FolderChoiceKind.create:
      final name = await _promptFolderName(context);
      if (name == null || !context.mounted) return;
      target = (await ref.read(noteRepositoryProvider).createFolder(name)).id;
  }

  await ref.read(homeNotifierProvider.notifier).setFolder(note.id, target);
  ref.invalidate(foldersProvider);
}

enum _FolderChoiceKind { none, existing, create }

/// What the folder sheet was closed with. Distinct from `null`, which means the
/// sheet was dismissed without choosing.
class _FolderChoice {
  final _FolderChoiceKind kind;
  final int? folderId;

  const _FolderChoice.none()
      : kind = _FolderChoiceKind.none,
        folderId = null;
  const _FolderChoice.create()
      : kind = _FolderChoiceKind.create,
        folderId = null;
  const _FolderChoice.existing(int id)
      : kind = _FolderChoiceKind.existing,
        folderId = id;
}

Future<String?> _promptFolderName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: context.notes.card,
      title: const Text('New folder'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Folder name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = controller.text.trim();
            Navigator.pop(dialogContext, name.isEmpty ? null : name);
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

/// Edits [note]'s tags as a comma-separated list.
///
/// Free text rather than a picker: tags are meant to be applied retroactively
/// and invented on the spot, and a picker would make a new tag the slow path.
/// Existing tags are offered as chips so the vocabulary still converges.
Future<void> showEditTagsDialog(
  BuildContext context,
  WidgetRef ref, {
  required NoteCardData note,
}) async {
  final known = await ref.read(noteRepositoryProvider).tagCounts();
  if (!context.mounted) return;

  final result = await showDialog<List<String>>(
    context: context,
    builder: (_) => _TagsDialog(
      initial: note.tags,
      known: known.keys.toList()..sort(),
    ),
  );
  if (result == null) return;

  await ref.read(homeNotifierProvider.notifier).setTags(note.id, result);
  ref.invalidate(tagCountsProvider);
}

class _TagsDialog extends StatefulWidget {
  final List<String> initial;
  final List<String> known;

  const _TagsDialog({required this.initial, required this.known});

  @override
  State<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends State<_TagsDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial.join(', '));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Set<String> get _current =>
      NoteRepository.normalizeTags(_controller.text.split(',')).toSet();

  void _toggle(String tag) {
    final next = _current;
    next.contains(tag) ? next.remove(tag) : next.add(tag);
    final ordered = next.toList()..sort();
    setState(() => _controller.text = ordered.join(', '));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _current;
    final suggestions = [
      for (final tag in widget.known)
        if (!selected.contains(tag)) tag,
    ];

    return AlertDialog(
      backgroundColor: context.notes.card,
      title: const Text('Tags'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'physics, exam, week 3',
              helperText: 'Separate with commas',
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Existing tags',
                  style: Theme.of(context).textTheme.labelSmall),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in suggestions)
                  ActionChip(
                    label: Text(tag),
                    onPressed: () => _toggle(tag),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _current.toList()..sort()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
