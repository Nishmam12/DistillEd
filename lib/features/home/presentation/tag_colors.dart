// Tag colours: a dot beside a tag in the sidebar. Kept in shared_preferences
// (they are cosmetic); a backup restored on another phone brings the tags
// back without their colours.

import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The swatches offered, from the app's calm palette.
const kTagColors = <int>[
  0xFF7FA38A, // sage
  0xFF6E8FB5, // slate blue
  0xFFC9A55B, // ochre
  0xFFC97B6B, // clay
  0xFF9A7FB5, // heather
  0xFF7A8A8A, // grey
];

class TagColorsNotifier extends StateNotifier<Map<String, int>> {
  TagColorsNotifier() : super(const {}) {
    _load();
  }

  static const _key = 'home.tagColors';

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null || !mounted) return;
      state = {
        for (final MapEntry(:key, :value) in (jsonDecode(raw) as Map).entries)
          if (key is String && value is int) key: value,
      };
    } catch (_) {}
  }

  /// Colours [tag]; null takes its colour away.
  Future<void> set(String tag, int? color) async {
    state = {
      for (final e in state.entries)
        if (e.key != tag) e.key: e.value,
      if (color != null) tag: color,
    };
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(state));
  }
}

final tagColorsProvider =
    StateNotifierProvider<TagColorsNotifier, Map<String, int>>(
        (ref) => TagColorsNotifier());
