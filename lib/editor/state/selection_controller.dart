// Holds the set of selected element ids for the unified canvas.

import 'package:flutter_riverpod/legacy.dart';

class SelectionController extends StateNotifier<Set<String>> {
  SelectionController() : super(const {});

  void selectOnly(String id) => state = {id};
  void selectMany(Iterable<String> ids) => state = ids.toSet();
  void addToSelection(String id) => state = {...state, id};

  void toggle(String id) =>
      state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};

  void clear() => state = const {};
}

final selectionProvider =
    StateNotifierProvider.autoDispose<SelectionController, Set<String>>(
  (ref) => SelectionController(),
);
