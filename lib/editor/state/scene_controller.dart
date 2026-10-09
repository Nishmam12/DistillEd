// Holds the unified scene (ordered [SceneElement]s) for one page and persists
// mutations through a [SceneElementStore].
//
// Store writes are queued per controller (see [_enqueue]) so they reach the
// database in the order the edits were made.

import 'package:flutter/foundation.dart' show debugPrint;
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
    required this._notebookId,
    required this._pageId,
  })  : super(const []);

  // Tail of the write queue. Edits change `state` synchronously but their
  // writes are async; without ordering, a slow earlier write could land after
  // a later one and resurrect a deleted element.
  Future<void> _tail = Future.value();

  Future<void> _enqueue(Future<void> Function() write) {
    final next = _tail.then((_) => write());
    _tail = next.catchError((_) {});
    return next;
  }

  /// For the sync [SceneMutator] entry points, which cannot be awaited.
  void _fireAndLog(Future<void> write) =>
      write.catchError((Object e, StackTrace s) {
        debugPrint('Scene write failed: $e\n$s');
      });

  /// Loads this page's elements from the store (ordered by zOrder).
  Future<void> load() async {
    state = List.unmodifiable(await _store.loadForPage(_pageId));
  }

  /// Replaces the whole scene and persists it.
  Future<void> setAll(List<SceneElement> elements) async {
    state = List.unmodifiable(elements);
    await _enqueue(() => _store.replaceForPage(_notebookId, _pageId, elements));
  }

  Future<void> add(SceneElement element) async {
    state = List.unmodifiable([...state, element]);
    await _enqueue(() => _store.upsertForPage(_notebookId, _pageId, [element]));
  }

  Future<void> addMany(List<SceneElement> elements) async {
    if (elements.isEmpty) return;
    state = List.unmodifiable([...state, ...elements]);
    await _enqueue(() => _store.upsertForPage(_notebookId, _pageId, elements));
  }

  /// Replaces existing elements (matched by id) with [elements].
  Future<void> updateMany(List<SceneElement> elements) async {
    if (elements.isEmpty) return;
    final byId = {for (final e in elements) e.id: e};
    state = List.unmodifiable([
      for (final e in state) byId[e.id] ?? e,
    ]);
    await _enqueue(() => _store.upsertForPage(_notebookId, _pageId, elements));
  }

  Future<void> removeMany(Set<String> ids) async {
    if (ids.isEmpty) return;
    final remaining = [
      for (final e in state)
        if (!ids.contains(e.id)) e,
    ];
    state = List.unmodifiable(remaining);
    await _enqueue(() => _store.deleteElements(_pageId, ids));
  }

  Future<void> update(SceneElement element) async {
    state = List.unmodifiable([
      for (final e in state)
        if (e.id == element.id) element else e,
    ]);
    await _enqueue(() => _store.upsertForPage(_notebookId, _pageId, [element]));
  }

  Future<void> remove(String id) async {
    final remaining = [
      for (final e in state)
        if (e.id != id) e,
    ];
    state = List.unmodifiable(remaining);
    await _enqueue(() => _store.deleteElements(_pageId, {id}));
  }

  // ---- SceneMutator (used by undo/redo commands; state updates are sync) ----

  @override
  void applyAdd(List<SceneElement> elements) => _fireAndLog(addMany(elements));

  @override
  void applyRemove(Set<String> ids) => _fireAndLog(removeMany(ids));

  @override
  void applyUpdate(List<SceneElement> elements) =>
      _fireAndLog(updateMany(elements));

  @override
  void applyReplaceAll(List<SceneElement> elements) =>
      _fireAndLog(setAll(elements));

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
