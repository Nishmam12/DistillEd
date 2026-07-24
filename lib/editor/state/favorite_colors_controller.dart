// Three quick-access "favourite" ink colours shown in the editor toolbar,
// persisted across launches. Tapping a swatch applies it as the active drawing
// colour; long-pressing a swatch reassigns it (see EditorBottomBar). Values are
// ARGB ints, matching [EditorToolState.color].
//
// Persistence lives here (not in core settings, which the header there asks to
// keep feature-agnostic) because favourite colours are an editor concern. The
// list is stored as strings because SharedPreferences has no int-list API.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteColorsController extends StateNotifier<List<int>> {
  static const _key = 'editor.favoriteColors';

  /// How many favourite slots the toolbar shows.
  static const int slots = 3;

  /// The colours a fresh install starts with — charcoal, coral-red and blue,
  /// the three most-reached-for inks (drawn from the editor palette). Kept in
  /// sync with [slots].
  static const List<int> defaults = [0xFF1F2933, 0xFFE03131, 0xFF1971C2];

  FavoriteColorsController() : super(defaults) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final stored = prefs.getStringList(_key);
    if (stored == null) return;

    final parsed = <int>[];
    for (final s in stored) {
      final v = int.tryParse(s);
      if (v != null) parsed.add(v);
    }
    // Only adopt a well-formed triple; a corrupt or differently-sized value
    // falls back to defaults so the toolbar is never short a swatch.
    if (parsed.length == slots) state = parsed;
  }

  /// Reassigns the swatch at [index] to [color] and persists all three. Out-of-
  /// range indices are ignored rather than throwing.
  Future<void> setColor(int index, int color) async {
    if (index < 0 || index >= state.length) return;
    if (state[index] == color) return;
    final next = [...state]..[index] = color;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [for (final c in next) '$c']);
  }
}

final favoriteColorsProvider =
    StateNotifierProvider<FavoriteColorsController, List<int>>(
  (ref) => FavoriteColorsController(),
);
