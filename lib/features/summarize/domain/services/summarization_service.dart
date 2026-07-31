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
import '../../../ai/domain/quality/ai_quality_guard.dart';
import '../../../ai/domain/text_budget.dart' as text_budget;
import '../../../ai/domain/tutor_voice.dart';
import '../../data/cache/summary_cache.dart';
import '../../data/cache/summary_store.dart';

enum SummarizeStage { recognizing, summarizing }

/// What a summarize request covers. Selection reads only the chosen elements on
/// one page; page reads one page; an import group reads every page of one
/// imported document; notebook reads every page in order. Scope only changes
/// what text is gathered — the gate, routing, chunk-and-reduce and generation
/// downstream are identical.
///
/// These mirror [AiScopeKind] (features/ai/domain/ai_scope.dart), which is the
/// shared definition every AI surface scopes by. They stay a separate sealed
/// type here because a summarize scope also carries the SELECTION, which is an
/// editor concept the AI platform has no business knowing about — the editor
/// resolves an [AiScope] to page ids and hands them over below.
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

/// Every page of one imported document — [pageIds] in page order.
///
/// Distinct from [NotebookScope] even though both are "a list of pages": a
/// notebook summary is cached (one per notebook) and a PDF summary is not, and
/// the two must never share that cache entry or a student who summarized their
/// lecture PDF would be shown it again as the summary of the whole notebook.
class ImportGroupScope extends SummarizeScope {
  final List<int> pageIds;

  /// The import these pages came from — carried for the cache key discussion
  /// above and so the UI can name the document.
  final String importGroupId;
  const ImportGroupScope(this.pageIds, {required this.importGroupId});
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

  /// Which tier the student is reading, per the accuracy fail-safe.
  /// [AnswerTier.localLowConfidence] means the on-device model produced
  /// something the quality check rejected and no cloud run was permitted; the
  /// sheet must warn rather than present it as a reliable recap.
  final AnswerTier tier;

