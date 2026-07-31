// Drives a bulk RAG indexing run over many pages:
//   idle → running(progress) → done(report)
//              ↘ modelMissing (the embedder isn't downloaded)
//
// Two entry points, both of which exist because [RagIndexScheduler] can only
// see the page on screen:
//   • [indexImport] — called the moment a PDF import finishes, so the document
//     is searchable before the student has flipped through a single page.
//   • [indexNotebook] — the explicit "Index all pages" action, for every
//     notebook that was imported before eager indexing existed.
//
// The run is fire-and-forget from the caller's point of view: an import must
// not block on 40 embeddings, and the state here is what the UI subscribes to
// if it wants to show progress. Failures are surfaced in the report rather than
// thrown — a page that wouldn't index is a page that isn't searchable, which is
// worth saying plainly and is never worth interrupting the editor over.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/rag/bulk_indexer.dart';

sealed class NotebookIndexState {
  const NotebookIndexState();
}

class NotebookIndexIdle extends NotebookIndexState {
  const NotebookIndexIdle();
}

class NotebookIndexRunning extends NotebookIndexState {
  final BulkIndexProgress progress;
  const NotebookIndexRunning(this.progress);
}

class NotebookIndexDone extends NotebookIndexState {
  final BulkIndexReport report;
  const NotebookIndexDone(this.report);

  /// One line a snackbar can show without the caller re-deriving it.
  String get message {
    if (report.stoppedModelNotReady) {
      return 'Pages will be searchable once the search model is downloaded.';
    }
    final failed = report.failedPageIds.length;
    final tail = failed == 0 ? '' : ' ($failed could not be read)';
    if (report.indexed == 0) {
      return 'Your notes were already searchable$tail.';
    }
    final s = report.indexed == 1 ? '' : 's';
    return '${report.indexed} page$s added to search$tail.';
  }
}

class NotebookIndexNotifier extends StateNotifier<NotebookIndexState> {
  final BulkRagIndexer _indexer;

  NotebookIndexNotifier({required BulkRagIndexer indexer})
      : _indexer = indexer,
        super(const NotebookIndexIdle());

  bool _running = false;
  bool _cancelled = false;

  bool get isRunning => _running;

  /// Indexes [pageIds] for [notebookId]. No-op while another run is in flight —
  /// two overlapping runs would contend on the single embedder instance and
  /// duplicate every page's work.
  Future<BulkIndexReport?> run({
    required int notebookId,
    required List<int> pageIds,
  }) async {
    if (_running || pageIds.isEmpty) return null;
    _running = true;
    _cancelled = false;
    state = NotebookIndexRunning(
        BulkIndexProgress(pagesDone: 0, pagesTotal: pageIds.length));
    try {
      final report = await _indexer.indexPages(
        notebookId: notebookId,
        pageIds: pageIds,
        onProgress: (p) {
          if (mounted && _running) state = NotebookIndexRunning(p);
        },
        isCancelled: () => _cancelled,
      );
      if (mounted) state = NotebookIndexDone(report);
      return report;
    } finally {
      _running = false;
    }
  }

  /// Stops at the next page boundary. The pages already indexed stay indexed —
  /// each page is its own transaction, so a cancelled run leaves a consistent,
  /// partially-searchable notebook rather than nothing.
  void cancel() => _cancelled = true;

  void reset() {
    if (!_running) state = const NotebookIndexIdle();
  }
}
