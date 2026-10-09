// The shadow re-index's indexing job, over the notebooks' pages (docs/TECH_MIGRATION_PLAN.md,
// phase 4.5). Every page with text is brought current for the target model, with the
// same indexer the app uses when a page is edited.

import '../device_state.dart' show PauseReason;
import 'embedder_rollout_runner.dart';
import 'rag_indexer.dart';
import 'text_embedder.dart';

/// A page with text, as the rollout reads it.
class RolloutPage {
  const RolloutPage({
    required this.notebookId,
    required this.pageId,
    required this.text,
  });

  final int notebookId;
  final int pageId;
  final String text;
}

class NotebookRolloutIndex implements RolloutIndex {
  NotebookRolloutIndex({
    required this.pages,
    required this.indexerFor,
    this.pauseReason,
    this.pauseCheckEvery = const Duration(seconds: 30),
  });

  /// Every page with text, across every notebook.
  final Future<List<RolloutPage>> Function() pages;

  /// The indexer for a target model.
  final RagIndexer Function(TextEmbedder target) indexerFor;

  /// Why indexing should wait (hot, low battery), or null to carry on.
  final Future<PauseReason?> Function()? pauseReason;
  final Duration pauseCheckEvery;

  @override
  Future<int> indexablePages() async => (await pages()).length;

  @override
  Future<int> pendingPages(TextEmbedder target) async {
    final indexer = indexerFor(target);
    var pending = 0;
    for (final page in await pages()) {
      final current = await indexer.isCurrent(
        notebookId: page.notebookId,
        pageId: page.pageId,
        text: page.text,
      );
      if (!current) pending++;
    }
    return pending;
  }

  /// A page that fails is skipped and left pending, so one bad page cannot stop
  /// the rest; the runner's no-progress check still stops a pass where every page
  /// fails (a missing model, say).
  @override
  Future<void> indexPending(TextEmbedder target) async {
    final indexer = indexerFor(target);
    for (final page in await pages()) {
      while (await pauseReason?.call() != null) {
        await Future<void>.delayed(pauseCheckEvery);
      }
      try {
        await indexer.indexPage(
          notebookId: page.notebookId,
          pageId: page.pageId,
          text: page.text,
        );
      } catch (_) {
        continue;
      }
    }
  }
}
