// Holds the element library and persists changes through a [LibraryRepository].
// The library is global (not per-page), so this is a single provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/persistence/library_repository.dart';
import '../../domain/model/library_item.dart';
import '../../domain/model/scene_element.dart';

class LibraryController extends StateNotifier<List<LibraryItem>> {
  final LibraryRepository _repo;
  LibraryController(this._repo) : super(const []);

  // Every save writes the whole library, so saves must land in the order the
  // edits were made: an older snapshot finishing last would bring back whatever
  // was removed since. Each save waits for the one before it.
  Future<void> _tail = Future.value();

  Future<void> _save() {
    final snapshot = state;
    final next = _tail.then((_) => _repo.saveAll(snapshot));
    _tail = next.catchError((_) {});
    return next;
  }

  Future<void> load() async {
    // Let pending saves land first, so the read cannot bring back an older copy.
    await _tail;
    state = List.unmodifiable(await _repo.load());
  }

  /// Saves [elements] as a new named library item (the cluster is stored in its
  /// current scene coordinates; insertion repositions it).
  Future<LibraryItem> addFromElements(
    String name,
    List<SceneElement> elements, {
    required String id,
  }) async {
    final item = LibraryItem(
      id: id,
      name: name,
      createdAt: DateTime.now(),
      elements: List.of(elements),
    );
    state = List.unmodifiable([...state, item]);
    await _save();
    return item;
  }

  Future<void> rename(String id, String name) async {
    state = List.unmodifiable([
      for (final i in state) i.id == id ? i.copyWith(name: name) : i,
    ]);
    await _save();
  }

  Future<void> remove(String id) async {
    state = List.unmodifiable([
      for (final i in state)
        if (i.id != id) i,
    ]);
    await _save();
  }
}

/// In-memory by default; the dev playground and tests override this, and the
/// real app wires a [FileLibraryRepository] when launch persistence lands.
final libraryRepositoryProvider =
    Provider<LibraryRepository>((ref) => InMemoryLibraryRepository());

final libraryProvider =
    StateNotifierProvider<LibraryController, List<LibraryItem>>(
  (ref) => LibraryController(ref.watch(libraryRepositoryProvider)),
);
