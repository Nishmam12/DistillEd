// Search across every notebook's page text, for the home screen's search.
//
// Pure: callers hand in each notebook's text rows and page order, and get back
// located hits, using the same matching rule as find-in-notebook.

import '../../../data/persistence/page_text_store.dart';
import 'note_search.dart';

/// One notebook's searchable text.
class NotebookCorpus {
  final int notebookId;
  final String title;
  final List<PageText> texts;

  /// pageId -> 0-based position of the page in the notebook.
  final Map<int, int> pageIndexById;

  const NotebookCorpus({
    required this.notebookId,
    required this.title,
    required this.texts,
    required this.pageIndexById,
  });
}

/// A match on one page of one notebook.
class GlobalSearchHit {
  final int notebookId;
  final String notebookTitle;
  final NoteSearchHit hit;

  const GlobalSearchHit({
    required this.notebookId,
    required this.notebookTitle,
    required this.hit,
  });
}

/// Finds [query] on the pages of every notebook in [corpus]: at most one hit
/// per page, [maxPerNotebook] per notebook and [maxTotal] overall, so one big
/// notebook cannot crowd out the rest.
List<GlobalSearchHit> searchAcrossNotebooks(
  List<NotebookCorpus> corpus,
  String query, {
  int maxPerNotebook = 3,
  int maxTotal = 30,
}) {
  if (query.trim().isEmpty) return const [];
  final out = <GlobalSearchHit>[];
  for (final book in corpus) {
    final hits = NoteSearch.search(
      pages: book.texts,
      pageIndexById: book.pageIndexById,
      query: query,
      maxHitsPerPage: 1,
    ).where((h) => h.pageIndex >= 0).take(maxPerNotebook);
    for (final h in hits) {
      out.add(GlobalSearchHit(
          notebookId: book.notebookId, notebookTitle: book.title, hit: h));
      if (out.length >= maxTotal) return out;
    }
  }
  return out;
}
