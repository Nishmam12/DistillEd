// The sage sidebar of the margo home screen: wordmark, the Notes / Favorites /
// Shared entries, then the user's folders (nested) and tags.
//
// The selected entry is a 232-wide pill in the page-background colour cut
// into the sage panel, in both brightnesses (`bgPrimary` on `surfaceSubtle`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/icons/app_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../note_cards_provider.dart';
import '../notes_palette.dart';
import 'organize_sheets.dart';
import '../../domain/folder_tree.dart';
import '../../domain/tag_tree.dart';
import '../hidden_notes.dart';
import '../home_notifier.dart' show homeNotifierProvider;
import '../tag_colors.dart';

class HomeSidebar extends ConsumerWidget {
  const HomeSidebar({super.key, required this.onCollapse, this.onNavigate});

  /// The panel-collapse glyph beside the wordmark.
  final VoidCallback onCollapse;

  /// Called after an entry is chosen, so a drawer can close itself.
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favoritesOnly = ref.watch(notesFavoritesOnlyProvider);
    final folderFilter = ref.watch(notesFolderFilterProvider);
    final folders = ref.watch(foldersProvider).value ?? const [];
    final tags = ref.watch(tagCountsProvider).value ?? const <String, int>{};
    final tagColors = ref.watch(tagColorsProvider);
    final selectedTags = ref.watch(notesTagFilterProvider);

    final allSelected =
        !ref.watch(notesHiddenViewProvider) &&
        !favoritesOnly &&
        folderFilter == FolderFilter.all &&
        selectedTags.isEmpty;

    final hiddenView = ref.watch(notesHiddenViewProvider);
    final anyHidden =
        ref.watch(noteCardsProvider).value?.any((c) => c.hidden) ?? false;

    void resetScope() {
      ref.read(notesHiddenViewProvider.notifier).state = false;
      ref.read(notesFavoritesOnlyProvider.notifier).state = false;
      ref.read(notesFolderFilterProvider.notifier).state = FolderFilter.all;
      ref.read(notesTagFilterProvider.notifier).state = const {};
    }

    void choose(VoidCallback apply) {
      apply();
      onNavigate?.call();
    }

    final tagNames = tags.keys.toList()..sort();

