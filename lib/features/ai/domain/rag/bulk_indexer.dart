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
import '../device_state.dart';
import '../pipeline_flags.dart';
import 'rag_indexer.dart';

/// Reads one page's AI-visible text (ink, typed text, OCR'd images, figures).
/// Wired in production to [PageContentExtractor]; a page that yields '' is
/// indexed as empty, which correctly clears any stale chunks it had.
typedef PageTextReader = Future<String> Function(int pageId);

/// Which half of a batched run is under way.
enum BulkIndexPhase {
  /// Every page is read and embedded in turn (batching off) — one combined pass.
  combined,

  /// Reading pages with the vision model; nothing is embedded yet.
  reading,

  /// Embedding the pages that were read; the vision model is already unloaded.
  indexing,
}

/// How far along a bulk run is. [pagesDone] counts pages finished (indexed,
/// unchanged, cleared OR failed) in the current [phase], so a progress bar
/// always reaches the end of each.
class BulkIndexProgress {
  final int pagesDone;
  final int pagesTotal;
  final BulkIndexPhase phase;

  /// Set while the run is WAITING — the device is hot or low on power — so the
  /// UI can say why nothing is moving. Null whenever work is under way.
  final PauseReason? paused;

  const BulkIndexProgress({
    required this.pagesDone,
    required this.pagesTotal,
    this.phase = BulkIndexPhase.combined,
    this.paused,
  });

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

  /// Set when the run stopped early because the vision (page-reading) model
  /// isn't installed. [stoppedModelNotReady] is also set then (some model is
  /// missing); this says which.
  final bool stoppedVisionNotReady;

  const BulkIndexReport({
    this.indexed = 0,
    this.unchanged = 0,
    this.cleared = 0,
    this.failedPageIds = const [],
    this.stoppedModelNotReady = false,
    this.stoppedVisionNotReady = false,
  });

  /// True when nothing at all went wrong — the notebook is fully searchable.
  bool get isComplete => failedPageIds.isEmpty && !stoppedModelNotReady;
}

/// Indexes many pages in one pass.
class BulkRagIndexer {
  final RagIndexer _indexer;
  final PageTextReader _readPage;

  /// Read every page first, unload the vision model, then embed every page —
  /// see [kBatchByModel]. Off alternates the two models page by page.
  final bool batchByModel;

  /// Whether the embedding model is installed. Asked before the first read: the
  /// reads are the expensive part, and a missing embedder would throw every one
  /// of them away.
  final Future<bool> Function()? _embedderReady;

  /// Unloads the vision model. Called once reading is over, so its ~2.6 GB is
  /// back before the embedder works rather than after the idle timer.
  final Future<void> Function()? _releaseVisionModel;

  /// Told each page's text as soon as it has been read. Wired to the
  /// searchable-text store so a page is findable by keyword the moment it is
  /// read — and stays so for someone who has never downloaded the embedder.
  final Future<void> Function(int notebookId, int pageId, String text)?
      _onPageRead;

  /// Why a read should wait right now (a hot or low-battery device), or null to
  /// go ahead. Asked before every page is READ — the heavy part; embedding is
  /// light and is not held up. Null means "never wait".
  final Future<PauseReason?> Function()? _pauseReason;

  /// How often a waiting run asks again.
  final Duration pollInterval;

  const BulkRagIndexer({
    required this._indexer,
    required this._readPage,
    this.batchByModel = kBatchByModel,
    this._embedderReady,
    this._releaseVisionModel,
    this._onPageRead,
    this._pauseReason,
    this.pollInterval = const Duration(seconds: 15),
  });

