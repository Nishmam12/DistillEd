// Filing a note: the folder picker and the tag editor.
//
// Both are reached from the note's long-press menu and drive [HomeNotifier], so
// the home list refreshes itself once the change lands.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../suggested_terms_loader.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/note_repository.dart';
import '../../domain/folder_tree.dart';
import '../../domain/models/folder.dart';
import '../tag_colors.dart' show kTagColors;
import '../home_notifier.dart';
import '../models/note_card_data.dart';
import '../note_cards_provider.dart';

/// Moves [note] into a folder, out of one, or into a folder created on the spot.
Future<void> showMoveToFolderSheet(
  BuildContext context,
  WidgetRef ref, {
  required NoteCardData note,
}) async {
  await _moveToFolder(context, ref, {note.id}, note.folderId);
}

/// Moves several notebooks at once (multi-select). True when they were moved;
/// false when the sheet or the new-folder prompt was dismissed.
Future<bool> showMoveManyToFolderSheet(
  BuildContext context,
  WidgetRef ref, {
  required Set<int> ids,
}) =>
    _moveToFolder(context, ref, ids, null);

Future<bool> _moveToFolder(
  BuildContext context,
  WidgetRef ref,
  Set<int> ids,
  int? currentFolderId,
) async {
  final folders = await ref.read(noteRepositoryProvider).getFolders();
  if (!context.mounted) return false;

  // An explicit choice type, not a nullable int: Flutter reports a dismissed
  // sheet as null, so returning null for "No folder" would make swiping the
  // sheet away silently unfile the note.
  final choice = await showModalBottomSheet<_FolderChoice>(
    context: context,
    backgroundColor: context.colors.surface,
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
            trailing: ids.length == 1 && currentFolderId == null
                ? const Icon(Icons.check)
                : null,
            onTap: () =>
                Navigator.pop(sheetContext, const _FolderChoice.none()),
          ),
          const Divider(height: 1),
          for (final (:folder, :depth) in folderTree(folders))
            ListTile(
              contentPadding:
                  EdgeInsetsDirectional.only(start: 16 + depth * 20.0, end: 16),
              leading: _folderGlyph(folder),
              title: Text(folder.name),
              trailing:
                  ids.length == 1 && currentFolderId == folder.id
                      ? const Icon(Icons.check)
                      : null,
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
  if (choice == null || !context.mounted) return false;

  final int? target;
  switch (choice.kind) {
    case _FolderChoiceKind.none:
      target = null;
    case _FolderChoiceKind.existing:
      target = choice.folderId;
    case _FolderChoiceKind.create:
      final name = await _promptFolderName(context);
      if (name == null || !context.mounted) return false;
      target = (await ref.read(noteRepositoryProvider).createFolder(name)).id;
  }

  await ref.read(homeNotifierProvider.notifier).setFolderMany(ids, target);
  ref.invalidate(foldersProvider);
  return true;
}

/// Prompts for a name and creates a folder — the sidebar's ⊕. Returns the new
/// folder's id, or null when the prompt was dismissed or left empty.
Future<int?> showCreateFolderDialog(BuildContext context, WidgetRef ref) async {
  final name = await _promptFolderName(context);
  if (name == null || !context.mounted) return null;
  final folder = await ref.read(noteRepositoryProvider).createFolder(name);
  ref.invalidate(foldersProvider);
  return folder.id;
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

Future<String?> _promptFolderName(
  BuildContext context, {
  String title = 'New folder',
  String initial = '',
  String confirm = 'Create',
}) =>
    showDialog<String>(
      context: context,
      builder: (_) =>
          _FolderNameDialog(title: title, initial: initial, confirm: confirm),
    );

/// A folder's glyph, in its colour when it has one.
Widget _folderGlyph(Folder folder) => Icon(
      Icons.folder_outlined,
      color: folder.color == null ? null : Color(folder.color!),
    );

/// Long-press on a folder in the sidebar: rename it, add a folder inside,
/// move it, colour it, or delete it.
Future<void> showFolderActionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required Folder folder,
}) async {
  final repo = ref.read(noteRepositoryProvider);
  final folders = await repo.getFolders();
  if (!context.mounted) return;
  final parentName = folders
      .where((f) => f.id == folder.parentId)
      .map((f) => f.name)
      .firstOrNull;

  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: context.colors.surface,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(folder.name,
                style: Theme.of(sheet).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename'),
            onTap: () => Navigator.pop(sheet, 'rename'),
          ),
          if (canAddFolderIn(folders, folder.id))
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder inside'),
              onTap: () => Navigator.pop(sheet, 'add'),
            ),
          ListTile(
            leading: const Icon(Icons.drive_file_move_outline),
            title: const Text('Move to…'),
            onTap: () => Navigator.pop(sheet, 'move'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in [...kTagColors, null])
                  Semantics(
                    button: true,
                    selected: folder.color == color,
                    label: color == null ? 'No colour' : 'Colour',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(sheet, 'color:${color ?? ''}'),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color == null ? null : Color(color),
                          border: Border.all(
                            width: folder.color == color ? 3 : 1,
                            color: sheet.colors.textSecondary
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: color == null
                            ? const Icon(Icons.block, size: 16)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete folder'),
            onTap: () => Navigator.pop(sheet, 'delete'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case 'rename':
      final name = await _promptFolderName(context,
          title: 'Rename folder', initial: folder.name, confirm: 'Rename');
      if (name == null) return;
      await repo.renameFolder(folder.id, name);
    case 'add':
      final name = await _promptFolderName(context);
      if (name == null) return;
      await repo.createFolder(name, parentId: folder.id);
    case 'move':
      final target = await _pickFolderParent(context, folders, folder);
      if (target == null) return;
      await repo.moveFolder(folder.id, target.folderId);
    case 'delete':
      final where = parentName ?? 'the top level';
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Delete “${folder.name}”?'),
          content: Text('Its notes and folders move to $where. '
              'No notes are deleted.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text('Delete')),
          ],
        ),
      );
      if (ok != true) return;
      await repo.deleteFolder(folder.id);
      final filter = ref.read(notesFolderFilterProvider);
      if (filter == FolderFilter.only(folder.id)) {
        ref.read(notesFolderFilterProvider.notifier).state = FolderFilter.all;
      }
      // Notebooks were refiled, so the cards' folder ids changed too.
      await ref.read(homeNotifierProvider.notifier).loadNotebooks();
    default:
      final hex = action.substring('color:'.length);
      await repo.setFolderColor(folder.id, hex.isEmpty ? null : int.parse(hex));
  }
  ref.invalidate(foldersProvider);
}

