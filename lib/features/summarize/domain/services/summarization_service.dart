// Composes the summarization pipeline on the AI platform:
//   extract pages → meaningfulness gate → cache check → route → generate →
//   cache save.
//
// Summarize is the first consumer of the shared platform (features/ai): page
// understanding comes from [PageContentExtractor] (recognized ink AND typed
// text), local generation from the [AiProvider] contract, routing from the
// capability-driven [AiRouter]. Nothing here talks to a model runtime
// directly.
//
// Privacy invariant: note text reaches [CloudLlmClient] only when the router
// returned [AiRoute.cloud], which requires the user's explicit cloud opt-in.

import '../../../ai/data/llm/cloud_llm_client.dart';
import '../../../ai/domain/ai_provider.dart';
import '../../../ai/domain/ai_router.dart';
import '../../../ai/domain/meaningfulness_gate.dart';
import '../../../ai/domain/page_content.dart';
import '../../../ai/domain/page_content_extractor.dart';
import '../../../ai/domain/text_budget.dart' as text_budget;
import '../../data/cache/summary_cache.dart';
import '../../data/cache/summary_store.dart';

enum SummarizeStage { recognizing, summarizing }

/// What a summarize request covers. Selection reads only the chosen elements on
/// one page; page reads one page; notebook reads every page in order. Scope
/// only changes what text is gathered — the gate, routing, chunk-and-reduce and
/// generation downstream are identical.
sealed class SummarizeScope {
  const SummarizeScope();
}

/// Just the selected elements on [pageId] (read-only consumer of the editor's
/// selection). Empty [elementIds] yields no text (the gate then rejects it).
class SelectionScope extends SummarizeScope {
  final int pageId;
  final Set<String> elementIds;
  const SelectionScope({required this.pageId, required this.elementIds});
}

/// One page.
class PageScope extends SummarizeScope {
  final int pageId;
  const PageScope(this.pageId);
}

/// The whole notebook — [pageIds] in page order.
class NotebookScope extends SummarizeScope {
  final List<int> pageIds;
  const NotebookScope(this.pageIds);
}

class SummarizationResult {
  final String summary;
  final String recognizedText;
  final bool fromCache;
  final String modelUsed;

  /// Input exceeded the local context window and was summarized in passes
  /// (chunk-and-reduce) instead of being truncated — the whole note was read.
  final bool chunked;

  /// The cloud route failed and the local model produced the summary instead.
  final bool cloudFellBack;

  const SummarizationResult({
    required this.summary,
    required this.recognizedText,
    required this.modelUsed,
    this.fromCache = false,
    this.chunked = false,
    this.cloudFellBack = false,
  });
}

/// Base type for defined (non-bug) summarization failures.
class SummarizeException implements Exception {
  final String message;
  final bool retryable;
  SummarizeException(this.message, {this.retryable = true});

  @override
  String toString() => '$runtimeType: $message';
}

/// The gate rejected the extracted text — never sent to any LLM.
class NotMeaningfulException extends SummarizeException {
  final GateFailure failure;
  NotMeaningfulException(this.failure)
      : super("Couldn't read this note clearly enough to summarize.",
            retryable: false);
}

/// The local model is required but not downloaded. When [offline] the user
/// must reconnect first (actionable error); otherwise the UI can offer the
/// download and retry.
class LocalModelRequiredException extends SummarizeException {
  final bool offline;
  LocalModelRequiredException({required this.offline})
      : super(offline
            ? 'The on-device model is not downloaded and you are offline. '
                'Connect to the internet to download it.'
            : 'The on-device model needs to be downloaded first.');
}

class SummarizationService {
  static const String _instruction =
      'You summarize handwritten notes. Write a faithful summary of the note '
      'in 3 to 6 sentences. Use only information present in the note — never '
      'invent facts, names, dates, or numbers. If parts of the note are '
      'unclear, summarize only what is clear.';

  /// Per-chunk pass of chunk-and-reduce: condense one section of a long note
  /// without losing the specifics later passes rely on.
  static const String _sectionInstruction =
      'You summarize one section of a longer handwritten note. Write a '
      'faithful, compact summary of just this section, keeping the key facts, '
      'names, and numbers. Use only what this section says — never invent '
      'anything.';

