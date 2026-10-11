// The Notes browser — the app's home screen (margo design).
//
// A sage sidebar (Notes / Favorites / Shared, folders) beside a grid of note
// cards. On a tablet-class width the sidebar is pinned and can be collapsed;
// below the expanded window size (840 dp) it opens as a drawer instead.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:distill_ed/core/icons/phosphor_icons_regular.dart';

import '../../../../core/icons/app_icon.dart';
import '../../../../core/layout/window_size.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../editor/state/scene_image_cache_provider.dart';
import '../home_notifier.dart';
import '../models/note_card_data.dart';
import '../note_cards_provider.dart';
import '../notes_palette.dart';
import '../widgets/home_sidebar.dart';
import '../widgets/new_note_dialog.dart';
import '../widgets/note_card.dart';
import '../widgets/organize_sheets.dart';
import '../widgets/search_popover.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Whether the pinned sidebar is showing (wide layouts only).
  bool _sidebarOpen = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cards = ref.watch(visibleNoteCardsProvider);
    final windowWidth = MediaQuery.sizeOf(context).width;
    final wide = context.windowSize.isExpanded;
    final sidebarWidth = NotesPalette.sidebarWidthFor(windowWidth);

    final main = _Main(
      cards: cards,
      showMenu: !wide || !_sidebarOpen,
      onMenu: () {
        if (wide) {
          setState(() => _sidebarOpen = true);
        } else {
          _scaffoldKey.currentState?.openDrawer();
        }
      },
      onSort: () => _pickSort(context, ref),
      onCompose: () => _createNotebook(context, ref),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: c.bgPrimary,
      drawer: wide
          ? null
          : Drawer(
              width: sidebarWidth,
              backgroundColor: c.surfaceSubtle,
              shape: const RoundedRectangleBorder(),
              child: HomeSidebar(
                onCollapse: () => Navigator.of(context).pop(),
                onNavigate: () => Navigator.of(context).pop(),
              ),
            ),
      body: Row(
        children: [
          if (wide && _sidebarOpen)
            SizedBox(
              width: sidebarWidth,
              child: HomeSidebar(
                onCollapse: () => setState(() => _sidebarOpen = false),
              ),
            ),
          Expanded(child: SafeArea(bottom: false, child: main)),
        ],
      ),
    );
  }

  Future<void> _createNotebook(BuildContext context, WidgetRef ref) async {
    final result = await showNewNoteDialog(context);
    if (result == null || result.title.trim().isEmpty) return;

    final notebook = await ref
        .read(homeNotifierProvider.notifier)
        .createNotebook(
          result.title.trim(),
          templateIndex: result.templateIndex,
          backgroundColor: result.backgroundColor,
        );

    if (context.mounted) unawaited(context.push('/note2/${notebook.id}'));
  }

  Future<void> _pickSort(BuildContext context, WidgetRef ref) async {
    final current = ref.read(notesSortProvider);
    final picked = await showModalBottomSheet<NotesSort>(
      context: context,
      backgroundColor: context.colors.surface,
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
                color: context.colors.textSecondary.withValues(alpha: 0.3),
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
                    color: context.colors.textPrimary,
                  ),
                ),
                trailing: sort == current
                    ? Icon(Icons.check_rounded, color: context.colors.accent)
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

/// Title, chrome icons, sort row and the grid.
class _Main extends ConsumerWidget {
  const _Main({
    required this.cards,
    required this.showMenu,
    required this.onMenu,
    required this.onSort,
    required this.onCompose,
  });

  final AsyncValue<List<NoteCardData>> cards;
  final bool showMenu;
  final VoidCallback onMenu;
  final VoidCallback onSort;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final sort = ref.watch(notesSortProvider);
    final favoritesOnly = ref.watch(notesFavoritesOnlyProvider);
    final folder = ref.watch(notesFolderFilterProvider);
    final folders = ref.watch(foldersProvider).value ?? const [];

