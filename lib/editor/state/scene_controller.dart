// Holds the unified scene (ordered [SceneElement]s) for one page and persists
// mutations through a [SceneElementStore].
//
// Foundation for Phase 2+: the editor input pipeline and render layers will
// read/drive this controller. It is not yet wired into the running editor.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/persistence/isar_scene_element_store.dart';
import '../../data/persistence/scene_element_store.dart';
import '../../domain/commands/scene_command.dart';
import '../../domain/model/scene_element.dart';

class SceneController extends StateNotifier<List<SceneElement>>
    implements SceneMutator {
  final SceneElementStore _store;
  final int _notebookId;
  final int _pageId;

  SceneController(
    this._store, {
    required int notebookId,
    required int pageId,
  })  : _notebookId = notebookId,
        _pageId = pageId,
        super(const []);

  /// Loads this page's elements from the store (ordered by zOrder).
  Future<void> load() async {
    state = List.unmodifiable(await _store.loadForPage(_pageId));
  }

  /// Replaces the whole scene and persists it.
  Future<void> setAll(List<SceneElement> elements) async {
    state = List.unmodifiable(elements);
    await _store.clearForPage(_pageId);
    await _store.upsertForPage(_notebookId, _pageId, elements);
  }

  Future<void> add(SceneElement element) async {
    state = List.unmodifiable([...state, element]);
    await _store.upsertForPage(_notebookId, _pageId, [element]);
  }

  Future<void> addMany(List<SceneElement> elements) async {
    if (elements.isEmpty) return;
    state = List.unmodifiable([...state, ...elements]);
    await _store.upsertForPage(_notebookId, _pageId, elements);
  }

  /// Replaces existing elements (matched by id) with [elements].
  Future<void> updateMany(List<SceneElement> elements) async {
    if (elements.isEmpty) return;
    final byId = {for (final e in elements) e.id: e};
    state = List.unmodifiable([
      for (final e in state) byId[e.id] ?? e,
    ]);
    await _store.upsertForPage(_notebookId, _pageId, elements);
  }

  Future<void> removeMany(Set<String> ids) async {
    if (ids.isEmpty) return;
    final remaining = [
      for (final e in state)
        if (!ids.contains(e.id)) e,
    ];
    state = List.unmodifiable(remaining);
    await _store.clearForPage(_pageId);
    await _store.upsertForPage(_notebookId, _pageId, remaining);
  }

  Future<void> update(SceneElement element) async {
    state = List.unmodifiable([
      for (final e in state)
        if (e.id == element.id) element else e,
    ]);
    await _store.upsertForPage(_notebookId, _pageId, [element]);
  }

  Future<void> remove(String id) async {
    final remaining = [
      for (final e in state)
        if (e.id != id) e,
    ];
    state = List.unmodifiable(remaining);
    // No per-element delete on the store yet (added when autosave lands in a
    // later phase); rewrite the page's rows for now.
    await _store.clearForPage(_pageId);
    await _store.upsertForPage(_notebookId, _pageId, remaining);
  }

  // ---- SceneMutator (used by undo/redo commands; state updates are sync) ----

  @override
  void applyAdd(List<SceneElement> elements) => addMany(elements);

  @override
  void applyRemove(Set<String> ids) => removeMany(ids);

  @override
  void applyUpdate(List<SceneElement> elements) => updateMany(elements);

  @override
  void applyReplaceAll(List<SceneElement> elements) => setAll(elements);

  /// Next free z-order value (one above the current top).
  int nextZOrder() {
    var top = -1;
    for (final e in state) {
      if (e.zOrder > top) top = e.zOrder;
    }
    return top + 1;
  }
}

/// Production store. The new schemas are registered in the Isar open call (see
/// main.dart); override in tests/dev with an in-memory store.
final sceneElementStoreProvider =
    Provider<SceneElementStore>((ref) => IsarSceneElementStore());

/// Absolute app-documents path that relative image paths resolve against.
/// Overridden in main() with the real directory; '' in tests/dev playground
/// (which have no on-disk images).
final appDocsPathProvider = Provider<String>((ref) => '');

typedef ScenePageKey = ({int notebookId, int pageId});

final sceneControllerProvider = StateNotifierProvider.family<SceneController,
    List<SceneElement>, ScenePageKey>(
  (ref, key) => SceneController(
    ref.watch(sceneElementStoreProvider),
    notebookId: key.notebookId,
    pageId: key.pageId,
  ),
);
