import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/persistence/library_repository.dart';
import '../../domain/model/template_type.dart';
import '../../data/persistence/scene_element_store.dart';
import '../../domain/model/element_id.dart';
import '../../domain/services/selection_editing.dart';
import '../../features/home/data/repositories/page_repository.dart';
import '../../features/home/domain/models/note_page.dart';
import '../../shared/isar/isar_service.dart';
import 'history_controller.dart';
import 'library_controller.dart';
import 'scene_controller.dart';

/// [NotePage.templateOverride] for a page that follows its notebook's template.
const int kNotebookTemplate = -1;

/// The paper [page] is drawn on: its own template if it has one, otherwise
/// the notebook's.
TemplateType templateForPage(NotePage page, TemplateType notebookTemplate) {
  final i = page.templateOverride;
  return i >= 0 && i < TemplateType.values.length
      ? TemplateType.values[i]
      : notebookTemplate;
}

class PageState {
  final int currentPageIndex;
  final List<NotePage> pages;

  const PageState({required this.currentPageIndex, required this.pages});

  PageState copyWith({int? currentPageIndex, List<NotePage>? pages}) {
    return PageState(
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      pages: pages ?? this.pages,
    );
  }
}

class PageNotifier extends StateNotifier<PageState> {
  final PageRepository _repository;
  final SceneElementStore _store;
  final int _notebookId;
  final void Function(int pageId)? _onPageDeleted;

  PageNotifier(
    this._repository,
    this._store,
    this._notebookId, {
    this._onPageDeleted,
  }) : super(const PageState(currentPageIndex: 0, pages: []));

  Future<void> initialize() async {
    List<NotePage> pages = await _repository.getPagesForNotebook(_notebookId);
    if (pages.isEmpty) {
      final newPage = await _repository.createPage(_notebookId);
      pages = [newPage];
    }
    // Re-initializing (Book view opens over a live editor) must keep the page
    // the user is on.
    state = PageState(
      currentPageIndex: state.currentPageIndex.clamp(0, pages.length - 1),
      pages: pages,
    );
  }

  /// Drops the scene and undo state of every page of this notebook. Call when
  /// the editor closes: those providers live for the whole session otherwise.
  void release() {
    for (final p in state.pages) {
      _onPageDeleted?.call(p.id);
    }
  }

  void switchPage(int index) {
    if (index >= 0 && index < state.pages.length) {
      state = state.copyWith(currentPageIndex: index);
    }
  }

  Future<void> insertPage() async {
    await _repository.createPage(_notebookId);
    final pages = await _repository.getPagesForNotebook(_notebookId);
    state = PageState(currentPageIndex: pages.length - 1, pages: pages);
  }

  Future<void> deletePage(int index) async {
    if (state.pages.length <= 1) return;
    if (index < 0 || index >= state.pages.length) return;

    // Capture the page's own id before the row goes away — the scene elements
    // are keyed by pageId, and deleting only the NotePage row would strand them
    // in the store forever.
    final deletedPageId = state.pages[index].id;

    // Queued writes for this page would otherwise land after the clear and
    // leave orphan rows behind.
    await SceneController.flushPage(deletedPageId);
    await _repository.deletePage(_notebookId, index);
    await _store.clearForPage(deletedPageId);
    _onPageDeleted?.call(deletedPageId);
    final pages = await _repository.getPagesForNotebook(_notebookId);

    int newIndex = state.currentPageIndex;
    if (state.currentPageIndex == index) {
      newIndex = index > 0 ? index - 1 : 0;
    } else if (state.currentPageIndex > index) {
      newIndex--;
    }

    state = PageState(currentPageIndex: newIndex, pages: pages);
  }

