// Composes the summarization pipeline:
//   recognize → meaningfulness gate → cache check → route → LLM → cache save.
//
// Privacy invariant: note text reaches CloudLlmClient only when the router
// returned AiRoute.cloud, which requires the user's explicit cloud opt-in.

import '../../../editor/domain/models/stroke.dart';
import '../../data/cache/summary_cache.dart';
import '../../data/cache/summary_store.dart';
import '../../data/llm/cloud_llm_client.dart';
import '../../data/llm/llm_exceptions.dart';
import '../../data/llm/local_llm_service.dart';
import 'ai_router.dart';
import 'handwriting_recognition_service.dart';
import 'meaningfulness_gate.dart';

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

/// The gate rejected the recognized text — never sent to any LLM.
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

  final HandwritingRecognitionService _recognition;
  final AiRouter _router;
  final LocalLlmService _localLlm;
  final CloudLlmClient _cloud;
  final SummaryStore _store;
  final String _localModelLabel;

  SummarizationService({
    required HandwritingRecognitionService recognition,
    required AiRouter router,
    required LocalLlmService localLlm,
    required CloudLlmClient cloud,
    required SummaryStore store,
    String localModelLabel = 'gemma4-e2b-local',
  })  : _recognition = recognition,
        _router = router,
        _localLlm = localLlm,
        _cloud = cloud,
        _store = store,
        _localModelLabel = localModelLabel;

  /// Summarizes a notebook. [pagesStrokes] must be in page order.
  ///
  /// Throws [NotMeaningfulException] (gate), [LocalModelRequiredException]
  /// (model missing), or the [LlmException] subtypes from the local runtime.
  Future<SummarizationResult> summarize({
    required int notebookId,
    required List<List<Stroke>> pagesStrokes,
    required String languageCode,
    required bool cloudEnabled,
    void Function(SummarizeStage stage)? onStage,
  }) async {
    onStage?.call(SummarizeStage.recognizing);
    final outcome =
        await _recognition.recognizeNotebook(pagesStrokes, languageCode);
    if (!outcome.gate.passed) {
      throw NotMeaningfulException(outcome.gate.failure!);
    }
    final text = outcome.text;

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

  Future<(String, bool)> _generateLocally(String text) async {
    final truncatedText = truncateToWords(text, AiRouter.localInputWordBudget);
    final wasTruncated = truncatedText.length != text.length;
    try {
      final summary = await _localLlm.generateOnce(
        prompt: '$_instruction\n\nNOTE:\n$truncatedText\n\nSUMMARY:',
      );
      return (summary, wasTruncated);
    } on LlmNotReadyException {
      // Model vanished between routing and generation (e.g. deleted in
      // settings) — surface the same actionable state as the router would.
      throw LocalModelRequiredException(offline: false);
    }
  }

  static final RegExp _whitespace = RegExp(r'\s+');

  static int countWords(String text) =>
      text.trim().isEmpty ? 0 : text.trim().split(_whitespace).length;

  /// Keeps the first [maxWords] words (page order preserved by construction).
  static String truncateToWords(String text, int maxWords) {
    final words = text.trim().split(_whitespace);
    if (words.length <= maxWords) return text;
    return words.take(maxWords).join(' ');
  }
}
