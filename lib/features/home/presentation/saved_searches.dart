// Saved searches: a name for the notes list's current filters (folder, tags,
// favourites, date, handwriting, recording) and sort, to come back to in one
// tap. Kept in shared_preferences as JSON; no database change.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'note_cards_provider.dart';

class SavedSearch {
  final String name;
  final int? folderId; // null all, -1 unfiled, else the folder
  final List<String> tags;
  final bool favoritesOnly;
  final NotesMoreFilters more;
  final NotesSort sort;

  const SavedSearch({
    required this.name,
    this.folderId,
    this.tags = const [],
    this.favoritesOnly = false,
    this.more = const NotesMoreFilters(),
    this.sort = NotesSort.recent,
  });

  Map<String, Object?> toJson() => {
        'name': name,
        'folder': folderId,
        'tags': tags,
        'fav': favoritesOnly,
        'date': more.date.name,
        'ink': more.inkOnly,
        'rec': more.recordingOnly,
        'sort': sort.name,
      };

  /// Null for anything unreadable; an unknown enum name falls back to the
  /// default rather than losing the whole search.
  static SavedSearch? fromJson(Object? json) {
    if (json is! Map || json['name'] is! String) return null;
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return SavedSearch(
      name: json['name'] as String,
      folderId: json['folder'] is int ? json['folder'] as int : null,
      tags: [for (final t in (json['tags'] as List? ?? const [])) if (t is String) t],
      favoritesOnly: json['fav'] == true,
      more: NotesMoreFilters(
        date: byName(NotesDateFilter.values, json['date'], NotesDateFilter.any),
        inkOnly: json['ink'] == true,
        recordingOnly: json['rec'] == true,
      ),
      sort: byName(NotesSort.values, json['sort'], NotesSort.recent),
    );
  }
}

class SavedSearchesNotifier extends StateNotifier<List<SavedSearch>> {
  SavedSearchesNotifier() : super(const []) {
    _load();
  }

  static const _key = 'home.savedSearches';

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null || !mounted) return;
      state = [
        for (final s in jsonDecode(raw) as List)
          if (SavedSearch.fromJson(s) case final search?) search,
      ];
    } catch (_) {
      // A damaged list is an empty one; the notes are untouched.
    }
  }

  Future<void> _store() async => (await SharedPreferences.getInstance())
      .setString(_key, jsonEncode([for (final s in state) s.toJson()]));

  /// Saves the list's current filters as [name], replacing one of that name.
  Future<void> saveCurrent(WidgetRef ref, String name) async {
    final folder = ref.read(notesFolderFilterProvider);
    final search = SavedSearch(
      name: name,
      folderId: switch (folder) {
        _ when folder == FolderFilter.all => null,
        _ when folder == FolderFilter.unfiled => -1,
        _ => folder.folderIdOrNull,
      },
      tags: ref.read(notesTagFilterProvider).toList()..sort(),
      favoritesOnly: ref.read(notesFavoritesOnlyProvider),
      more: ref.read(notesMoreFiltersProvider),
      sort: ref.read(notesSortProvider),
    );
    state = [for (final s in state) if (s.name != name) s, search];
    await _store();
  }

  Future<void> delete(String name) async {
    state = [for (final s in state) if (s.name != name) s];
    await _store();
  }
}

/// Puts the list back the way [search] had it.
void applySavedSearch(WidgetRef ref, SavedSearch search) {
  ref.read(notesFolderFilterProvider.notifier).state = switch (search.folderId) {
    null => FolderFilter.all,
    -1 => FolderFilter.unfiled,
    final id => FolderFilter.only(id),
  };
  ref.read(notesTagFilterProvider.notifier).state = search.tags.toSet();
  ref.read(notesFavoritesOnlyProvider.notifier).state = search.favoritesOnly;
  ref.read(notesMoreFiltersProvider.notifier).state = search.more;
  ref.read(notesSortProvider.notifier).state = search.sort;
}

final savedSearchesProvider =
    StateNotifierProvider<SavedSearchesNotifier, List<SavedSearch>>(
        (ref) => SavedSearchesNotifier());

/// The last few searches whose result was opened, newest first: shown under
/// the empty search field to run again in one tap. Kept in shared_preferences.
class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier() : super(const []) {
    _load();
  }

  static const _key = 'home.recentSearches';
  static const max = 8;

  Future<void> _load() async {
    try {
      final saved =
          (await SharedPreferences.getInstance()).getStringList(_key);
      // Something added before the load finished stays first.
      if (saved != null && mounted) state = _merged(state, saved);
    } catch (_) {}
  }

  static List<String> _merged(List<String> first, List<String> then) {
    final out = <String>[];
    for (final q in [...first, ...then]) {
      if (out.length == max) break;
      if (!out.any((o) => o.toLowerCase() == q.toLowerCase())) out.add(q);
    }
    return out;
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    state = _merged([q], state);
    await _store();
  }

  Future<void> clear() async {
    state = const [];
    await _store();
  }

  Future<void> _store() async {
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key, state);
    } catch (_) {}
  }
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
        (ref) => RecentSearchesNotifier());
