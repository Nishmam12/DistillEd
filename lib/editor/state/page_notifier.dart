import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/persistence/scene_element_store.dart';
import '../../domain/model/element_id.dart';
import '../../domain/services/selection_editing.dart';
import '../../features/home/data/repositories/page_repository.dart';
import '../../features/home/domain/models/note_page.dart';
import '../../shared/isar/isar_service.dart';
import 'scene_controller.dart';

class PageState {
  final int currentPageIndex;
  final List<NotePage> pages;

  const PageState({
    required this.currentPageIndex,
    required this.pages,
  });

  PageState copyWith({
    int? currentPageIndex,
    List<NotePage>? pages,
  }) {
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

  PageNotifier(this._repository, this._store, this._notebookId)
      : super(const PageState(currentPageIndex: 0, pages: []));

  Future<void> initialize() async {
    List<NotePage> pages = await _repository.getPagesForNotebook(_notebookId);
    if (pages.isEmpty) {
      final newPage = await _repository.createPage(_notebookId);
      pages = [newPage];
    }
    state = PageState(currentPageIndex: 0, pages: pages);
  }

  void switchPage(int index) {
    if (index >= 0 && index < state.pages.length) {
      state = state.copyWith(currentPageIndex: index);
    }
  }

  Future<void> insertPage() async {
    await _repository.createPage(_notebookId);
    final pages = await _repository.getPagesForNotebook(_notebookId);
    state = PageState(
      currentPageIndex: pages.length - 1,
      pages: pages,
    );
  }

  Future<void> deletePage(int index) async {
    if (state.pages.length <= 1) return;
    if (index < 0 || index >= state.pages.length) return;

    // Capture the page's own id before the row goes away — the scene elements
    // are keyed by pageId, and deleting only the NotePage row would strand them
    // in the store forever.
    final deletedPageId = state.pages[index].id;

    await _repository.deletePage(_notebookId, index);
    await _store.clearForPage(deletedPageId);
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
    final sourceElements = await _store.loadForPage(state.pages[index].id);

    final created = await _repository.createPage(_notebookId);
    final pages = await _repository.getPagesForNotebook(_notebookId);

    // Move the newly created page to immediately after the duplicated page
    await _repository.movePage(_notebookId, pages.length - 1, index + 1);

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
    state = PageState(
      currentPageIndex: index + 1,
      pages: updatedPages,
    );
  }

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

final pageProvider = StateNotifierProvider.family<PageNotifier, PageState, int>((ref, notebookId) {
  final repository = ref.watch(pageRepositoryProvider);
  final store = ref.watch(sceneElementStoreProvider);
  return PageNotifier(repository, store, notebookId);
});

final pageRepositoryProvider = Provider<PageRepository>((ref) {
  return PageRepository(IsarService.instance);
});
