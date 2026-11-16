// Loads every notebook's page text once for the home search, and answers the
// current query from memory.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/persistence/page_text_store.dart';
import '../../../editor/state/page_notifier.dart';
import '../../home/presentation/home_notifier.dart';
import '../domain/global_search.dart';

/// The text of every live notebook. Read when the search panel opens; it is
/// dropped again once nothing watches it.
final globalSearchCorpusProvider =
    FutureProvider.autoDispose<List<NotebookCorpus>>((ref) async {
  final notebooks = ref.read(homeNotifierProvider);
  final pages = ref.read(pageRepositoryProvider);
  final texts = ref.read(pageTextStoreProvider);
  final corpus = <NotebookCorpus>[];
  for (final book in notebooks) {
    final rows = await texts.forNotebook(book.id);
    if (rows.isEmpty) continue;
    final order = await pages.getPagesForNotebook(book.id);
    corpus.add(NotebookCorpus(
      notebookId: book.id,
      title: book.title,
      texts: rows,
      pageIndexById: {for (var i = 0; i < order.length; i++) order[i].id: i},
    ));
  }
  return corpus;
});
