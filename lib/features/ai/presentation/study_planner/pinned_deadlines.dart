// Dates the student added to a notebook's study plan from a selection ("Add
// to study plan" on a date chip). Kept in shared_preferences per notebook, no
// database change; shown beside the dates found in the notes.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/study_planner/note_deadlines.dart';

class PinnedDeadlines {
  static String _key(int notebookId) => 'planner.pinned.$notebookId';

  /// Every pinned date, past ones included. Unreadable rows are skipped.
  static Future<List<NoteDeadline>> load(int notebookId) async {
    try {
      final raw =
          (await SharedPreferences.getInstance()).getString(_key(notebookId));
      if (raw == null) return const [];
      return [
        for (final r in jsonDecode(raw) as List)
          if (r case {'d': final int d, 'l': final String l, 'p': final int p})
            NoteDeadline(
              date: DateTime.fromMillisecondsSinceEpoch(d),
              label: l,
              pageId: p,
              pinned: true,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Adds [d], replacing one on the same day with the same label.
  static Future<void> add(int notebookId, NoteDeadline d) async {
    final kept = [
      for (final o in await load(notebookId))
        if (!_same(o, d)) o,
      d,
    ];
    await _store(notebookId, kept);
  }

  static Future<void> remove(int notebookId, NoteDeadline d) async =>
      _store(notebookId, [
        for (final o in await load(notebookId))
          if (!_same(o, d)) o,
      ]);

  static bool _same(NoteDeadline a, NoteDeadline b) =>
      a.date == b.date && a.label.toLowerCase() == b.label.toLowerCase();

  static Future<void> _store(int notebookId, List<NoteDeadline> all) async =>
      (await SharedPreferences.getInstance()).setString(
          _key(notebookId),
          jsonEncode([
            for (final d in all)
              {'d': d.date.millisecondsSinceEpoch, 'l': d.label, 'p': d.pageId},
          ]));
}

/// [found] and the pinned dates from today on, soonest first. A pinned date
/// that was also found shows once, as pinned (so it can be removed).
List<NoteDeadline> mergeDeadlines(
  List<NoteDeadline> found,
  List<NoteDeadline> pinned, {
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final upcoming = [
    for (final p in pinned)
      if (!p.date.isBefore(today)) p,
  ];
  String key(NoteDeadline d) =>
      '${d.date.millisecondsSinceEpoch}|${d.label.toLowerCase()}';
  final pinnedKeys = {for (final p in upcoming) key(p)};
  final all = [
    ...upcoming,
    for (final f in found)
      if (!pinnedKeys.contains(key(f))) f,
  ];
  // Stable by date: insertion order breaks ties.
  final order = {for (var i = 0; i < all.length; i++) all[i]: i};
  all.sort((a, b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : order[a]!.compareTo(order[b]!);
  });
  return all;
}