  /// Final reduce pass: fold the section summaries into one summary. The input
  /// is already summarized text, so it must not be summarized any further than
  /// the note itself would be.
  static const String _reduceInstruction =
      'You are given section summaries of a single handwritten note, in order. '
      'Combine them into one faithful summary of the whole note in 3 to 6 '
      'sentences. Use only information in the section summaries — never invent '
      'facts, names, dates, or numbers.';

  /// Cap on reduce recursion; a safety net for pathologically small context
  /// windows so chunk-and-reduce always terminates.
  static const int _maxReducePasses = 4;

  final PageContentExtractor _extractor;
  final MeaningfulnessGate _gate;
  final AiRouter _router;
  final AiProvider _local;
  final CloudLlmClient _cloud;
  final SummaryStore _store;
  final String _localModelLabel;

  SummarizationService({
    required PageContentExtractor extractor,
    required AiRouter router,
    required AiProvider local,
    required CloudLlmClient cloud,
    required SummaryStore store,
    MeaningfulnessGate gate = const MeaningfulnessGate(),
    String localModelLabel = 'gemma4-e2b-local',
  })  : _extractor = extractor,
        _gate = gate,
        _router = router,
        _local = local,
        _cloud = cloud,
        _store = store,
        _localModelLabel = localModelLabel;

  /// Summarizes a whole notebook. [pageIds] must be in page order. Kept as the
  /// notebook entry point (the app-bar Summarize action); delegates to
  /// [summarizeScope] with a [NotebookScope].
  Future<SummarizationResult> summarize({
    required int notebookId,
    required List<int> pageIds,
    required String languageCode,
    required bool cloudEnabled,
    void Function(SummarizeStage stage)? onStage,
  }) {
    return summarizeScope(
      notebookId: notebookId,
      scope: NotebookScope(pageIds),
      languageCode: languageCode,
      cloudEnabled: cloudEnabled,
      onStage: onStage,
    );
  }

  /// Summarizes [scope] — a selection, one page, or the whole notebook. Each
  /// source page is read through the platform extractor, so both handwritten
  /// ink and typed text contribute. Content that exceeds the local context
  /// window is chunk-and-reduced (summarize sections, then summarize the
  /// section summaries), never silently truncated.
  ///
  /// The persistent cache is notebook-level: only [NotebookScope] reads and
  /// writes it (a page or selection summary must not collide with the
  /// notebook's cached summary).
  ///
  /// Throws [NotMeaningfulException] (gate), [LocalModelRequiredException]
  /// (model missing), or [SummarizeException] for generation failures.
  Future<SummarizationResult> summarizeScope({
    required int notebookId,
    required SummarizeScope scope,
    required String languageCode,
    required bool cloudEnabled,
    void Function(SummarizeStage stage)? onStage,
  }) async {
    onStage?.call(SummarizeStage.recognizing);

    final (text, scores) = await _gather(scope, languageCode);

    final gate = _gate.evaluate(text, topScores: scores);
    if (!gate.passed) throw NotMeaningfulException(gate.failure!);

    // Unchanged notebook → instant cached summary. Only the notebook scope is
    // cached (one entry per notebook).
    final cacheable = scope is NotebookScope;
    final hash = hashRecognizedText(text);
    if (cacheable) {
      final cached = await _store.find(notebookId);
      if (cached != null && cached.textHash == hash) {
        return SummarizationResult(
          summary: cached.summary,
          recognizedText: text,
          modelUsed: cached.modelUsed,
          fromCache: true,
        );
      }
    }

    final decision = await _router.decide(
      inputWordCount: countWords(text),
      cloudEnabled: cloudEnabled,
    );

    String summary;
    String modelUsed;
    var chunked = false;
    var cloudFellBack = false;

    switch (decision.route) {
      case AiRoute.errorOfflineNoModel:
        throw LocalModelRequiredException(offline: true);

      case AiRoute.downloadThenLocal:
        throw LocalModelRequiredException(offline: false);

      case AiRoute.cloud:
        onStage?.call(SummarizeStage.summarizing);
        try {
          summary = await _cloud.chatCompletion(messages: [
            const ChatMessage.system(_instruction),
            ChatMessage.user('NOTE:\n$text'),
          ]);
          modelUsed = 'cloud';
        } on CloudUnavailableException {
          // Cloud tier is a stub / unreachable — degrade to local.
          (summary, chunked) = await _generateLocally(text);
          modelUsed = _localModelLabel;
          cloudFellBack = true;
        }

      case AiRoute.local:
        onStage?.call(SummarizeStage.summarizing);
        (summary, chunked) = await _generateLocally(text);
        modelUsed = _localModelLabel;
    }

    if (cacheable) {
      await _store.save(SummaryCache()
        ..notebookId = notebookId
        ..textHash = hash
        ..summary = summary
        ..modelUsed = modelUsed
        ..createdAt = DateTime.now());
    }

    return SummarizationResult(
      summary: summary,
      recognizedText: text,
      modelUsed: modelUsed,
      chunked: chunked,
      cloudFellBack: cloudFellBack,
    );
  }