  const SummarizationResult({
    required this.summary,
    required this.recognizedText,
    required this.modelUsed,
    this.fromCache = false,
    this.chunked = false,
    this.cloudFellBack = false,
    this.tier = AnswerTier.local,
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
  /// The voice contract, shared by every summarization pass.
  ///
  /// Small on-device models default to an assistant register: they open with a
  /// preamble ("Here is a summary of your note:"), narrate the document
  /// ("the note discusses…", "the author mentions…"), and close by offering
  /// more help. That reads as a chatbot reporting on a file rather than a tutor
  /// recapping the material, so the register is pinned explicitly here instead
  /// of being left to the model's default. Matches the tutor voice [Explainer]
  /// establishes for explanations.
  static const String _voice =
      'You are a tutor recapping a student\'s handwritten notes with them, out '
      'loud, the way you would at the end of a session.\n\n'
      '$kTutorVoiceWithMath\n\n'
      'Two things specific to a recap: speak about the material itself, not '
      'about the note as a document — say "photosynthesis converts light into '
      'sugar", never "the note explains that photosynthesis…" or "the student '
      'writes about…". And start straight in on the content: no "here is a '
      'summary", no title, no heading. A recap is not the place to check '
      'understanding with a question; just tell them what the material said.';

  /// The single-pass instruction. Public for the same reason [NotesQa.systemPrompt]
  /// and [Explainer.systemPromptFor] are: a prompt is behaviour, and the tests
  /// that pin the tutor voice and the faithfulness rules have to be able to
  /// read it.
  static const String noteInstruction = '$_voice\n\n'
      'Recap the note below in 3 to 6 sentences, keeping what a student would '
      'need for revision: the key ideas, and the names, dates and numbers that '
      'carry them. Use only information present in the note — never invent '
      'facts, names, dates, or numbers. If parts of the note are unclear, '
      'cover only what is clear, without remarking on the gaps.\n\n$_figureRule';

  /// How to treat the `[Figure N — kind: title]` blocks [PageContent] appends.
  ///
  /// Without this the model does one of two wrong things with them: quotes the
  /// scaffolding back verbatim ("Figure 1 — chart shows…"), or ignores them as
  /// metadata. Both lose the graph the student drew, which is the entire point
  /// of reading it. Shared by every pass so a chunked summary treats figures
  /// the same way a single-pass one does.
  static const String _figureRule =
      'Blocks marked [Figure …] are charts, diagrams or tables from the page, '
      'described for you because they are pictures rather than writing. Treat '
      'what they say as part of the note and fold it into the recap in your own '
      'words — a trend, a relationship, a process. Never write "Figure 1", '
      '"the figure shows", "the diagram", or "the chart"; say what it means '
      'instead, the way you would if the student had written it in a sentence.';

  /// Per-chunk pass of chunk-and-reduce: condense one section of a long note
  /// without losing the specifics later passes rely on.
  static const String sectionInstruction = '$_voice\n\n'
      'The text below is one section of a longer note. Recap just this section, '
      'compactly, keeping its key facts, names, and numbers — later passes '
      'depend on those specifics surviving. Use only what this section says — '
      'never invent anything.\n\n$_figureRule';

  /// Final reduce pass: fold the section summaries into one summary. The input
  /// is already summarized text, so it must not be summarized any further than
  /// the note itself would be.
  static const String reduceInstruction = '$_voice\n\n'
      'The text below is section-by-section recaps of a single note, in order. '
      'Draw them together into one recap of the whole note in 3 to 6 '
      'sentences, and do not mention that it came in sections. Use only '
      'information in those recaps — never invent facts, names, dates, or '
      'numbers.';

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

  /// The accuracy fail-safe, applied to the FINAL summary pass.
  ///
  /// Only the final pass, deliberately. Chunk-and-reduce's intermediate section
  /// summaries are never shown to anyone — escalating one of those to the cloud
  /// would spend a network call on text that exists only to be summarized again,
  /// while a broken section still shows up as a broken final summary and gets
  /// caught there. Null keeps the pre-guard behaviour exactly.
  final AiQualityGuard? _guard;

  /// Whether pages are read with the VLM (charts and diagrams understood) or on
  /// the light ML Kit path. On by default — a summary that silently drops the
  /// graph on the page is the bug this exists to fix. Off is an escape hatch
  /// for tests and for low-end devices where the extra per-visual model pass is
  /// too slow.
  final bool _visionEnabled;

  SummarizationService({
    required PageContentExtractor extractor,
    required AiRouter router,
    required AiProvider local,
    required CloudLlmClient cloud,
    required SummaryStore store,
    MeaningfulnessGate gate = const MeaningfulnessGate(),
    String localModelLabel = 'gemma4-e2b-local',
    bool visionEnabled = true,
    AiQualityGuard? guard,
  })  : _guard = guard,
        _extractor = extractor,
        _gate = gate,
        _router = router,
        _local = local,
        _cloud = cloud,
        _store = store,
        _localModelLabel = localModelLabel,
        _visionEnabled = visionEnabled;

  /// Summarizes a whole notebook. [pageIds] must be in page order. Kept as the
  /// notebook entry point (the app-bar Summarize action); delegates to
  /// [summarizeScope] with a [NotebookScope].
  Future<SummarizationResult> summarize({
    required int notebookId,
    required List<int> pageIds,
    required String languageCode,
    required bool cloudEnabled,
    bool preferCloud = false,
    void Function(SummarizeStage stage)? onStage,
  }) {
    return summarizeScope(
      notebookId: notebookId,
      scope: NotebookScope(pageIds),
      languageCode: languageCode,
      cloudEnabled: cloudEnabled,
      preferCloud: preferCloud,
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
    bool preferCloud = false,
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
      preferCloud: preferCloud,
    );

    String summary;
    String modelUsed;
    var chunked = false;
    var cloudFellBack = false;
    var tier = AnswerTier.local;

    switch (decision.route) {
      case AiRoute.errorOfflineNoModel:
        throw LocalModelRequiredException(offline: true);

      case AiRoute.downloadThenLocal:
        throw LocalModelRequiredException(offline: false);

      case AiRoute.cloud:
        onStage?.call(SummarizeStage.summarizing);
        try {
          summary = await _cloud.chatCompletion(messages: [
            const ChatMessage.system(noteInstruction),
            ChatMessage.user('NOTE:\n$text'),
          ]);
          modelUsed = 'cloud';
        } on CloudUnavailableException {
          // Cloud tier is a stub / unreachable — degrade to local.
          (summary, chunked, tier) = await _generateLocally(text);
          modelUsed = _localModelLabel;
          cloudFellBack = true;
        }

      case AiRoute.local:
        onStage?.call(SummarizeStage.summarizing);
        (summary, chunked, tier) = await _generateLocally(text);
        modelUsed = tier == AnswerTier.cloudVerified ? 'cloud' : _localModelLabel;
    }

    // A low-confidence summary is deliberately NOT cached: caching it would
    // pin the bad recap to the notebook until its text changed, and the student
    // would see it again on every open with no way to ask for another try.
    if (cacheable && tier != AnswerTier.localLowConfidence) {
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
      tier: tier,
    );
  }

  /// Resolves a scope to its combined text and the ink confidence scores that
  /// feed the meaningfulness gate.
  ///
  /// Reads with vision on ([_visionEnabled]), so a page's charts and diagrams
  /// arrive as described figures rather than as a handful of stray axis labels.
  /// That costs an extra VLM pass per visual — accepted here because summarize
  /// is an explicit, user-initiated action, unlike the passive Context Engine
  /// loop which stays on the light path between deep reads.
  Future<(String, List<double>)> _gather(
    SummarizeScope scope,
    String languageCode,
  ) async {
    final vision = _visionEnabled;
    switch (scope) {
      case NotebookScope(:final pageIds):
        return _gatherPages(pageIds, languageCode, vision);

      case ImportGroupScope(:final pageIds):
        return _gatherPages(pageIds, languageCode, vision);

      case PageScope(:final pageId):
        final page = await _extractor.extractPage(pageId,
            languageCode: languageCode, useVision: vision);
        return _single(page);

      case SelectionScope(:final pageId, :final elementIds):
        final page = await _extractor.extractSelection(pageId, elementIds,
            languageCode: languageCode, useVision: vision);
        return _single(page);
    }
  }

  /// Reads several pages in order and joins them into one body of text.
  /// Shared by the notebook and import-group scopes, which differ only in which
  /// pages they name.
  Future<(String, List<double>)> _gatherPages(
    List<int> pageIds,
    String languageCode,
    bool vision,
  ) async {
    final pages = <PageContent>[];
    for (final pageId in pageIds) {
      pages.add(await _extractor.extractPage(pageId,
          languageCode: languageCode, useVision: vision));
    }
    final text = pages
        .map((p) => p.combinedTextWithFigures)
        .where((t) => t.isNotEmpty)
        .join('\n\n');
    final scores = [
      for (final p in pages)
        if (p.inkTopScore != null) p.inkTopScore!,
    ];
    return (text, scores);
  }

  /// Figures are included in the gated/summarized text — a page whose only
  /// content is a hand-drawn graph has almost no words, and gating on
  /// [PageContent.combinedText] alone is exactly why such a page used to be
  /// rejected as "not meaningful" instead of summarized.
  static (String, List<double>) _single(PageContent page) => (
        page.combinedTextWithFigures,
        [if (page.inkTopScore != null) page.inkTopScore!],
      );

  /// Summarizes [text] locally. When it fits the local budget this is one
  /// faithful pass; when it exceeds the local context window it is
  /// chunk-and-reduced. Returns the summary and whether reduction ran.
  Future<(String, bool, AnswerTier)> _generateLocally(String text) async {
    if (countWords(text) <= _router.localInputWordBudget) {
      final result = await _guarded(text, noteInstruction);
      return (result.text.trim(), false, result.tier);
    }
    // The reduce pass IS the final pass, so the guard runs there (see [_guard]).
    final result = await _chunkAndReduce(text, _router.localInputWordBudget);
    return (result.text.trim(), true, result.tier);
  }

  /// One pass through the accuracy fail-safe, or a plain local pass when no
  /// guard is wired.
  ///
  /// A summary is checked as UNGROUNDED output: it is a recap of the note it
  /// was given, not an answer assembled from retrieved passages, so only the
  /// broken-output checks (empty, looping, degenerate) apply. Requiring
  /// vocabulary overlap with the source would punish exactly the paraphrasing a
  /// good recap does.
  Future<GuardedResult> _guarded(String text, String instruction) async {
    final guard = _guard;
    if (guard == null) {
      return GuardedResult(
        text: await _summarizeOnce(text, instruction),
        tier: AnswerTier.local,
      );
    }
    try {
      return await guard.run(
        prompt: 'NOTE:\n$text',
        systemPrompt: instruction,
        options: _summarizeOptions,
      );
    } on AiModelNotReadyException {
      throw LocalModelRequiredException(offline: false);
    } on AiException catch (e) {
      throw SummarizeException(e.message);
    }
  }

  /// Summarizes over-budget [text] in passes: summarize each section that fits
  /// [budget], then summarize the joined section summaries — recursing while
  /// even the summaries overflow, with a hard pass cap so it always terminates.
  Future<GuardedResult> _chunkAndReduce(String text, int budget,
      {int pass = 0}) async {
    final sections = text_budget.chunkByWords(text, budget);
    if (sections.length <= 1) {
      return _guarded(
          sections.isEmpty ? text : sections.first, reduceInstruction);
    }

    final partials = <String>[];
    for (final section in sections) {
      // Intermediate passes stay unguarded — see [_guard].
      partials.add(await _summarizeOnce(section, sectionInstruction));
    }
    final combined = partials.join('\n\n');

    if (countWords(combined) <= budget) {
      return _guarded(combined, reduceInstruction);
    }
    if (pass + 1 >= _maxReducePasses) {
      // Safety net for a tiny context window: stop recursing and reduce the
      // (necessarily truncated) combined summaries in one final pass.
      return _guarded(
          text_budget.truncateToWords(combined, budget), reduceInstruction);
    }
    return _chunkAndReduce(combined, budget, pass: pass + 1);
  }

  /// One local generation pass (defaults tuned for faithful summarization, not
  /// creative chat), translating platform failures into summarize-level ones.
  /// Sampling for a summarization pass — a constant so the guard's cloud re-run
  /// asks for the same thing the local pass was asked for.
  static const AiGenerationOptions _summarizeOptions = AiGenerationOptions(
    temperature: 0.2,
    topP: 0.95,
    maxTokens: 512,
  );

  Future<String> _summarizeOnce(String text, String instruction) async {
    try {
      final chunks = await _local
          .generate(
            prompt: 'NOTE:\n$text',
            systemPrompt: instruction,
            options: _summarizeOptions,
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
