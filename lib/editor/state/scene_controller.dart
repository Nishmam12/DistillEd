// Holds the unified scene (ordered [SceneElement]s) for one page and persists
// mutations through a [SceneElementStore].
//
// Store writes are queued per controller (see [_enqueue]) so they reach the
// database in the order the edits were made.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/error_log.dart';
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

  // Tail of each page's write queue. Edits change `state` synchronously but
  // their writes are async; without ordering, a slow earlier write could land
  // after a later one and resurrect a deleted element. Keyed by page rather
  // than held per instance: a controller released while its writes are in
  // flight (the editor closing) must still order before the next controller
  // for that page loads.
  static final Map<int, Future<void>> _tails = {};

  Future<void> get _tail => _tails[_pageId] ?? Future.value();

  Future<void> _enqueue(Future<void> Function() write) {
    final next = _tail.then((_) => write());
    final tail = next.catchError((_) {});
    _tails[_pageId] = tail;
    // Drop the entry once drained, unless a later write has replaced it.
    tail.then((_) {
      if (identical(_tails[_pageId], tail)) _tails.remove(_pageId);
    });
    return next;
  }

  /// For the sync [SceneMutator] entry points, which cannot be awaited.
  ///
  /// A failed write leaves the canvas showing something the database does not
  /// have, so it is logged and the scene is reloaded from the store.
  void _fireAndLog(Future<void> write) =>
      write.catchError((Object e, StackTrace s) async {
        debugPrint('Scene write failed: $e\n$s');
        await ErrorLog.record(e, s);
        try {
          if (mounted) await load();
        } catch (_) {}
      });

  /// Loads this page's elements from the store (ordered by zOrder).
  Future<void> load() async {
    // Let in-flight writes land first so the read can't return stale rows.
    await _tail;
    state = List.unmodifiable(await _store.loadForPage(_pageId));
  }

  /// Replaces the whole scene and persists it.
  Future<void> setAll(List<SceneElement> elements) async {
    state = List.unmodifiable(elements);
    await _enqueue(() => _store.replaceForPage(_notebookId, _pageId, elements));
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

  /// Replaces elements in memory only (no store write). For per-move updates
  /// during a drag; the caller persists the final state once via [updateMany].
  void updateInMemory(List<SceneElement> elements) {
    final byId = {for (final e in elements) e.id: e};
    state = List.unmodifiable([
      for (final e in state) byId[e.id] ?? e,
    ]);
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
