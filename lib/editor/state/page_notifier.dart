import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/data/repositories/page_repository.dart';
import '../../features/home/domain/models/note_page.dart';
import '../../shared/isar/isar_service.dart';

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
  final int _notebookId;

  PageNotifier(this._repository, this._notebookId)
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
    
    await _repository.deletePage(_notebookId, index);
    final pages = await _repository.getPagesForNotebook(_notebookId);
    
    int newIndex = state.currentPageIndex;
    if (state.currentPageIndex == index) {
      newIndex = index > 0 ? index - 1 : 0;
    } else if (state.currentPageIndex > index) {
      newIndex--;
    }
    
    state = PageState(currentPageIndex: newIndex, pages: pages);
  }

  Future<void> duplicatePage(int index) async {
    // Note: This duplicates the metadata. To duplicate the strokes,
    // the UI/orchestrator will need to coordinate copying the .ink file.
    await _repository.createPage(_notebookId);
    final pages = await _repository.getPagesForNotebook(_notebookId);
    
    // Move the newly created page to immediately after the duplicated page
    await _repository.movePage(_notebookId, pages.length - 1, index + 1);
    
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
  return PageNotifier(repository, notebookId);
});

final pageRepositoryProvider = Provider<PageRepository>((ref) {
  return PageRepository(IsarService.instance);
});
