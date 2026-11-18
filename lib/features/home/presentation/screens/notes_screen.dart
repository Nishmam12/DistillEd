// The Notes browser — the app's home screen (margo design).
//
// A sage sidebar (Notes / Favorites / Shared, folders) beside a grid of note
// cards. On a tablet-class width the sidebar is pinned and can be collapsed;
// below the expanded window size (840 dp) it opens as a drawer instead.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:margo/core/icons/phosphor_icons_regular.dart';

import '../../../../core/icons/app_icon.dart';
import '../../../../core/layout/window_size.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../editor/state/scene_image_cache_provider.dart';
import '../hidden_notes.dart';
import '../home_notifier.dart';
import '../models/note_card_data.dart';
import '../note_cards_provider.dart';
import '../notes_palette.dart';
import '../notes_selection.dart';
import '../recent_notebooks.dart';
import '../widgets/home_sidebar.dart';
import '../widgets/new_note_dialog.dart';
import '../widgets/note_card.dart';
import '../widgets/organize_sheets.dart';
import '../widgets/recent_strip.dart';
import '../widgets/today_strip.dart';
import '../study_today_providers.dart';
import '../widgets/selection_bar.dart';
import '../widgets/search_popover.dart';
import '../widgets/sort_filter_sheet.dart';

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
    // A selection belongs to the view it was made in: another folder, the
    // favourites, a tag or a search starts again, and a notebook that leaves
    // the view (trashed, filtered out) leaves the selection.
    void clearSelection(Object? _, Object? _) =>
        ref.read(notesSelectionProvider.notifier).state = const {};
    ref.listen(notesFolderFilterProvider, clearSelection);
    ref.listen(notesFavoritesOnlyProvider, clearSelection);
    ref.listen(notesTagFilterProvider, clearSelection);
    ref.listen(notesSearchQueryProvider, clearSelection);
    ref.listen(visibleNoteCardsProvider, (_, next) {
      final selected = ref.read(notesSelectionProvider);
      final shown = next.value;
      if (selected.isEmpty || shown == null) return;
      final keep = {
        for (final n in shown)
          if (selected.contains(n.id)) n.id,
      };
      if (keep.length != selected.length) {
        ref.read(notesSelectionProvider.notifier).state = keep;
      }
    });
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
      // The pinned sidebar panel stops at the system bars (the design's sage
      // rectangle runs from under the status bar to above the nav bar); the
      // grid scrolls on under the nav bar.
      body: Row(
        children: [
          if (wide && _sidebarOpen)
            SafeArea(
              right: false,
              child: SizedBox(
                width: sidebarWidth,
                child: HomeSidebar(
                  onCollapse: () => setState(() => _sidebarOpen = false),
                ),
              ),
            ),
          Expanded(
            child: SafeArea(
              left: !(wide && _sidebarOpen),
              bottom: false,
              child: main,
            ),
          ),
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

    if (context.mounted) _openNotebook(context, ref, notebook.id);
  }

  Future<void> _pickSort(BuildContext context, WidgetRef ref) =>
      showSortFilterSheet(context);
}