  /// Copies the page at [index] — metadata *and* its scene content — and puts
  /// the copy immediately after the original.
  ///
  /// Element ids must be re-minted: the store keys elements by id, so reusing
  /// the source ids would make the copy overwrite the original rather than sit
  /// beside it. [SelectionEditing.duplicate] also remaps group ids, so grouped
  /// elements stay grouped within the copy without merging into the source's
  /// groups.
  Future<void> duplicatePage(int index) async {
    if (index < 0 || index >= state.pages.length) return;
    // Read only after the source page's pending edits have landed.
    await SceneController.flushPage(state.pages[index].id);
    final sourceElements = await _store.loadForPage(state.pages[index].id);

    final source = state.pages[index];
    final created = await _repository.createPage(_notebookId);
    final pages = await _repository.getPagesForNotebook(_notebookId);

    // Move the newly created page to immediately after the duplicated page
    await _repository.movePage(_notebookId, pages.length - 1, index + 1);
    if (source.bookmarked ||
        source.title.isNotEmpty ||
        source.templateOverride != kNotebookTemplate) {
      await _repository.setPageInfo(
        created.id,
        bookmarked: source.bookmarked,
        title: source.title,
        templateOverride: source.templateOverride,
      );
    }

    if (sourceElements.isNotEmpty) {
      await _store.upsertForPage(
        _notebookId,
        created.id,
        SelectionEditing.duplicate(
          sourceElements,
          offset: Offset.zero,
          nextId: newElementId,
        ),
      );
    }

    final updatedPages = await _repository.getPagesForNotebook(_notebookId);
    state = PageState(currentPageIndex: index + 1, pages: updatedPages);
  }

  /// Moves [pageIds] (in their current relative order) to sit right after the
  /// page at [afterIndex], and opens the first of them. How an import lands
  /// after the page the user was on: pages are created at the end and then
  /// moved here in one reorder.
  Future<void> movePagesAfter(List<int> pageIds,
      {required int afterIndex}) async {
    if (pageIds.isEmpty) return;
    final moving = pageIds.toSet();
    final ids = [for (final p in state.pages) p.id];
    final rest = [for (final id in ids) if (!moving.contains(id)) id];
    final kept = [for (final id in ids) if (moving.contains(id)) id];
    final at = (afterIndex + 1).clamp(0, rest.length);
    final order = [...rest.take(at), ...kept, ...rest.skip(at)];

    await _repository.reorderPages(_notebookId, order);
    final pages = await _repository.getPagesForNotebook(_notebookId);
    state = PageState(currentPageIndex: at, pages: pages);
  }

  /// The order of [ids] after the pages in [moving] (kept in their current
  /// relative order) are lifted out and dropped so the first of them sits at
  /// [toIndex] of the result. [toIndex] is clamped to the pages that remain.
  static List<int> orderAfterMove(
      List<int> ids, Set<int> moving, int toIndex) {
    final rest = [for (final id in ids) if (!moving.contains(id)) id];
    final kept = [for (final id in ids) if (moving.contains(id)) id];
    final at = toIndex.clamp(0, rest.length);
    return [...rest.take(at), ...kept, ...rest.skip(at)];
  }

  /// Moves [pageIds] together so the first of them lands at [toIndex], in one
  /// write. The page being edited stays the current page.
  Future<void> movePages(List<int> pageIds, int toIndex) async {
    if (pageIds.isEmpty) return;
    final ids = [for (final p in state.pages) p.id];
    final order = orderAfterMove(ids, pageIds.toSet(), toIndex);
    if (order.indexed.every((e) => ids[e.$1] == e.$2)) return;
    final currentId = state.pages[state.currentPageIndex].id;
    await _repository.reorderPages(_notebookId, order);
    final pages = await _repository.getPagesForNotebook(_notebookId);
    final at = pages.indexWhere((p) => p.id == currentId);
    state = PageState(currentPageIndex: at < 0 ? 0 : at, pages: pages);
  }

