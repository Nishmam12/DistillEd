// Persistence boundary for unified scene elements.
//
// The abstraction lets the migrator and SceneController be unit-tested with an
// in-memory implementation (no native Isar), while production uses
// [IsarSceneElementStore].

import '../../domain/model/scene_element.dart';

abstract class SceneElementStore {
  /// All elements on [pageId], ordered by zOrder ascending.
  Future<List<SceneElement>> loadForPage(int pageId);

  /// Inserts or replaces [elements] on a page, keyed by element id. Idempotent:
  /// re-running with the same elements does not create duplicates.
  Future<void> upsertForPage(
    int notebookId,
    int pageId,
    List<SceneElement> elements,
  );

  /// Removes every element on [pageId].
  Future<void> clearForPage(int pageId);

  /// Removes the elements with [elementIds] from [pageId], atomically.
  Future<void> deleteElements(int pageId, Set<String> elementIds);

  /// Makes [elements] the whole content of [pageId] in ONE transaction, so a
  /// crash can never leave the page cleared but not yet rewritten.
  Future<void> replaceForPage(
    int notebookId,
    int pageId,
    List<SceneElement> elements,
  );
}

/// In-memory store for tests and migration without a live database.
class InMemorySceneElementStore implements SceneElementStore {
  // pageId → (elementId → element)
  final Map<int, Map<String, SceneElement>> _byPage = {};

  @override
  Future<List<SceneElement>> loadForPage(int pageId) async {
    final page = _byPage[pageId];
    if (page == null) return [];
    final list = page.values.toList()
      ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    return list;
  }

  @override
  Future<void> upsertForPage(
    int notebookId,
    int pageId,
    List<SceneElement> elements,
  ) async {
    final page = _byPage.putIfAbsent(pageId, () => {});
    for (final e in elements) {
      page[e.id] = e; // keyed by element id → idempotent
    }
  }

  @override
  Future<void> clearForPage(int pageId) async {
    _byPage.remove(pageId);
  }

  @override
  Future<void> deleteElements(int pageId, Set<String> elementIds) async {
    _byPage[pageId]?.removeWhere((id, _) => elementIds.contains(id));
  }

  @override
  Future<void> replaceForPage(
    int notebookId,
    int pageId,
    List<SceneElement> elements,
  ) async {
    _byPage[pageId] = {for (final e in elements) e.id: e};
  }
}