    // Design geometry (350-wide panel): wordmark 29 in and 32 down, the
    // collapse glyph 19 from the right edge; entry pills 22 in, 232 wide, 37
    // tall, 55 apart; "Folders" 24 under the last entry with the add glyph 17
    // from the edge; folder rows indented a further 12.
    return DecoratedBox(
      // Light: the design's sideways black shadow (25%, 8/0, blur 16).
      // Dark: a hairline.
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        border: isDark ? Border(right: BorderSide(color: c.border)) : null,
        boxShadow: isDark
            ? null
            : [
                const BoxShadow(
                  color: NotesPalette.shadowColor,
                  blurRadius: 16,
                  offset: Offset(8, 0),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 32, 7, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Text(
                        'margo',
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'ModulusPro',
                          fontSize: 46,
                          height: 1.17,
                          fontWeight: FontWeight.w600,
                          color: c.brand,
                        ),
                      ),
                    ),
                  ),
                  AppIconButton(
                    AppIcons.sidebarLeft,
                    size: 28,
                    tooltip: 'Hide sidebar',
                    onPressed: onCollapse,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _Entry(
                icon: AppIcons.noteText,
                label: 'Notes',
                selected: allSelected,
                onTap: () => choose(resetScope),
              ),
              _Entry(
                icon: AppIcons.bookmark,
                label: 'Favorites',
                selected: favoritesOnly,
                onTap: () => choose(() {
                  resetScope();
                  ref.read(notesFavoritesOnlyProvider.notifier).state = true;
                }),
              ),
              // Only once something is hidden; opening it asks the device.
              if (anyHidden || hiddenView)
                _Entry(
                  icon: AppIcons.lock,
                  label: 'Hidden',
                  selected: hiddenView,
                  onTap: () async {
                    if (!await unlockHidden(context, ref)) return;
                    choose(() {
                      resetScope();
                      ref.read(notesHiddenViewProvider.notifier).state = true;
                    });
                  },
                ),
              // Drawn like its siblings, as in the design; sharing isn't built
              // yet, so a tap says so instead of doing nothing.
              _Entry(
                icon: AppIcons.people,
                label: 'Shared',
                onTap: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Shared notes are coming soon')),
                  ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Text(
                        'Folders',
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'ModulusPro',
                          fontSize: 28,
                          height: 1.17,
                          fontWeight: FontWeight.w500,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  AppIconButton(
                    AppIcons.addCircle,
                    tooltip: 'New folder',
                    onPressed: () => showCreateFolderDialog(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Nested; long-press for rename, colour, move and delete.
              for (final (:folder, :depth) in folderTree(folders))
                _Entry(
                  icon: AppIcons.folder,
                  iconColor: switch (folder.color) {
                    final v? => Color(v),
                    null => null,
                  },
                  label: folder.name,
                  small: true,
                  depth: depth,
                  onLongPress: () =>
                      showFolderActionsSheet(context, ref, folder: folder),
                  selected:
                      !favoritesOnly &&
                      folderFilter == FolderFilter.only(folder.id),
                  onTap: () => choose(() {
                    final already =
                        !favoritesOnly &&
                        folderFilter == FolderFilter.only(folder.id);
                    resetScope();
                    if (!already) {
                      ref.read(notesFolderFilterProvider.notifier).state =
                          FolderFilter.only(folder.id);
                    }
                  }),
                ),
              if (folders.isNotEmpty)
                _Entry(
                  icon: AppIcons.folder,
                  label: 'Unfiled',
                  small: true,
                  selected:
                      !favoritesOnly && folderFilter == FolderFilter.unfiled,
                  onTap: () => choose(() {
                    final already =
                        !favoritesOnly && folderFilter == FolderFilter.unfiled;
                    resetScope();
                    if (!already) {
                      ref.read(notesFolderFilterProvider.notifier).state =
                          FolderFilter.unfiled;
                    }
                  }),
                ),
              if (tagNames.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Text(
                    'Tags',
                    style: TextStyle(
                      fontFamily: 'ModulusPro',
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Nested: `physics/optics` under `physics`. Long-press to
                // colour a tag.
                for (final node in tagTree(
                    [
                  for (final n in ref.watch(homeNotifierProvider))
                    if (!n.hidden) n.tags,
                ]))
                  _Entry(
                    label: '#${node.label}',
                    small: true,
                    depth: node.depth,
                    dot: switch (tagColors[node.path]) {
                      final v? => Color(v),
                      null => null,
                    },
                    selected: selectedTags.contains(node.path),
                    trailing: '${node.notes}',
                    onTap: () {
                      final next = {...selectedTags};
                      next.contains(node.path)
                          ? next.remove(node.path)
                          : next.add(node.path);
                      ref.read(notesTagFilterProvider.notifier).state = next;
                    },
                    onLongPress: () => _pickTagColor(context, ref, node.path),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Long-press on a tag: a colour for it, or none.
Future<void> _pickTagColor(BuildContext context, WidgetRef ref, String tag) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Colour for #$tag'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final color in [...kTagColors, null])
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        ref.read(tagColorsProvider.notifier).set(tag, color);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color == null ? null : Color(color),
                          border: Border.all(
                              color: context.colors.textSecondary
                                  .withValues(alpha: 0.4)),
                        ),
                        child: color == null
                            ? const Icon(Icons.block, size: 18)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

class _Entry extends StatelessWidget {
  const _Entry({
    required this.label,
    this.icon,
    this.selected = false,
    this.small = false,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.depth = 0,
    this.dot,
    this.iconColor,
  });

  /// A folder's colour, for its glyph.
  final Color? iconColor;

  final String label;
  final String? icon;
  final bool selected;

  /// Nesting level of a tag or folder under its parent; each step indents.
  final int depth;

  /// A tag's colour, shown as a dot before it.
  final Color? dot;
  final VoidCallback? onLongPress;

  /// Folder/tag rows: 26px glyph indented a further 12, 22 Regular type.
  /// Main entries: 24px glyph, 24 Medium type.
  final bool small;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = c.textPrimary;
    final glyph = small ? 26.0 : 24.0;

    // A 37-tall pill (at normal text size), at most 232 wide; the glyph is
    // vertically centred and 11 from the label.
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: NotesPalette.sidebarPillWidth,
          ),
          child: Semantics(
            button: true,
            selected: selected,
            child: Material(
              color: selected
                  ? c.bgPrimary
                  : c.surfaceSubtle.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(40),
              child: InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: onTap,
                onLongPress: onLongPress,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 37),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        (small ? 23 : 11) + depth * 18.0, 2, 12, 2),
                    child: Row(
                      children: [
                        if (dot != null) ...[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: dot, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (icon != null) ...[
                          AppIcon(icon!, size: glyph, color: iconColor ?? ink),
                          const SizedBox(width: 11),
                        ],
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'ModulusPro',
                              fontSize: small ? 22 : 24,
                              height: 1.17,
                              fontWeight: small
                                  ? FontWeight.w400
                                  : FontWeight.w500,
                              color: ink,
                            ),
                          ),
                        ),
                        if (trailing != null)
                          Text(
                            trailing!,
                            style: TextStyle(
                              fontFamily: 'ModulusPro',
                              fontSize: 13,
                              color: c.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