  /// Waits while the device says background work should wait, reporting why on
  /// each poll. Returns false if the run was cancelled during the wait, so a
  /// device that never cools cannot hold a cancelled run for ever.
  Future<bool> _waitForDevice({
    required BulkIndexPhase phase,
    required int done,
    required int total,
    void Function(BulkIndexProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final check = _pauseReason;
    if (check == null) return true;
    while (true) {
      final reason = await check();
      if (reason == null) return true;
      onProgress?.call(BulkIndexProgress(
        pagesDone: done,
        pagesTotal: total,
        phase: phase,
        paused: reason,
      ));
      if (isCancelled?.call() ?? false) return false;
      await Future<void>.delayed(pollInterval);
    }
  }

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
  /// exception is [AiModelNotReadyException]: with no model installed every
  /// remaining page would fail identically, so the run stops and says so rather
  /// than grinding through 40 guaranteed failures.
  ///
  /// [isCancelled] is polled between pages so closing the notebook or hitting
  /// Cancel stops the run at the next page boundary rather than mid-embed.
  Future<BulkIndexReport> indexPages({
    required int notebookId,
    required List<int> pageIds,
    void Function(BulkIndexProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) =>
      batchByModel
          ? _indexBatched(notebookId, pageIds, onProgress, isCancelled)
          : _indexOneByOne(notebookId, pageIds, onProgress, isCancelled);

  /// Two passes: all the vision reads, then all the embedding.
  ///
  /// Alternating the models page by page meant Gemma and the embedder were both
  /// resident for the whole run, each page paying for a read and then an
  /// embedding with the other model sitting loaded. Batched, the vision model is
  /// unloaded the moment the last read is done — before the embedder starts —
  /// and the heavy work is not interleaved with the light.
  ///
  /// A stop partway through the reads (cancel, or a model that is not
  /// installed) still embeds the pages ALREADY read: they cost almost nothing to
  /// embed, and throwing them away would make a stopped run worth less than the
  /// one-at-a-time loop's, which left every finished page searchable.
  Future<BulkIndexReport> _indexBatched(
    int notebookId,
    List<int> pageIds,
    void Function(BulkIndexProgress progress)? onProgress,
    bool Function()? isCancelled,
  ) async {
    final ready = _embedderReady;
    if (ready != null && !await ready()) {
      return const BulkIndexReport(stoppedModelNotReady: true);
    }

    final texts = <int, String>{}; // in page order
    final failed = <int>[];
    var stopped = false;
    var visionStopped = false;
    var cancelledWhileReading = false;

    void report(BulkIndexPhase phase, int done, int total) => onProgress?.call(
        BulkIndexProgress(pagesDone: done, pagesTotal: total, phase: phase));

    var done = 0;
    report(BulkIndexPhase.reading, 0, pageIds.length);
    for (final pageId in pageIds) {
      if (isCancelled?.call() ?? false) {
        cancelledWhileReading = true;
        break;
      }
      if (!await _waitForDevice(
        phase: BulkIndexPhase.reading,
        done: done,
        total: pageIds.length,
        onProgress: onProgress,
        isCancelled: isCancelled,
      )) {
        cancelledWhileReading = true;
        break;
      }
      try {
        final text = await _readPage(pageId);
        texts[pageId] = text;
        await _saveText(notebookId, pageId, text);
      } on AiModelNotReadyException {
        visionStopped = true;
        break;
      } catch (_) {
        failed.add(pageId);
      }
      done++;
      report(BulkIndexPhase.reading, done, pageIds.length);
    }

    // Nothing left for the vision model to do. Skipped when nothing was read:
    // there is then nothing it loaded for, and the idle timer will see to it.
    if (texts.isNotEmpty) {
      try {
        await _releaseVisionModel?.call();
      } catch (_) {
        // Memory housekeeping; the idle timer is the backstop.
      }
    }

    var indexed = 0, unchanged = 0, cleared = 0;
    done = 0;
    report(BulkIndexPhase.indexing, 0, texts.length);
    for (final entry in texts.entries) {
      // A cancel that already stopped the reads is not asked again: it is what
      // let the pages read so far be embedded rather than dropped.
      if (!cancelledWhileReading && (isCancelled?.call() ?? false)) break;
      try {
        switch (await _indexer.indexPage(
          notebookId: notebookId,
          pageId: entry.key,
          text: entry.value,
        )) {
          case RagIndexOutcome.indexed:
            indexed++;
          case RagIndexOutcome.unchanged:
            unchanged++;
          case RagIndexOutcome.cleared:
            cleared++;
        }
      } on AiModelNotReadyException {
        stopped = true;
        break;
      } catch (_) {
        failed.add(entry.key);
      }
      done++;
      report(BulkIndexPhase.indexing, done, texts.length);
    }

    return BulkIndexReport(
      indexed: indexed,
      unchanged: unchanged,
      cleared: cleared,
      failedPageIds: failed,
      stoppedModelNotReady: stopped || visionStopped,
      stoppedVisionNotReady: visionStopped,
    );
  }

  /// Persisting searchable text is a nicety on top of indexing and must never
  /// cost a page its index.
  Future<void> _saveText(int notebookId, int pageId, String text) async {
    try {
      await _onPageRead?.call(notebookId, pageId, text);
    } catch (_) {}
  }

  /// The original loop: each page read and embedded in turn.
  Future<BulkIndexReport> _indexOneByOne(
    int notebookId,
    List<int> pageIds,
    void Function(BulkIndexProgress progress)? onProgress,
    bool Function()? isCancelled,
  ) async {
    var indexed = 0, unchanged = 0, cleared = 0;
    final failed = <int>[];
    var done = 0;

    onProgress?.call(
        BulkIndexProgress(pagesDone: 0, pagesTotal: pageIds.length));

    for (final pageId in pageIds) {
      if (isCancelled?.call() ?? false) break;
      if (!await _waitForDevice(
        phase: BulkIndexPhase.combined,
        done: done,
        total: pageIds.length,
        onProgress: onProgress,
        isCancelled: isCancelled,
      )) {
        break;
      }
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
