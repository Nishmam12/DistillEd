// Turns the raw notebook list into cards the Notes screen can render.
//
// Each card carries its note's first page so the preview is painted live from
// the same elements the editor saves — there is no thumbnail file to go stale.
// Only page one is loaded: the list shows a glance, not a document.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/model/scene_element.dart';
import '../../../editor/state/page_notifier.dart';
import '../../../editor/state/scene_controller.dart';
import '../../../editor/state/scene_image_cache_provider.dart';
import 'home_notifier.dart';
import 'models/note_card_data.dart';

final noteCardsProvider = FutureProvider<List<NoteCardData>>((ref) async {
  final notebooks = ref.watch(homeNotifierProvider);
  final pageRepository = ref.watch(pageRepositoryProvider);
  final elements = ref.watch(sceneElementStoreProvider);
  final images = ref.watch(sceneImageCacheProvider);

  final cards = <NoteCardData>[];
  for (final notebook in notebooks) {
    final pages = await pageRepository.getPagesForNotebook(notebook.id);
    final scene = pages.isEmpty
        ? const <SceneElement>[]
        : await elements.loadForPage(pages.first.id);
    cards.add(NoteCardData.fromNotebook(notebook, previewScene: scene));
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

/// Cards filtered by the search box's query and ordered by the chosen sort.
final visibleNoteCardsProvider = Provider<AsyncValue<List<NoteCardData>>>((ref) {
  final query = ref.watch(notesSearchQueryProvider);
  final sort = ref.watch(notesSortProvider);

  return ref.watch(noteCardsProvider).whenData((cards) {
    final visible = [
      for (final card in cards)
        if (card.matches(query)) card,
    ];
    return sortCards(visible, sort);
  });
});

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