    final title = favoritesOnly
        ? 'Favorites'
        : folder == FolderFilter.unfiled
        ? 'Unfiled'
        : [
                for (final f in folders)
                  if (folder == FolderFilter.only(f.id)) f.name,
              ].firstOrNull ??
              'Notes';

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 20, 24, 0),
              child: Row(
                children: [
                  if (showMenu)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip: 'Show sidebar',
                        onPressed: onMenu,
                        icon: const AppIcon(AppIcons.sidebarLeft, size: 28),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ModulusPro',
                        fontSize: 40,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  SearchPopoverButton(
                    onOpenNote: (note) => context.push('/note2/${note.id}'),
                  ),
                  IconButton(
                    tooltip: 'About',
                    onPressed: () => context.push('/about'),
                    icon: const AppIcon(AppIcons.profile, size: 30),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                    icon: const AppIcon(AppIcons.setting, size: 30),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 4, 32, 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onSort,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            sort.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'ModulusPro',
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const AppIcon(AppIcons.sort),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: cards.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: c.accent)),
                error: (error, _) => _Message(
                  icon: PhosphorIconsRegular.warningCircle,
                  title: 'Could not load your notes',
                  subtitle: '$error',
                ),
                data: (visible) => visible.isEmpty
                    ? _EmptyState(favoritesOnly: favoritesOnly)
                    : _NotesGrid(cards: visible),
              ),
            ),
          ],
        ),
        Positioned(
          right: 32,
          bottom: 28,
          child: _NewButton(onPressed: onCompose),
        ),
      ],
    );
  }
}

/// The floating "+ new" pill.
class _NewButton extends StatelessWidget {
  const _NewButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'New note',
      child: Material(
        color: c.accent,
        elevation: isDark ? 0 : 6,
        shadowColor: c.brand.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+',
                  style: TextStyle(
                    fontFamily: 'ModulusPro',
                    fontSize: 26,
                    height: 1.2,
                    color: c.onAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'new',
                  style: TextStyle(
                    fontFamily: 'ModulusPro',
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: c.onAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesGrid extends ConsumerWidget {
  const _NotesGrid({required this.cards});

  final List<NoteCardData> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(sceneImageCacheProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = context.windowSize.isCompact;
        final padding = compact
            ? NotesPalette.compactContentPadding
            : NotesPalette.contentPadding;
        final gap = compact ? NotesPalette.compactGap : NotesPalette.gridGap;
        final available = constraints.maxWidth - padding.horizontal;
        final columns = ((available + gap) / (NotesPalette.cardMinWidth + gap))
            .floor()
            .clamp(1, 12);

        // Fixed-height tiles: the thumbnail keeps the design's 252:198 ratio at
        // whatever width the column ends up, and the footer grows with the
        // system font size so large text is never clipped.
        final tileWidth = (available - gap * (columns - 1)) / columns;
        final tileHeight =
            tileWidth * NotesPalette.thumbnailAspect +
            NoteCard.footerHeightFor(MediaQuery.textScalerOf(context));

        return GridView.builder(
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: tileHeight,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final note = cards[index];
            return NoteCard(
              key: ValueKey(note.id),
              note: note,
              sceneImageResolver: images.get,
              sceneRepaint: images,
              onTap: () => context.push('/note2/${note.id}'),
              onGraphTap: () => context.push('/note2/${note.id}/graph'),
              onLongPress: () => _showActions(context, ref, note),
              onToggleFavorite: () => ref
                  .read(homeNotifierProvider.notifier)
                  .setPinned(note.id, !note.pinned),
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
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
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
              subtitle: note.tags.isEmpty ? null : Text(note.tags.join(', ')),
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
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete note',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        unawaited(context.push('/note2/${note.id}/book'));
      case 'graph':
        unawaited(context.push('/note2/${note.id}/graph'));
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
        backgroundColor: context.colors.surface,
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
              foregroundColor: Theme.of(context).colorScheme.error,
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
          onPressed: () =>
              ref.read(homeNotifierProvider.notifier).restoreNotebook(note.id),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.favoritesOnly});

  final bool favoritesOnly;

  @override
  Widget build(BuildContext context) {
    // Two distinct empty states: nothing starred yet, and nothing in this scope.
    if (favoritesOnly) {
      return const _Message(
        icon: PhosphorIconsRegular.notePencil,
        title: 'No favorites yet',
        subtitle: 'Tap the bookmark on a note to keep it here.',
      );
    }
    return const _Message(
      icon: PhosphorIconsRegular.notePencil,
      title: 'No notes here',
      subtitle: 'Tap "+ new" to start a note.',
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
    final c = context.colors;
    // HOME-15. Derived from the tokens, since the mockup has no empty state:
    // the glyph sits in a large `surfaceSubtle` disc so the screen has SOME
    // shape at zero notes rather than three lines floating on a bare scaffold,
    // and it is `accent` because there is exactly one — the same single-instance
    // rule the search icon and meta glyphs follow. The heading takes
    // `textPrimary` and the guidance line `textSecondary`, matching every other
    // title/description pair in the app.
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: c.accent),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                height: 1.4,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
