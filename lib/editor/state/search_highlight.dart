// What to tint on a page opened from Find: the words the search found. Set when
// a result is opened, shown only on that page, and cleared by its chip.

import 'package:flutter_riverpod/legacy.dart';

class SearchHighlight {
  final int pageId;
  final String query;

  const SearchHighlight({required this.pageId, required this.query});

  @override
  bool operator ==(Object other) =>
      other is SearchHighlight && other.pageId == pageId && other.query == query;

  @override
  int get hashCode => Object.hash(pageId, query);
}

final searchHighlightProvider =
    StateProvider<SearchHighlight?>((ref) => null);
