// The student's own study recipes, beside the built-in ones. Kept in
// shared_preferences as JSON; no database change.

import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/study_recipes.dart';

class StudyRecipesNotifier extends StateNotifier<List<StudyRecipe>> {
  StudyRecipesNotifier() : super(kBuiltInRecipes) {
    _load();
  }

  static const _key = 'tutor.recipes';

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null || !mounted) return;
      final own = [
        for (final r in jsonDecode(raw) as List)
          if (r case {'n': final String n, 'i': final String i})
            if (recipeName(n) == n && i.trim().isNotEmpty) StudyRecipe(n, i),
      ];
      state = _merged(own);
    } catch (_) {}
  }

  /// Built-ins first, then the student's own; an own recipe with a built-in's
  /// name replaces it.
  static List<StudyRecipe> _merged(List<StudyRecipe> own) => [
        for (final b in kBuiltInRecipes)
          if (!own.any((o) => o.name == b.name)) b,
        ...own,
      ];

  List<StudyRecipe> get _own => [
        for (final r in state)
          if (!r.builtIn) r,
      ];

  Future<void> save(String name, String instruction) async {
    state = _merged([
      for (final r in _own)
        if (r.name != name) r,
      StudyRecipe(name, instruction.trim()),
    ]);
    await _store();
  }

  /// False when there is no recipe of the student's called [name].
  Future<bool> remove(String name) async {
    if (!_own.any((r) => r.name == name)) return false;
    state = _merged([
      for (final r in _own)
        if (r.name != name) r,
    ]);
    await _store();
    return true;
  }

  Future<void> _store() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
          _key,
          jsonEncode([
            for (final r in _own) {'n': r.name, 'i': r.instruction},
          ]));
    } catch (_) {}
  }
}

final studyRecipesProvider =
    StateNotifierProvider<StudyRecipesNotifier, List<StudyRecipe>>(
        (ref) => StudyRecipesNotifier());
