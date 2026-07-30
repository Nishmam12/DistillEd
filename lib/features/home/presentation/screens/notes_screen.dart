// The Notes browser — the app's home screen.
//
// Not a list and not a grid: a column of full-width document cards on a
// near-white canvas, sized so five sit on screen at once with room to breathe.
// Chrome (title, search, bottom controls) is fixed; only the cards scroll.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/ink_colors.dart';
import '../../../../domain/model/template_type.dart';
import '../../../../editor/state/scene_image_cache_provider.dart';
import '../home_notifier.dart';
import '../models/note_card_data.dart';
import '../note_cards_provider.dart';
import '../notes_palette.dart';
import '../widgets/organize_sheets.dart';
import '../widgets/note_card.dart';
import '../widgets/search_bar_widget.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  /// Height of the fixed bottom bar the list scrolls under.
  static const bottomBarHeight = 72.0;

  /// Card height that fits [targetCards] in [viewportHeight], clamped to the
  /// 150–170 band.
  ///
  /// The band wins when the two conflict. A tall viewport (tablet, desktop
  /// window) lands on a clean five; a shorter phone shows four and a generous
  /// slice of the fifth, which is the closest the band allows — squeezing cards
  /// under 150 to force a fifth is exactly the cramped list the spec rules out.
  static double cardHeightFor(double viewportHeight, {int targetCards = 5}) {
    final gaps = NotesPalette.cardGap * (targetCards - 1);
    final available = viewportHeight - NotesPalette.listPadding.top - gaps;
    return (available / targetCards)
        .clamp(NotesPalette.cardHeightMin, NotesPalette.cardHeightMax);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(visibleNoteCardsProvider);
    final query = ref.watch(notesSearchQueryProvider);

    return Scaffold(
      backgroundColor: context.notes.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                const _Header(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                  child: SearchBarWidget(
                    onChanged: (value) =>
                        ref.read(notesSearchQueryProvider.notifier).state =
                            value,
                  ),
                ),
                const _OrganizeFilterRow(),
                Expanded(
                  child: cards.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: context.notes.accent,
                      ),
                    ),
                    error: (error, _) => _Message(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load your notes',
                      subtitle: '$error',
                    ),
                    data: (visible) => visible.isEmpty
                        ? _EmptyState(query: query)
                        : _NotesList(cards: visible),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomBar(
                count: cards.valueOrNull?.length ?? 0,
                onFilter: () => _pickSort(context, ref),
                onCompose: () => _createNotebook(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNotebook(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String title, int templateIndex})>(
      context: context,
      builder: (context) => const _CreateNotebookDialog(),
    );
    if (result == null || result.title.trim().isEmpty) return;

    final notebook = await ref
        .read(homeNotifierProvider.notifier)
        .createNotebook(result.title.trim(), templateIndex: result.templateIndex);

    if (context.mounted) context.push('/note2/${notebook.id}');
  }

  Future<void> _pickSort(BuildContext context, WidgetRef ref) async {
    final current = ref.read(notesSortProvider);
    final picked = await showModalBottomSheet<NotesSort>(
      context: context,
      backgroundColor: context.notes.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.notes.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            for (final sort in NotesSort.values)
              ListTile(
                title: Text(
                  sort.label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.notes.textPrimary,
                  ),
                ),
                trailing: sort == current
                    ? Icon(Icons.check_rounded,
                        color: context.notes.accent)
                    : null,
                onTap: () => Navigator.of(context).pop(sort),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked != null) {
      ref.read(notesSortProvider.notifier).state = picked;
    }
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'DistillEd',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 38,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: context.notes.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            iconSize: 26,
            color: context.notes.accent,
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({required this.cards});

  final List<NoteCardData> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(sceneImageCacheProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = NotesScreen.cardHeightFor(constraints.maxHeight);
        return ListView.separated(
          padding: NotesPalette.listPadding,
          itemCount: cards.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: NotesPalette.cardGap),
          itemBuilder: (context, index) {
            final note = cards[index];
            return SizedBox(
              height: cardHeight,
              child: NoteCard(
                key: ValueKey(note.id),
                note: note,
                sceneImageResolver: images.get,
                sceneRepaint: images,
                onTap: () => context.push('/note2/${note.id}'),
                onGraphTap: () => context.push('/note2/${note.id}/graph'),
                onLongPress: () => _showActions(context, ref, note),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    NoteCardData note,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.notes.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(note.pinned
                  ? Icons.push_pin
                  : Icons.push_pin_outlined),
              title: Text(note.pinned ? 'Unpin' : 'Pin to top'),
              onTap: () => Navigator.of(context).pop('pin'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Move to folder…'),
              onTap: () => Navigator.of(context).pop('folder'),
            ),
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('Tags…'),
              subtitle:
                  note.tags.isEmpty ? null : Text(note.tags.join(', ')),
              onTap: () => Navigator.of(context).pop('tags'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: const Text('Open in book view'),
              onTap: () => Navigator.of(context).pop('book'),
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('Knowledge graph'),
              onTap: () => Navigator.of(context).pop('graph'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: context.ink.accentRed),
              title: Text(
                'Delete note',
                style: TextStyle(color: context.ink.accentRed),
              ),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    switch (action) {
      case 'pin':
        await ref
            .read(homeNotifierProvider.notifier)
            .setPinned(note.id, !note.pinned);
      case 'folder':
        await showMoveToFolderSheet(context, ref, note: note);
      case 'tags':
        await showEditTagsDialog(context, ref, note: note);
      case 'book':
        context.push('/note2/${note.id}/book');
      case 'graph':
        context.push('/note2/${note.id}/graph');
      case 'delete':
        await _confirmDelete(context, ref, note);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    NoteCardData note,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.notes.card,
        title: const Text('Move to trash'),
        content: Text(
          'Move "${note.title}" to the trash? '
          'You can restore it for the next 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.ink.accentRed,
            ),
            child: const Text('Move to trash'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(homeNotifierProvider.notifier).deleteNotebook(note.id);
    if (!context.mounted) return;

    // Undo right where the action happened — the trash is the safety net, but
    // an immediate undo is what an accidental tap actually wants.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Moved "${note.title}" to trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref
              .read(homeNotifierProvider.notifier)
              .restoreNotebook(note.id),
        ),
      ),
    );
  }
}

/// Folder and tag filters. Hidden entirely until the user has made at least one
/// folder or tag, so a fresh install is not asked to reason about organisation
/// it has not created yet.
class _OrganizeFilterRow extends ConsumerWidget {
  const _OrganizeFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider).valueOrNull ?? const [];
    final tags = ref.watch(tagCountsProvider).valueOrNull ?? const {};
    if (folders.isEmpty && tags.isEmpty) return const SizedBox.shrink();

    final folderFilter = ref.watch(notesFolderFilterProvider);
    final selectedTags = ref.watch(notesTagFilterProvider);
    final tagNames = tags.keys.toList()..sort();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        children: [
          _FilterChip(
            label: 'All',
            selected: folderFilter == FolderFilter.all,
            onTap: () => ref.read(notesFolderFilterProvider.notifier).state =
                FolderFilter.all,
          ),
          for (final folder in folders)
            _FilterChip(
              label: folder.name,
              icon: Icons.folder_outlined,
              selected: folderFilter == FolderFilter.only(folder.id),
              onTap: () => ref.read(notesFolderFilterProvider.notifier).state =
                  folderFilter == FolderFilter.only(folder.id)
                      ? FolderFilter.all
                      : FolderFilter.only(folder.id),
            ),
          if (folders.isNotEmpty)
            _FilterChip(
              label: 'Unfiled',
              selected: folderFilter == FolderFilter.unfiled,
              onTap: () => ref.read(notesFolderFilterProvider.notifier).state =
                  folderFilter == FolderFilter.unfiled
                      ? FolderFilter.all
                      : FolderFilter.unfiled,
            ),
          for (final tag in tagNames)
            _FilterChip(
              label: '#$tag',
              selected: selectedTags.contains(tag),
              onTap: () {
                final next = {...selectedTags};
                next.contains(tag) ? next.remove(tag) : next.add(tag);
                ref.read(notesTagFilterProvider.notifier).state = next;
              },
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? context.ink.accentWash : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? context.ink.accent : context.ink.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: context.notes.textSecondary),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected
                      ? context.ink.accent
                      : context.notes.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.count,
    required this.onFilter,
    required this.onCompose,
  });

  final int count;
  final VoidCallback onFilter;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    // Frosted, not opaque: cards sliding under it stay faintly present, the way
    // an iOS toolbar behaves — but blurred enough that its own labels win.
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: NotesScreen.bottomBarHeight + safeBottom,
          padding: EdgeInsets.only(left: 18, right: 18, bottom: safeBottom),
          decoration: BoxDecoration(
            color: context.notes.background.withValues(alpha: 0.86),
            // Themed rather than a fixed black wash: a 8%-black hairline is
            // invisible against a dark canvas.
            border: Border(
              top: BorderSide(
                color: context.notes.textSecondary.withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Row(
            children: [
              _BarButton(
                icon: Icons.tune_rounded,
                tooltip: 'Sort notes',
                onPressed: onFilter,
              ),
              Expanded(
                child: Text(
                  '$count ${count == 1 ? 'Note' : 'Notes'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.notes.textSecondary,
                  ),
                ),
              ),
              _BarButton(
                icon: Icons.edit_square,
                tooltip: 'New note',
                onPressed: onCompose,
                filled: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? context.notes.accent : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Semantics(
            button: true,
            label: tooltip,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                icon,
                size: 22,
                color: filled ? Colors.white : context.notes.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.trim().isNotEmpty) {
      return _Message(
        icon: Icons.search_off_rounded,
        title: 'No notes match "${query.trim()}"',
        subtitle: 'Try a different search.',
      );
    }
    return const _Message(
      icon: Icons.note_add_outlined,
      title: 'No notes yet',
      subtitle: 'Tap the compose button to start your first note.',
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.notes.textSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.notes.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: context.notes.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateNotebookDialog extends StatefulWidget {
  const _CreateNotebookDialog();

  @override
  State<_CreateNotebookDialog> createState() => _CreateNotebookDialogState();
}

class _CreateNotebookDialogState extends State<_CreateNotebookDialog> {
  final _controller = TextEditingController();
  int _selectedTemplate = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop((
      title: _controller.text,
      templateIndex: _selectedTemplate,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.notes.card,
      title: const Text('New note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Note title'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          Text(
            'Page style',
            style: TextStyle(
              color: context.notes.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in TemplateType.values)
                _TemplateChip(
                  type: type,
                  selected: type.index == _selectedTemplate,
                  onTap: () => setState(() => _selectedTemplate = type.index),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final TemplateType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour =
        selected ? context.notes.accent : context.notes.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? context.notes.accent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? context.notes.accent
                : context.notes.textSecondary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.iconData, size: 16, color: colour),
            const SizedBox(width: 6),
            Text(
              type.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: colour,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
