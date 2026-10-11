// The sage sidebar of the margo home screen: wordmark, the Notes / Favorites /
// Shared entries, then the user's folders (and tags, once they exist).
//
// The selected entry is a pill in the page-background colour cut into the sage
// panel, in both brightnesses (`bgPrimary` on `surfaceSubtle`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/icons/app_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../note_cards_provider.dart';
import 'organize_sheets.dart';

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
    final selectedTags = ref.watch(notesTagFilterProvider);
    final total = ref.watch(noteCardsProvider).value?.length ?? 0;

    final allSelected =
        !favoritesOnly &&
        folderFilter == FolderFilter.all &&
        selectedTags.isEmpty;

    void resetScope() {
      ref.read(notesFavoritesOnlyProvider.notifier).state = false;
      ref.read(notesFolderFilterProvider.notifier).state = FolderFilter.all;
      ref.read(notesTagFilterProvider.notifier).state = const {};
    }

    void choose(VoidCallback apply) {
      apply();
      onNavigate?.call();
    }

    final tagNames = tags.keys.toList()..sort();

    return DecoratedBox(
      // Light: the design's sideways shadow (8/0, blur 16). Dark: a hairline.
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        border: isDark ? Border(right: BorderSide(color: c.border)) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: c.brand.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(8, 0),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'margo',
                      style: TextStyle(
                        fontFamily: 'ModulusPro',
                        fontSize: 40,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: c.brand,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hide sidebar',
                    onPressed: onCollapse,
                    icon: AppIcon(
                      AppIcons.sidebarLeft,
                      size: 26,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _Entry(
                icon: AppIcons.noteText,
                label: 'Notes',
                selected: allSelected,
                trailing: '$total',
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
              const _Entry(
                icon: AppIcons.people,
                label: 'Shared',
                trailing: 'Soon',
                enabled: false,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Folders',
                      style: TextStyle(
                        fontFamily: 'ModulusPro',
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'New folder',
                    onPressed: () => showCreateFolderDialog(context, ref),
                    icon: AppIcon(AppIcons.addCircle, color: c.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final folder in folders)
                _Entry(
                  icon: AppIcons.folder,
                  label: folder.name,
                  small: true,
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
                const SizedBox(height: 20),
                Text(
                  'Tags',
                  style: TextStyle(
                    fontFamily: 'ModulusPro',
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final tag in tagNames)
                  _Entry(
                    label: '#$tag',
                    small: true,
                    selected: selectedTags.contains(tag),
                    trailing: '${tags[tag]}',
                    onTap: () {
                      final next = {...selectedTags};
                      next.contains(tag) ? next.remove(tag) : next.add(tag);
                      ref.read(notesTagFilterProvider.notifier).state = next;
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.label,
    this.icon,
    this.selected = false,
    this.enabled = true,
    this.small = false,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String? icon;
  final bool selected;
  final bool enabled;

  /// Folder/tag rows use the design's smaller (22) type; main entries use 24.
  final bool small;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = enabled ? c.textPrimary : c.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        child: Material(
          color: selected ? c.bgPrimary : c.surfaceSubtle.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(40),
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  if (icon != null) ...[
                    AppIcon(icon!, size: small ? 26 : 24, color: ink),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ModulusPro',
                        fontSize: small ? 20 : 22,
                        height: 1.25,
                        fontWeight: small ? FontWeight.w400 : FontWeight.w500,
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
    );
  }
}