  /// Resolves a scope to its combined text and the ink confidence scores that
  /// feed the meaningfulness gate.
  Future<(String, List<double>)> _gather(
    SummarizeScope scope,
    String languageCode,
  ) async {
    switch (scope) {
      case NotebookScope(:final pageIds):
        final pages = <PageContent>[];
        for (final pageId in pageIds) {
          pages.add(
              await _extractor.extractPage(pageId, languageCode: languageCode));
        }
        final text = pages
            .map((p) => p.combinedText)
            .where((t) => t.isNotEmpty)
            .join('\n\n');
        final scores = [
          for (final p in pages)
            if (p.inkTopScore != null) p.inkTopScore!,
        ];
        return (text, scores);

      case PageScope(:final pageId):
        final page =
            await _extractor.extractPage(pageId, languageCode: languageCode);
        return _single(page);

      case SelectionScope(:final pageId, :final elementIds):
        final page = await _extractor.extractSelection(pageId, elementIds,
            languageCode: languageCode);
        return _single(page);
    }
  }

  static (String, List<double>) _single(PageContent page) => (
        page.combinedText,
        [if (page.inkTopScore != null) page.inkTopScore!],
      );

  /// Summarizes [text] locally. When it fits the local budget this is one
  /// faithful pass; when it exceeds the local context window it is
  /// chunk-and-reduced. Returns the summary and whether reduction ran.
  Future<(String, bool)> _generateLocally(String text) async {
    if (countWords(text) <= _router.localInputWordBudget) {
      return (await _summarizeOnce(text, _instruction), false);
    }
    return (
      await _chunkAndReduce(text, _router.localInputWordBudget),
      true,
    );
  }

  /// Summarizes over-budget [text] in passes: summarize each section that fits
  /// [budget], then summarize the joined section summaries — recursing while
  /// even the summaries overflow, with a hard pass cap so it always terminates.
  Future<String> _chunkAndReduce(String text, int budget, {int pass = 0}) async {
    final sections = text_budget.chunkByWords(text, budget);
    if (sections.length <= 1) {
      return _summarizeOnce(sections.isEmpty ? text : sections.first,
          _reduceInstruction);
    }

    final partials = <String>[];
    for (final section in sections) {
      partials.add(await _summarizeOnce(section, _sectionInstruction));
    }
    final combined = partials.join('\n\n');

    if (countWords(combined) <= budget) {
      return _summarizeOnce(combined, _reduceInstruction);
    }
    if (pass + 1 >= _maxReducePasses) {
      // Safety net for a tiny context window: stop recursing and reduce the
      // (necessarily truncated) combined summaries in one final pass.
      return _summarizeOnce(
          text_budget.truncateToWords(combined, budget), _reduceInstruction);
    }
    return _chunkAndReduce(combined, budget, pass: pass + 1);
  }

  /// One local generation pass (defaults tuned for faithful summarization, not
  /// creative chat), translating platform failures into summarize-level ones.
  Future<String> _summarizeOnce(String text, String instruction) async {
    try {
      final chunks = await _local
          .generate(
            prompt: 'NOTE:\n$text',
            systemPrompt: instruction,
            options: const AiGenerationOptions(
              temperature: 0.2,
              topP: 0.95,
              maxTokens: 512,
            ),
          )
          .toList();
      return chunks.join().trim();
    } on AiModelNotReadyException {
      // Model vanished between routing and generation (e.g. deleted in
      // settings) — surface the same actionable state as the router would.
      throw LocalModelRequiredException(offline: false);
    } on AiException catch (e) {
      throw SummarizeException(e.message);
    }
  }

  // Word budgeting shared with the rest of the platform (text_budget.dart);
  // kept as statics here because they are part of this service's tested API.
  static int countWords(String text) => text_budget.countWords(text);

  /// Keeps the first [maxWords] words (page order preserved by construction).
  static String truncateToWords(String text, int maxWords) =>
      text_budget.truncateToWords(text, maxWords);
}