/// Opens notebook [id] in the editor and remembers it for the Recent strip.
///
/// With [page] (0-based) the editor opens on that page, and with [query] it
/// tints the matching words there.
void _openNotebook(BuildContext context, WidgetRef ref, int id,
    {int? page, String? query}) {
  unawaited(ref.read(recentNotebooksProvider.notifier).record(id));
  final args = [
    if (page != null) 'page=$page',
    if (query != null && query.isNotEmpty) 'q=${Uri.encodeQueryComponent(query)}',
  ];
  // Cards reviewed or a plan changed inside: Today reads them again after.
  final container = ProviderScope.containerOf(context, listen: false);
  unawaited(context
      .push('/note2/$id${args.isEmpty ? '' : '?${args.join('&')}'}')
      .then((_) => container.invalidate(studyNotebooksProvider)));
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
    // The Recent strip only belongs on the plain, unfiltered list.
    final plain = folder == FolderFilter.all &&
        !favoritesOnly &&
        !ref.watch(notesHiddenViewProvider) &&
        ref.watch(notesSearchQueryProvider).trim().isEmpty &&
        ref.watch(notesTagFilterProvider).isEmpty &&
        !ref.watch(notesMoreFiltersProvider).isActive;
    final selecting = ref.watch(notesSelectionProvider).isNotEmpty;
    final recents = !plain || selecting
        ? const <NoteCardData>[]
        : recentCards(ref.watch(noteCardsProvider).value ?? const [],
            ref.watch(recentNotebooksProvider));

    final title = ref.watch(notesHiddenViewProvider)
        ? 'Hidden'
        : favoritesOnly
        ? 'Favorites'
        : folder == FolderFilter.unfiled
        ? 'Unfiled'
        : [
                for (final f in folders)
                  if (folder == FolderFilter.only(f.id)) f.name,
              ].firstOrNull ??
              'Notes';

    // Design geometry (1280×800 frame, below the status bar): the three 36px
    // chrome icons hang 28 from the top, 17 apart, flush with the grid's right
    // edge; the 42px title starts 27 lower, beside them; the sort row (icon
    // first, then the label) sits 26 under the icons, and the grid 24 under it.
    // Each icon's 48dp tap target overhangs the glyph by `inset`.
    final compact = context.windowSize.isCompact;
    final pad = compact
        ? NotesPalette.compactContentPadding
        : NotesPalette.contentPadding;
    final inset = AppIconButton.insetFor(36);
    const iconGap = 17.0;
    final titleSize = compact ? 34.0 : 42.0;

    final menu = AppIconButton(
      AppIcons.sidebarLeft,
      size: 28,
      tooltip: 'Show sidebar',
      onPressed: onMenu,
    );
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'ModulusPro',
        fontSize: titleSize,
        height: 1.17,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
    );
    final icons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SearchPopoverButton(
          onOpenNote: (note) => _openNotebook(context, ref, note.id),
          onOpenHit: (hit, query) => _openNotebook(context, ref, hit.notebookId,
              page: hit.hit.pageIndex, query: query),
        ),
        SizedBox(width: iconGap - inset * 2),
        AppIconButton(
          AppIcons.profile,
          size: 36,
          tooltip: 'About',
          onPressed: () => context.push('/about'),
        ),
        SizedBox(width: iconGap - inset * 2),
        AppIconButton(
          AppIcons.setting,
          size: 36,
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
    final sortButton = _SortButton(
        label: ref.watch(notesMoreFiltersProvider).isActive
            ? '${sort.label} · filtered'
            : sort.label,
        onTap: onSort);

    // Back leaves select mode first.
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(notesSelectionProvider.notifier).state = const {};
      },
      child: Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact)
              // Phones: menu and icons on one row, the title and sort below —
              // side by side they would not fit a 320dp screen.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pad.left - (showMenu ? AppIconButton.insetFor(28) : 0),
                  16 - inset,
                  pad.right - inset,
                  0,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (showMenu) menu,
                        const Spacer(),
                        icons,
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: showMenu ? AppIconButton.insetFor(28) : 0,
                        right: inset - _SortButton.padding,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: titleText),
                          const SizedBox(width: 8),
                          Flexible(child: sortButton),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pad.left,
                  28 - inset,
                  pad.right - inset,
                  0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showMenu)
                      Padding(
                        // Centred on the title line, not the icon row.
                        padding: EdgeInsets.only(
                          right: 8,
                          top: inset + 27 + titleSize * 1.17 / 2 - 26,
                        ),
                        child: menu,
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: inset + 27),
                        child: titleText,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        icons,
                        Padding(
                          padding: EdgeInsets.only(
                            top: 26 - inset - _SortButton.padding,
                            right: inset - _SortButton.padding,
                          ),
                          child: sortButton,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24 - _SortButton.padding),
            if (selecting)
              SelectionBar(visible: cards.value ?? const [], padding: pad),
            // Today and Recent scroll in at most half the room when space is
            // short (a phone, or the keyboard up for the scratch pad).
            if ((plain && !selecting) || recents.isNotEmpty)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (plain && !selecting) TodayStrip(padding: pad),
                      if (recents.isNotEmpty)
                        RecentStrip(
                          notes: recents,
                          padding: pad,
                          onOpen: (note) =>
                              _openNotebook(context, ref, note.id),
                        ),
                    ],
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
        // 36 from the right edge, 18 above the nav bar.
        Positioned(
          right: compact ? 20 : 36,
          bottom: 18 + MediaQuery.paddingOf(context).bottom,
          child: _NewButton(onPressed: onCompose),
        ),
      ],
    ));
  }
}

/// Sort glyph then the current order's label, right-aligned under the icons.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  /// Tap padding around the row; callers offset by it to keep design spacing.
  static const padding = 6.0;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIcons.sort),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'ModulusPro',
                  fontSize: 20,
                  height: 1.17,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The floating "+ new" pill: the accent, slightly see-through.
///
/// It used to be frosted glass. A backdrop blur that sits over a scrolling
/// list is recomputed on every frame of the scroll, so it is a tint now.
class _NewButton extends StatelessWidget {
  const _NewButton({required this.onPressed});

  final VoidCallback onPressed;

