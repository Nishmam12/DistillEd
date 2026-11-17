// Which tools the editor's toolbar shows, and in what order (Samsung Notes'
// customisable toolbar). Kept in shared_preferences as two lists of tool ids,
// shown and hidden; a known tool in neither list is new to this build and
// is shown, at the end. Unknown ids are dropped when read.

import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every tool the toolbar can show, in the default order. The arrow is the
/// shape tool's line-and-arrow variant; the rest are [EditorTool] names.
const List<String> kToolbarItems = [
  'select',
  'pen',
  'shape',
  'arrow',
  'eraser',
  'text',
  'tape',
  'laser',
];

class ToolbarLayout {
  final List<String> shown;
  const ToolbarLayout(this.shown);

  static const standard = ToolbarLayout(kToolbarItems);

  /// The tools not on the bar, in the default order.
  List<String> get hidden => [
        for (final id in kToolbarItems)
          if (!shown.contains(id)) id,
      ];

  /// From what was stored; [shownIds] null means never customised.
  static ToolbarLayout fromStored(List<String>? shownIds, List<String>? hiddenIds) {
    if (shownIds == null) return standard;
    final shown = <String>[
      for (final id in shownIds)
        if (kToolbarItems.contains(id)) id,
    ].toSet().toList();
    final hidden = {...?hiddenIds};
    for (final id in kToolbarItems) {
      if (!shown.contains(id) && !hidden.contains(id)) shown.add(id);
    }
    // A bar with no tools on it cannot be drawn with; start again.
    return shown.isEmpty ? standard : ToolbarLayout(shown);
  }
}

class ToolbarLayoutNotifier extends StateNotifier<ToolbarLayout> {
  ToolbarLayoutNotifier() : super(ToolbarLayout.standard) {
    _load();
  }

  static const _shownKey = 'editor.toolbar.shown';
  static const _hiddenKey = 'editor.toolbar.hidden';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? read(String key) {
        final raw = prefs.getString(key);
        return raw == null ? null : [for (final v in jsonDecode(raw) as List) '$v'];
      }

      if (mounted) state = ToolbarLayout.fromStored(read(_shownKey), read(_hiddenKey));
    } catch (_) {}
  }

  /// Shows [shown], in that order. Ignored when it would leave no tool.
  Future<void> set(List<String> shown) async {
    if (shown.isEmpty) return;
    state = ToolbarLayout(shown);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_shownKey, jsonEncode(state.shown));
      await prefs.setString(_hiddenKey, jsonEncode(state.hidden));
    } catch (_) {}
  }

  Future<void> reset() async {
    state = ToolbarLayout.standard;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_shownKey);
      await prefs.remove(_hiddenKey);
    } catch (_) {}
  }
}

final toolbarLayoutProvider =
    StateNotifierProvider<ToolbarLayoutNotifier, ToolbarLayout>(
        (ref) => ToolbarLayoutNotifier());
