// The notebooks opened most recently, for the strip above the home grid.
//
// Kept as a short list of ids in SharedPreferences, newest first: it needs no
// database column, and a notebook that is gone (trashed, deleted) simply drops
// out when the ids are matched against the live cards.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/note_card_data.dart';

/// How many recent notebooks are remembered.
const int kRecentNotebooksKept = 8;

/// [ids] with [id] moved (or added) to the front, capped at [cap].
List<int> pushRecent(List<int> ids, int id, {int cap = kRecentNotebooksKept}) =>
    [id, for (final i in ids) if (i != id) i].take(cap).toList();

/// The cards for [ids], in that order, skipping notebooks that are not there.
List<NoteCardData> recentCards(List<NoteCardData> cards, List<int> ids) {
  final byId = {for (final c in cards) c.id: c};
  return [for (final id in ids) ?byId[id]];
}

class RecentNotebooksNotifier extends StateNotifier<List<int>> {
  RecentNotebooksNotifier() : super(const []) {
    _load();
  }

  static const _key = 'home.recentNotebooks';

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getStringList(_key);
      if (raw == null || !mounted) return;
      final loaded = [for (final s in raw) ?int.tryParse(s)];
      // An open that happened while this was loading stays in front.
      state = [...state, for (final id in loaded) if (!state.contains(id)) id]
          .take(kRecentNotebooksKept)
          .toList();
    } catch (e) {
      debugPrint('[Recents] could not read recent notebooks: $e');
    }
  }

  /// Notes that notebook [id] was just opened.
  Future<void> record(int id) async {
    state = pushRecent(state, id);
    try {
      await (await SharedPreferences.getInstance())
          .setStringList(_key, [for (final i in state) '$i']);
    } catch (e) {
      debugPrint('[Recents] could not save recent notebooks: $e');
    }
  }
}

final recentNotebooksProvider =
    StateNotifierProvider<RecentNotebooksNotifier, List<int>>(
        (ref) => RecentNotebooksNotifier());