  static const _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The design is #4F6B5A at 50% over a blur. Without the blur, half
    // strength lets card text show through the white label, so it is denser.
    // Light sage under a white label would wash out in dark, so dark uses the
    // deep field green with the cream ink instead.
    final fill = isDark
        ? c.fieldFill.withValues(alpha: 0.92)
        : c.accent.withValues(alpha: 0.88);
    final ink = isDark ? c.textPrimary : c.onAccent;
    final style = TextStyle(
      fontFamily: 'ModulusPro',
      fontSize: 24,
      height: 1.17,
      fontWeight: FontWeight.w500,
      color: ink,
    );

    return Semantics(
      button: true,
      label: 'New note',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: _radius,
        child: Material(
          color: fill,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(21, 7, 16, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('+', style: style),
                  const SizedBox(width: 4),
                  Text('new', style: style),
                ],
              ),
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
    final selection = ref.watch(notesSelectionProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = context.windowSize.isCompact;
        final padding = compact
            ? NotesPalette.compactContentPadding
            : NotesPalette.contentPadding;
        final gap = compact
            ? NotesPalette.compactGap
            : NotesPalette.gridColumnGap;
        final rowGap = compact
            ? NotesPalette.compactGap
            : NotesPalette.gridRowGap;
        final available = constraints.maxWidth - padding.horizontal;

        // Aim for the design's 252-wide cards (three across at 1280), rounding
        // to the nearest column count but never squeezing a card under the
        // minimum width.
        int columns = ((available + gap) / (NotesPalette.cardWidth + gap))
            .round()
            .clamp(1, 12);
        double widthAt(int n) => (available - gap * (n - 1)) / n;
        while (columns > 1 && widthAt(columns) < NotesPalette.cardMinWidth) {
          columns--;
        }

        // Fixed-height tiles: the thumbnail keeps the design's 252:198 ratio at
        // whatever width the column ends up, and the footer grows with the
        // system font size so large text is never clipped.
        final tileWidth = widthAt(columns);
        final tileHeight =
            tileWidth * NotesPalette.thumbnailAspect +
            NoteCard.footerHeightFor(MediaQuery.textScalerOf(context));

        return GridView.builder(
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: rowGap,
            crossAxisSpacing: gap,
            mainAxisExtent: tileHeight,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final note = cards[index];
            final picking = selection.isNotEmpty;
            void toggle() =>
                ref.read(notesSelectionProvider.notifier).toggle(note.id);
            return Stack(
              key: ValueKey(note.id),
              children: [
                Positioned.fill(
                  child: NoteCard(
                    note: note,
                    sceneImageResolver: images.get,
                    sceneRepaint: images,
                    onTap: picking
                        ? toggle
                        : () => _openNotebook(context, ref, note.id),
                    // The design's cards carry no graph button; the knowledge
                    // graph is in the long-press sheet.
                    onLongPress: picking
                        ? toggle
                        : () => _showActions(context, ref, note),
                    onToggleFavorite: () => ref
                        .read(homeNotifierProvider.notifier)
                        .setPinned(note.id, !note.pinned),
                  ),
                ),
                if (selection.contains(note.id))
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: ValueKey('picked:${note.id}'),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: context.colors.accent, width: 3),
                          color: context.colors.accent.withValues(alpha: 0.12),
                        ),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.check_circle,
                                color: context.colors.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
        // Scrolls on a short (landscape) screen rather than overflowing.
        child: SingleChildScrollView(
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
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Select'),
              onTap: () => Navigator.of(context).pop('select'),
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
            ListTile(
              leading: Icon(note.hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              title: Text(note.hidden ? 'Stop hiding' : 'Hide note'),
              onTap: () => Navigator.of(context).pop('hide'),
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
      ),
    );
    if (!context.mounted || action == null) return;

    switch (action) {
      case 'select':
        ref.read(notesSelectionProvider.notifier).state = {note.id};
      case 'pin':
        await ref
            .read(homeNotifierProvider.notifier)
            .setPinned(note.id, !note.pinned);
      case 'folder':
        await showMoveToFolderSheet(context, ref, note: note);
      case 'tags':
        await showEditTagsDialog(context, ref, note: note);
      case 'hide':
        await setNotesHidden(context, ref, {note.id}, hidden: !note.hidden);
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

    final home = ref.read(homeNotifierProvider.notifier);
    await home.deleteNotebook(note.id);
    if (!context.mounted) return;

    // Undo right where the action happened — the trash is the safety net, but
    // an immediate undo is what an accidental tap actually wants.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Moved "${note.title}" to trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => home.restoreNotebook(note.id),
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
                fontFamily: 'ModulusPro',
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
                fontFamily: 'ModulusPro',
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
