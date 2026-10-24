// Holds the set of selected element ids for the unified canvas.

import 'package:flutter_riverpod/legacy.dart';

class SelectionController extends StateNotifier<Set<String>> {
  SelectionController() : super(const {});

  void selectMany(Iterable<String> ids) => state = ids.toSet();

  void toggle(String id) =>
      state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};

  void clear() => state = const {};

  /// Drops ids that are no longer in the scene (deleted, undone, erased), so
  /// the selection bar does not hang on after its elements are gone.
  void retainOnly(Set<String> existing) {
    if (state.every(existing.contains)) return;
    state = state.intersection(existing);
  }
}

final selectionProvider =
    StateNotifierProvider.autoDispose<SelectionController, Set<String>>(
  (ref) => SelectionController(),
);