/// Where [folder] can move: the top level or any folder [canMoveFolder]
/// allows. Null when dismissed.
Future<_FolderChoice?> _pickFolderParent(
  BuildContext context,
  List<Folder> folders,
  Folder folder,
) =>
    showModalBottomSheet<_FolderChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.vertical_align_top),
              title: const Text('Top level'),
              trailing: folder.parentId == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheet, const _FolderChoice.none()),
            ),
            const Divider(height: 1),
            for (final (folder: f, :depth) in folderTree(folders))
              ListTile(
                enabled: canMoveFolder(folders, folder.id, f.id),
                contentPadding: EdgeInsetsDirectional.only(
                    start: 16 + depth * 20.0, end: 16),
                leading: _folderGlyph(f),
                title: Text(f.name),
                trailing:
                    folder.parentId == f.id ? const Icon(Icons.check) : null,
                onTap: () =>
                    Navigator.pop(sheet, _FolderChoice.existing(f.id)),
              ),
          ],
        ),
      ),
    );

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({
    required this.title,
    required this.initial,
    required this.confirm,
  });

  final String title;
  final String initial;
  final String confirm;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.surface,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Folder name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _controller.text.trim();
            Navigator.pop(context, name.isEmpty ? null : name);
          },
          child: Text(widget.confirm),
        ),
      ],
    );
  }
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
  // From the notebook's own words; only saved if picked.
  final suggested = {
    for (final t in await suggestedTermsFor(ref, note.id))
      ...NoteRepository.normalizeTags([t]),
  };
  if (!context.mounted) return;

  final result = await showDialog<List<String>>(
    context: context,
    builder: (_) => _TagsDialog(
      initial: note.tags,
      known: known.keys.toList()..sort(),
      suggested: [
        for (final t in suggested)
          if (!known.containsKey(t)) t,
      ],
    ),
  );
  if (result == null) return;

  await ref.read(homeNotifierProvider.notifier).setTags(note.id, result);
  ref.invalidate(tagCountsProvider);
}

/// Adds tags to several notebooks at once; the tags they have are kept. True
/// when tags were added.
Future<bool> showAddTagsDialog(
  BuildContext context,
  WidgetRef ref, {
  required Set<int> ids,
}) async {
  final known = await ref.read(noteRepositoryProvider).tagCounts();
  if (!context.mounted) return false;

  final result = await showDialog<List<String>>(
    context: context,
    builder: (_) => _TagsDialog(
      initial: const [],
      known: known.keys.toList()..sort(),
      title: 'Add tags',
      confirm: 'Add',
    ),
  );
  if (result == null || result.isEmpty) return false;

  await ref.read(homeNotifierProvider.notifier).addTagsMany(ids, result);
  ref.invalidate(tagCountsProvider);
  return true;
}

class _TagsDialog extends StatefulWidget {
  final List<String> initial;
  final List<String> known;
  final String title;
  final String confirm;

  /// Tags drawn from the notebook's pages, not yet used anywhere.
  final List<String> suggested;

  const _TagsDialog({
    required this.initial,
    required this.known,
    this.suggested = const [],
    this.title = 'Tags',
    this.confirm = 'Save',
  });

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
    final fromPages = [
      for (final tag in widget.suggested)
        if (!selected.contains(tag)) tag,
    ];

    return AlertDialog(
      backgroundColor: context.colors.surface,
      title: Text(widget.title),
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
          if (fromPages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Suggested from this note',
                  style: Theme.of(context).textTheme.labelSmall),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in fromPages)
                  ActionChip(
                    key: ValueKey('suggestedTag:$tag'),
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(tag),
                    onPressed: () => _toggle(tag),
                  ),
              ],
            ),
          ],
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
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
