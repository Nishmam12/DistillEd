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

class SummarizationResult {
  final String summary;
  final String recognizedText;
  final bool fromCache;
  final String modelUsed;

  /// Input exceeded the local budget and was truncated before prompting.
  final bool truncated;

  /// The cloud route failed and the local model produced the summary instead.
  final bool cloudFellBack;

  const SummarizationResult({
    required this.summary,
    required this.recognizedText,
    required this.modelUsed,
    this.fromCache = false,
    this.truncated = false,
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

  /// Summarizes a notebook. [pageIds] must be in page order; each page is
  /// read through the platform extractor, so both handwritten ink and typed
  /// text contribute.
  ///
  /// Throws [NotMeaningfulException] (gate), [LocalModelRequiredException]
  /// (model missing), or [SummarizeException] for generation failures.
  Future<SummarizationResult> summarize({
    required int notebookId,
    required List<int> pageIds,
    required String languageCode,
    required bool cloudEnabled,
    void Function(SummarizeStage stage)? onStage,
  }) async {
    onStage?.call(SummarizeStage.recognizing);

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

    final gate = _gate.evaluate(text, topScores: scores);
    if (!gate.passed) throw NotMeaningfulException(gate.failure!);

    // Unchanged note → instant cached summary.
    final hash = hashRecognizedText(text);
    final cached = await _store.find(notebookId);
    if (cached != null && cached.textHash == hash) {
      return SummarizationResult(
        summary: cached.summary,
        recognizedText: text,
        modelUsed: cached.modelUsed,
        fromCache: true,
      );
    }

    final decision = await _router.decide(
      inputWordCount: countWords(text),
      cloudEnabled: cloudEnabled,
    );

    String summary;
    String modelUsed;
    var truncated = false;
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
          (summary, truncated) = await _generateLocally(text);
          modelUsed = _localModelLabel;
          cloudFellBack = true;
        }

      case AiRoute.local:
        onStage?.call(SummarizeStage.summarizing);
        (summary, truncated) = await _generateLocally(text);
        modelUsed = _localModelLabel;
    }

    await _store.save(SummaryCache()
      ..notebookId = notebookId
      ..textHash = hash
      ..summary = summary
      ..modelUsed = modelUsed
      ..createdAt = DateTime.now());

    return SummarizationResult(
      summary: summary,
      recognizedText: text,
      modelUsed: modelUsed,
      truncated: truncated,
      cloudFellBack: cloudFellBack,
    );
  }

  /// Runs the local provider (defaults tuned for faithful summarization, not
  /// creative chat), translating platform failures into summarize-level ones.
  Future<(String, bool)> _generateLocally(String text) async {
    final truncatedText = truncateToWords(text, _router.localInputWordBudget);
    final wasTruncated = truncatedText.length != text.length;
    try {
      final chunks = await _local
          .generate(
            prompt: 'NOTE:\n$truncatedText',
            systemPrompt: _instruction,
            options: const AiGenerationOptions(
              temperature: 0.2,
              topP: 0.95,
              maxTokens: 512,
            ),
          )
          .toList();
      return (chunks.join().trim(), wasTruncated);
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
