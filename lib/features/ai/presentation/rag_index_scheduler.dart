// Decides WHEN a page gets re-embedded.
//
// RAG indexing rides the Context Engine's existing extraction (no second
// recognition pass, no polling loop), but deliberately NOT its 2.5s debounce.
// That cadence is tuned for analysis — one LLM call the user is waiting on —
// whereas embedding costs a ~175 MB model load and nobody is watching. Riding
// it directly would reload the embedder on every typing pause; a page is
// instead indexed once its text has settled.
//
// The 2.5s pass still does the useful half of the work: it decides whether the
// text CHANGED at all, so a quiet page schedules nothing.

import 'dart:async';

import '../domain/rag/rag_indexer.dart';

/// How long a page's text must sit unchanged before it is embedded.
///
/// A compromise, not a measurement: long enough that writing a paragraph
/// doesn't thrash the model, short enough that a page indexes while the user is
/// still in the app (an unindexed page isn't lost — the signature check
/// re-schedules it next time it's opened).
const Duration kIndexIdleDelay = Duration(seconds: 20);

/// Debounces [RagIndexer.indexPage] per page.
class RagIndexScheduler {
  final RagIndexer _indexer;
  final Duration idleDelay;

  /// One pending timer per page, so editing page A never cancels page B.
  final _pending = <int, Timer>{};

  RagIndexScheduler({
    required RagIndexer indexer,
    this.idleDelay = kIndexIdleDelay,
  }) : _indexer = indexer;

  /// Queues [pageId] to be indexed once its text stops changing.
  ///
  /// Never throws and never returns a failure: this is called from the Context
  /// Engine's notify hook, where an exception would be swallowed anyway and,
  /// worse, could stop a sibling listener from running.
  void schedule({
    required int notebookId,
    required int pageId,
    required String text,
  }) {
    _pending[pageId]?.cancel();
    _pending[pageId] = Timer(idleDelay, () {
      _pending.remove(pageId);
      unawaited(_index(notebookId: notebookId, pageId: pageId, text: text));
    });
  }

  Future<void> _index({
    required int notebookId,
    required int pageId,
    required String text,
  }) async {
    try {
      await _indexer.indexPage(
        notebookId: notebookId,
        pageId: pageId,
        text: text,
      );
    } catch (_) {
      // Swallowed on purpose, and safe to swallow: the overwhelmingly common
      // cause is the embedding model simply not being downloaded, which is a
      // normal state — not something to interrupt someone's writing over. The
      // indexer stores nothing on failure, so the page keeps its old signature
      // and the next attempt retries from scratch. Search degrades to "this
      // page isn't findable yet", which the RAG surfaces in Loop 2.3 report
      // honestly rather than papering over.
    }
  }

  /// Drops pending work — a page indexed after this would embed text the user
  /// may already have changed.
  void dispose() {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
  }
}
