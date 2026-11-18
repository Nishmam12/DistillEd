// Loads every notebook's page text once for the home search, and answers the
// current query from memory.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../ai/presentation/ai_providers.dart'
    show noteChunkStoreProvider, textEmbedderProvider;
import '../domain/meaning_search.dart';

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
    if (book.hidden) continue; // hidden notes are never searched
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

/// "Matched by meaning" for [query]: pages that mean what was typed but don't
/// contain it, from the embeddings the tutor keeps — on the device, offline.
///
/// Waits for typing to pause before embedding anything; empty for a short
/// query, with the setting off, or while the search model is not on the device.
final meaningSearchProvider = FutureProvider.autoDispose
    .family<List<GlobalSearchHit>, String>((ref, query) async {
  if (!ref.watch(settingsProvider.select((s) => s.searchByMeaning))) {
    return const [];
  }
  if (query.trim().length < 3) return const [];
  // A newer query replaces this provider: its wait is cancelled, not left
  // running.
  var replaced = false;
  final paused = Completer<void>();
  final wait = Timer(const Duration(milliseconds: 400), paused.complete);
  ref.onDispose(() {
    replaced = true;
    wait.cancel();
    if (!paused.isCompleted) paused.complete();
  });
  await paused.future;
  if (replaced) return const [];

  final corpus = await ref.watch(globalSearchCorpusProvider.future);
  final exact = {
    for (final h in searchAcrossNotebooks(corpus, query)) h.hit.pageId,
  };
  try {
    return await searchByMeaning(
      query: query,
      embedder: ref.read(textEmbedderProvider),
      chunksOf: ref.read(noteChunkStoreProvider).forNotebook,
      notebooks: corpus,
      exclude: exact,
    );
  } catch (_) {
    // No search model yet, or it failed: the exact results stand alone.
    return const [];
  }
});
