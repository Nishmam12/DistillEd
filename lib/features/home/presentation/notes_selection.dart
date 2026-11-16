// Multi-select on the home grid: the ids of the notebooks picked. Empty means
// not selecting, so un-picking the last one leaves select mode.

import 'package:flutter_riverpod/legacy.dart';

final notesSelectionProvider = StateProvider<Set<int>>((ref) => const {});

extension NotesSelectionToggle on StateController<Set<int>> {
  void toggle(int id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }
}