  /// Deletes [pageIds] and their content. Refuses (returns false) when that
  /// would leave the notebook with no page.
  Future<bool> deletePages(List<int> pageIds) async {
    final doomed = pageIds.toSet();
    final indexes = [
      for (var i = 0; i < state.pages.length; i++)
        if (doomed.contains(state.pages[i].id)) i,
    ];
    if (indexes.isEmpty || indexes.length >= state.pages.length) return false;
    // Highest first, so the lower indexes are still valid after each delete.
    for (final i in indexes.reversed) {
      await deletePage(i);
    }
    return true;
  }

  /// Copies each of [pageIds] to sit right after its original.
  Future<void> duplicatePages(List<int> pageIds) async {
    final wanted = pageIds.toSet();
    final indexes = [
      for (var i = 0; i < state.pages.length; i++)
        if (wanted.contains(state.pages[i].id)) i,
    ];
    final currentId = state.pages[state.currentPageIndex].id;
    for (final i in indexes.reversed) {
      await duplicatePage(i);
    }
    final at = state.pages.indexWhere((p) => p.id == currentId);
    state = state.copyWith(currentPageIndex: at < 0 ? 0 : at);
  }

  Future<void> _setInfo(
    int pageId, {
    bool? bookmarked,
    String? title,
    int? templateOverride,
  }) async {
    await _repository.setPageInfo(
      pageId,
      bookmarked: bookmarked,
      title: title,
      templateOverride: templateOverride,
    );
    final pages = await _repository.getPagesForNotebook(_notebookId);
    state = state.copyWith(pages: pages);
  }

  Future<void> setBookmarked(int pageId, bool on) =>
      _setInfo(pageId, bookmarked: on);

  /// Bookmarks every page in [pageIds] if any of them is not bookmarked yet,
  /// otherwise clears them all (one tap toggles a mixed selection on).
  Future<void> toggleBookmarks(List<int> pageIds) async {
    final wanted = pageIds.toSet();
    final chosen = state.pages.where((p) => wanted.contains(p.id)).toList();
    if (chosen.isEmpty) return;
    final on = chosen.any((p) => !p.bookmarked);
    for (final p in chosen) {
      await _repository.setPageInfo(p.id, bookmarked: on);
    }
    final pages = await _repository.getPagesForNotebook(_notebookId);
    state = state.copyWith(pages: pages);
  }

  Future<void> renamePage(int pageId, String title) =>
      _setInfo(pageId, title: title);

  /// Gives one page its own template, or [kNotebookTemplate] to follow the
  /// notebook again.
  Future<void> setPageTemplate(int pageId, int templateIndex) =>
      _setInfo(pageId, templateOverride: templateIndex);

  Future<void> reorderPages(int oldIndex, int newIndex) async {
    await _repository.movePage(_notebookId, oldIndex, newIndex);
    final pages = await _repository.getPagesForNotebook(_notebookId);

    int current = state.currentPageIndex;
    if (current == oldIndex) {
      current = newIndex;
    } else if (current > oldIndex && current <= newIndex) {
      current--;
    } else if (current >= newIndex && current < oldIndex) {
      current++;
    }

    state = PageState(currentPageIndex: current, pages: pages);
  }
}

final pageProvider = StateNotifierProvider.family<PageNotifier, PageState, int>((
  ref,
  notebookId,
) {
  final repository = ref.watch(pageRepositoryProvider);
  final store = ref.watch(sceneElementStoreProvider);
  return PageNotifier(
    repository,
    store,
    notebookId,
    onPageDeleted: (pageId) {
      // The deleted page's scene and undo stack would otherwise stay in memory
      // (and keep a live write queue) for the rest of the session.
      final key = (notebookId: notebookId, pageId: pageId);
      ref.invalidate(historyProvider(key));
      ref.invalidate(sceneControllerProvider(key));
    },
  );
});

final pageRepositoryProvider = Provider<PageRepository>((ref) {
  return PageRepository(
    IsarService.instance,
    libraryImages: () =>
        libraryImagePaths(ref.read(libraryRepositoryProvider)),
  );
});
