// Turns the raw notebook list into cards the Notes screen can render.
//
// Each card carries its note's first page so the preview is painted live from
// the same elements the editor saves — there is no thumbnail file to go stale.
// Only page one is loaded: the list shows a glance, not a document.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/search_providers.dart';
import '../../../domain/model/scene_element.dart';
import '../../../editor/state/page_notifier.dart';
import '../../../editor/state/scene_controller.dart';
import '../../../editor/state/scene_image_cache_provider.dart';
import '../domain/models/folder.dart';
import 'home_notifier.dart';
import 'models/note_card_data.dart';

final noteCardsProvider = FutureProvider<List<NoteCardData>>((ref) async {
  final notebooks = ref.watch(homeNotifierProvider);
  final pageRepository = ref.watch(pageRepositoryProvider);
  final elements = ref.watch(sceneElementStoreProvider);
  final images = ref.watch(sceneImageCacheProvider);
  final pageTexts = ref.watch(pageTextStoreProvider);

  final cards = <NoteCardData>[];
  for (final notebook in notebooks) {
    final pages = await pageRepository.getPagesForNotebook(notebook.id);
    final scene = pages.isEmpty
        ? const <SceneElement>[]
        : await elements.loadForPage(pages.first.id);
    // Every page's text, not just page one's: the preview only shows the first
    // few lines, but `matches()` searches the whole string, so a word written
    // on page 7 has to make the note findable from here.
    final pageOrder = {
      for (var i = 0; i < pages.length; i++) pages[i].id: i,
    };
    final texts = await pageTexts.forNotebook(notebook.id)
      ..sort((a, b) => (pageOrder[a.pageId] ?? 1 << 30)
          .compareTo(pageOrder[b.pageId] ?? 1 << 30));
    cards.add(NoteCardData.fromNotebook(
      notebook,
      previewScene: scene,
      previewText: [for (final t in texts) t.text].join('\n'),
    ));
  }

  // Decode any bitmaps the previews reference (PDF/photo imports). Fire and
  // forget: the cache notifies its listeners, and the painters repaint then.
  unawaited(images.ensure([
    for (final card in cards)
      for (final element in card.previewScene)
        if (element is ImageElement) element.relativeImagePath,
  ]));

  return cards;
});

/// How the list is ordered.
enum NotesSort {
  /// Most recently edited first — the repository's own order.
  recent('Recently edited'),
  created('Date created'),
  title('Title A–Z');

  const NotesSort(this.label);

  final String label;
}

/// Cards filtered by the search box, the folder and tag filters, then ordered
/// by the chosen sort.
final visibleNoteCardsProvider = Provider<AsyncValue<List<NoteCardData>>>((ref) {
  final query = ref.watch(notesSearchQueryProvider);
  final sort = ref.watch(notesSortProvider);
  final folder = ref.watch(notesFolderFilterProvider);
  final tags = ref.watch(notesTagFilterProvider);

  return ref.watch(noteCardsProvider).whenData((cards) {
    final visible = [
      for (final card in cards)
        if (card.matches(query) &&
            folder.accepts(card) &&
            _hasEveryTag(card, tags))
          card,
    ];
    return sortCards(visible, sort);
  });
});

/// Tag filtering is AND, not OR: picking "physics" then "exam" narrows to notes
/// carrying both, which is what stacking filters is normally taken to mean.
bool _hasEveryTag(NoteCardData card, Set<String> tags) {
  if (tags.isEmpty) return true;
  return tags.every(card.tags.contains);
}

/// Which folder the list is scoped to.
sealed class FolderFilter {
  const FolderFilter();

  /// Everything, filed or not.
  static const FolderFilter all = _AllFolders();

  /// Only notes in no folder.
  static const FolderFilter unfiled = _Unfiled();

  /// Only notes in one folder.
  const factory FolderFilter.only(int folderId) = _OneFolder;

  bool accepts(NoteCardData card);
}

class _AllFolders extends FolderFilter {
  const _AllFolders();
  @override
  bool accepts(NoteCardData card) => true;
}

class _Unfiled extends FolderFilter {
  const _Unfiled();
  @override
  bool accepts(NoteCardData card) => card.folderId == null;
}

class _OneFolder extends FolderFilter {
  final int folderId;
  const _OneFolder(this.folderId);
  @override
  bool accepts(NoteCardData card) => card.folderId == folderId;

  @override
  bool operator ==(Object other) =>
      other is _OneFolder && other.folderId == folderId;

  @override
  int get hashCode => folderId.hashCode;
}

/// Orders [cards] for display. Pinned notes always lead, whatever the sort.
List<NoteCardData> sortCards(List<NoteCardData> cards, NotesSort sort) {
  final ordered = [...cards];
  switch (sort) {
    case NotesSort.recent:
      break; // already newest-edited first
    case NotesSort.created:
      ordered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case NotesSort.title:
      ordered.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
  }
  // A stable partition, so the chosen sort still holds within each group.
  return [
    for (final card in ordered)
      if (card.pinned) card,
    for (final card in ordered)
      if (!card.pinned) card,
  ];
}

/// The live search query. Held outside the screen so a rebuild (or a rotation)
/// does not silently drop the user's filter.
final notesSearchQueryProvider = StateProvider<String>((ref) => '');

final notesSortProvider = StateProvider<NotesSort>((ref) => NotesSort.recent);

/// The folder the list is scoped to. Defaults to showing everything.
final notesFolderFilterProvider =
    StateProvider<FolderFilter>((ref) => FolderFilter.all);

/// Tags the list is filtered by (AND). Empty means no tag filter.
final notesTagFilterProvider = StateProvider<Set<String>>((ref) => const {});

/// The notebook's folders, for the folder picker and filter row.
final foldersProvider = FutureProvider<List<Folder>>((ref) async {
  // Watching the notebook list keeps folders fresh after a note is filed, and
  // after a folder is created from the file-into sheet.
  ref.watch(homeNotifierProvider);
  return ref.watch(noteRepositoryProvider).getFolders();
});

/// Every tag in use, with how many live notes carry it.
final tagCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(homeNotifierProvider);
  return ref.watch(noteRepositoryProvider).tagCounts();
});
