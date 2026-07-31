// Indexing pages the user has never opened.
//
// This closes the structural hole in RAG. [RagIndexScheduler] is driven by the
// Context Engine's per-page "text changed" hook, which only ever fires for the
// page on screen — so retrieval could only ever see pages someone had opened
// and edited. Import a 40-page PDF and ask a question about it, and the honest
// answer was "I couldn't find that in your notes" for 39 of those pages, with
// nothing in the UI to explain why. The live scheduler is right for editing;
// it is simply the wrong trigger for content that arrives all at once.
//
// So this is the other trigger: given a list of page ids, read each page and
// index it, in order, reporting progress. Two callers today — the tail of a PDF
// import (eager, so a freshly imported document is searchable without the user
// flipping through it) and an explicit "Index all pages" action (retroactive,
// for the notebooks that predate this file).
//
// Pure in the same way the rest of `domain/rag` is: extraction and indexing
// arrive as callbacks, so this is unit-tested with fakes and no Isar, no model,
// no widgets.

import 'dart:async';

import '../ai_exception.dart';
import 'rag_indexer.dart';

/// Reads one page's AI-visible text (ink, typed text, OCR'd images, figures).
/// Wired in production to [PageContentExtractor]; a page that yields '' is
/// indexed as empty, which correctly clears any stale chunks it had.
typedef PageTextReader = Future<String> Function(int pageId);

/// How far along a bulk run is. [pagesDone] counts pages finished (indexed,
/// unchanged, cleared OR failed), so a progress bar always reaches the end.
class BulkIndexProgress {
  final int pagesDone;
  final int pagesTotal;
  const BulkIndexProgress({required this.pagesDone, required this.pagesTotal});

  double get fraction => pagesTotal == 0 ? 1 : pagesDone / pagesTotal;
}

/// What a whole run did — returned rather than logged, so the UI can report
/// "12 pages indexed, 3 already current" and tests can assert the incremental
/// path held across a batch.
class BulkIndexReport {
  final int indexed;
  final int unchanged;
  final int cleared;

  /// Pages whose indexing threw. Kept as ids (not exceptions) because the
  /// actionable half is which pages are missing from search, not the stack.
  final List<int> failedPageIds;

  /// Set when the run stopped early because the embedding model isn't
  /// installed. Every remaining page is untouched, so re-running after the
  /// download picks all of them up.
  final bool stoppedModelNotReady;

  const BulkIndexReport({
    this.indexed = 0,
    this.unchanged = 0,
    this.cleared = 0,
    this.failedPageIds = const [],
    this.stoppedModelNotReady = false,
  });

  int get pagesTouched => indexed + unchanged + cleared;

  /// True when nothing at all went wrong — the notebook is fully searchable.
  bool get isComplete => failedPageIds.isEmpty && !stoppedModelNotReady;
}

/// Indexes many pages in one pass.
class BulkRagIndexer {
  final RagIndexer _indexer;
  final PageTextReader _readPage;

  const BulkRagIndexer({
    required RagIndexer indexer,
    required PageTextReader readPage,
  })  : _indexer = indexer,
        _readPage = readPage;

  /// Indexes every page in [pageIds] for [notebookId], in the order given.
  ///
  /// Sequential on purpose, not concurrent: each page costs an OCR/vision read
  /// and an embedding pass on the SAME single-instance on-device models, so
  /// running pages in parallel would contend on one mutex while holding several
  /// pages' bitmaps in memory. Slower and steadier is the right trade on a
  /// phone.
  ///
  /// One page's failure never sinks the batch — a picture that won't decode
  /// costs its own page, and the other 39 still become searchable. The single
  /// exception is [AiModelNotReadyException]: with no embedding model installed
  /// every remaining page would fail identically, so the run stops and says so
  /// rather than grinding through 40 guaranteed failures.
  ///
  /// [isCancelled] is polled between pages so closing the notebook or hitting
  /// Cancel stops the run at the next page boundary rather than mid-embed.
  Future<BulkIndexReport> indexPages({
    required int notebookId,
    required List<int> pageIds,
    void Function(BulkIndexProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    var indexed = 0, unchanged = 0, cleared = 0;
    final failed = <int>[];
    var done = 0;

    onProgress?.call(
        BulkIndexProgress(pagesDone: 0, pagesTotal: pageIds.length));

    for (final pageId in pageIds) {
      if (isCancelled?.call() ?? false) break;
      try {
        final text = await _readPage(pageId);
        final outcome = await _indexer.indexPage(
          notebookId: notebookId,
          pageId: pageId,
          text: text,
        );
        switch (outcome) {
          case RagIndexOutcome.indexed:
            indexed++;
          case RagIndexOutcome.unchanged:
            unchanged++;
          case RagIndexOutcome.cleared:
            cleared++;
        }
      } on AiModelNotReadyException {
        return BulkIndexReport(
          indexed: indexed,
          unchanged: unchanged,
          cleared: cleared,
          failedPageIds: failed,
          stoppedModelNotReady: true,
        );
      } catch (_) {
        failed.add(pageId);
      }
      done++;
      onProgress?.call(
          BulkIndexProgress(pagesDone: done, pagesTotal: pageIds.length));
    }

    return BulkIndexReport(
      indexed: indexed,
      unchanged: unchanged,
      cleared: cleared,
      failedPageIds: failed,
    );
  }
}
