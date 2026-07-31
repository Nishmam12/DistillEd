// Drives one "Ask your notes" query into the sidebar:
//   idle → searching → answering(partial, sources) → answered(full, sources)
//            ↘ notFound (retrieval found nothing relevant)
//            ↘ downloadingModel(progress) → (re-run) …
//            ↘ error(message, retryable, offerModelDownload)
//
// Two model-bearing steps run in sequence: EmbeddingGemma retrieves, then the
// LLM answers. Either can need a download, and both surface it as the same
// explicit offer rather than a silent fetch. The question is held so a retry or
// a model-download re-runs the whole thing.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/embeddings/embedder_download_manager.dart';
import '../data/llm/llm_exceptions.dart';
import '../data/llm/model_download_manager.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_scope.dart';
import '../domain/chat_commands.dart';
import '../domain/features/notes_qa.dart';
import '../domain/quality/ai_quality_guard.dart';
import '../domain/rag/rag_retriever.dart';

sealed class AskNotesState {
  const AskNotesState();
}

class AskNotesIdle extends AskNotesState {
  const AskNotesIdle();
}

/// The query box is open and awaiting a question (nothing asked yet). A state,
/// not a UI flag, so the sidebar's single body-swap ("ask surface active?")
/// keys off `state is! AskNotesIdle` like Explain does.
class AskNotesComposing extends AskNotesState {
  const AskNotesComposing();
}

/// Retrieving relevant passages (the embedding step).
class AskNotesSearching extends AskNotesState {
  final String question;

  /// What the search was allowed to read. Carried through every answering
  /// state so the UI can always show it — an answer scoped to one page and an
  /// answer scoped to the whole notebook look identical otherwise, and the
  /// difference is exactly what a "not found" hinges on.
  final AiScope? scope;
  const AskNotesSearching(this.question, {this.scope});
}

class AskNotesAnswering extends AskNotesState {
  final String question;
  final String text;
  final List<RetrievedChunk> sources;
  final AiScope? scope;
  const AskNotesAnswering(this.question, this.text, this.sources, {this.scope});
}

class AskNotesAnswered extends AskNotesState {
  final String question;
  final String text;
  final List<RetrievedChunk> sources;
  final AiScope? scope;

  /// Which model produced this, and whether it can be trusted at face value.
  /// The UI must show a cloud badge for [AnswerTier.cloudVerified] and a
  /// warning for [AnswerTier.localLowConfidence] — a possibly-wrong answer
  /// presented as settled fact is the failure the guard exists to prevent.
  final AnswerTier tier;

  /// The local answer failed its quality check and the cloud could re-run it,
  /// but the user's `askEachTime` privacy setting means they must say so first.
  final bool canRetryOnCloud;

  const AskNotesAnswered(
    this.question,
    this.text,
    this.sources, {
    this.scope,
    this.tier = AnswerTier.local,
    this.canRetryOnCloud = false,
  });
}

/// Retrieval returned nothing relevant — a grounded "not in your notes". Not an
/// error: the feature worked, the notes just don't cover it (or aren't indexed
/// yet). Distinct so the UI can nudge toward downloading/indexing when apt.
class AskNotesNotFound extends AskNotesState {
  final String question;
  final AiScope? scope;
  const AskNotesNotFound(this.question, {this.scope});
}

/// A short app-level reply to a typed command (`/cloud on`), shown in place of
/// an answer.
///
/// Its own state rather than a snackbar: the student typed into this box and
/// should get the reply in this box, and the composer stays open underneath so
/// the next thing they type is their actual question.
class AskNotesNotice extends AskNotesState {
  final String message;
  const AskNotesNotice(this.message);
}

/// Downloading one of the two models. [isEmbedder] picks the message
/// ("search model" vs "answer model") so the user knows what they're waiting on.
class AskNotesDownloadingModel extends AskNotesState {
  final int progress; // 0–100
  final bool isEmbedder;
  const AskNotesDownloadingModel(this.progress, {required this.isEmbedder});
}

class AskNotesError extends AskNotesState {
  final String message;
  final bool retryable;
  final bool offerModelDownload;

  /// Which model the offered download refers to, when [offerModelDownload].
  final bool downloadIsEmbedder;
  const AskNotesError(
    this.message, {
    this.retryable = true,
    this.offerModelDownload = false,
    this.downloadIsEmbedder = false,
  });
}

class AskNotesNotifier extends StateNotifier<AskNotesState> {
  final NotesQa _qa;
  final ModelDownloadManager _llmDownloads;
  final EmbedderDownloadManager _embedderDownloads;

  /// The accuracy fail-safe. Optional so existing callers and tests keep the
  /// plain local stream; when it is wired, every answer goes through the
  /// quality check and may be escalated to the cloud tier.
  final AiQualityGuard? _guard;

  /// Reads and writes the SAME `cloudAiEnabled` setting the sidebar's switch
  /// and the Settings screen use, so `/cloud on` and the toggle can never
  /// disagree — there is one stored value and three ways to reach it.
  final bool Function()? _cloudEnabled;
  final Future<void> Function(bool enabled)? _setCloudEnabled;
  final bool Function()? _privacyAsksEachTime;

  AskNotesNotifier({
    required NotesQa qa,
    required ModelDownloadManager llmDownloads,
    required EmbedderDownloadManager embedderDownloads,
    AiQualityGuard? guard,
    bool Function()? cloudEnabled,
    Future<void> Function(bool enabled)? setCloudEnabled,
    bool Function()? privacyAsksEachTime,
  })  : _qa = qa,
        _llmDownloads = llmDownloads,
        _embedderDownloads = embedderDownloads,
        _guard = guard,
        _cloudEnabled = cloudEnabled,
        _setCloudEnabled = setCloudEnabled,
        _privacyAsksEachTime = privacyAsksEachTime,
        super(const AskNotesIdle());

  String? _lastQuestion;
  int? _lastNotebookId;
  AiScope? _lastScope;
  bool _running = false;

  /// Opens the query box (footer "Ask" chip). No-op mid-run.
  void startComposing() {
    if (!_running) state = const AskNotesComposing();
  }

  /// [notebookId] is passed per-call (not held in the provider) so this notifier
  /// stays a plain session-scoped provider like Explain/Quiz, rather than a
  /// per-notebook family.
  ///
  /// [scope] limits which pages may be retrieved from — this page, this
  /// imported PDF, or the whole notebook (see `domain/ai_scope.dart`). Null
  /// searches the whole notebook, which is what this did before scopes existed.
  /// It is held with the question so a retry, or a re-run after a model
  /// download, searches the same pages rather than quietly widening.
  Future<void> ask(
    String question, {
    required int notebookId,
    AiScope? scope,
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _running) return;

    // Commands are intercepted BEFORE retrieval, so "/cloud on" never reaches
    // the model as a question about clouds.
    final command = parseChatCommand(trimmed);
    if (command != null) {
      await _handleCommand(command);
      return;
    }

    _lastQuestion = trimmed;
    _lastNotebookId = notebookId;
    _lastScope = scope;
    _running = true;
    try {
      state = AskNotesSearching(trimmed, scope: scope);
      final sources = await _qa.findSources(
          question: trimmed, notebookId: notebookId, scope: scope);
      if (!mounted) return;
      if (sources.isEmpty) {
        // Grounded refusal decided WITHOUT the LLM — nothing to answer from.
        state = AskNotesNotFound(trimmed, scope: scope);
        return;
      }

      state = AskNotesAnswering(trimmed, '', sources, scope: scope);
      final answer = await _generate(trimmed, sources, scope);
      if (!mounted) return;

      final text = answer.text.trim();
      // The model may still conclude the passages don't answer it — honour that
      // as a not-found rather than showing a bare refusal next to source chips.
      if (text.isEmpty || _isRefusal(text)) {
        state = AskNotesNotFound(trimmed, scope: scope);
      } else {
        state = AskNotesAnswered(
          trimmed,
          text,
          sources,
          scope: scope,
          tier: answer.tier,
          canRetryOnCloud: answer.canRetryOnCloud,
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = _mapError(e);
    } finally {
      _running = false;
    }
  }

  /// Runs a typed app command and replies in the box.
  ///
  /// Toggling the setting is NOT the same as consenting to a cloud call: under
  /// `askEachTime` the per-request confirmation still applies, and the
  /// confirmation message says so rather than letting the student assume
  /// otherwise.
  Future<void> _handleCommand(ChatCommand command) async {
    switch (command) {
      case UnknownSlashCommand(:final raw):
        state = AskNotesNotice(
            "I don't know the command \"$raw\". Try /cloud on or /cloud off.");

      case CloudModelCommand(:final enable):
        final read = _cloudEnabled;
        final write = _setCloudEnabled;
        if (read == null || write == null) {
          state = const AskNotesNotice(
              'Cloud AI can be turned on from Settings.');
          return;
        }
        if (enable == null) {
          state = AskNotesNotice(cloudStateReport(enabled: read()));
          return;
        }
        await write(enable);
        if (!mounted) return;
        state = AskNotesNotice(cloudCommandConfirmation(
          enabled: enable,
          privacyAsksEachTime: _privacyAsksEachTime?.call() ?? false,
        ));
    }
  }

  /// One answer, guarded when a guard is wired and plain-local when it isn't.
  ///
  /// Streaming is preserved either way: partial text lands in
  /// [AskNotesAnswering] as it arrives, so the fail-safe costs nothing in
  /// perceived latency for the common case where the local answer is fine.
  Future<GuardedResult> _generate(
    String question,
    List<RetrievedChunk> sources,
    AiScope? scope,
  ) async {
    void onPartial(String partial) {
      if (mounted) {
        state = AskNotesAnswering(question, partial, sources, scope: scope);
      }
    }

    final guard = _guard;
    if (guard != null) {
      return guard.run(
        prompt: _qa.promptFor(question: question, sources: sources),
        systemPrompt: NotesQa.systemPrompt,
        options: NotesQa.answerOptions,
        quality: NotesQa.qualityContextFor(sources),
        onPartial: onPartial,
      );
    }

    final buffer = StringBuffer();
    await for (final chunk in _qa.answer(question: question, sources: sources)) {
      if (!mounted) break;
      buffer.write(chunk);
      onPartial(buffer.toString());
    }
    return GuardedResult(text: buffer.toString(), tier: AnswerTier.local);
  }

  /// Re-runs the current answer on the cloud tier, on an explicit user tap.
  ///
  /// This is the `askEachTime` half of the privacy contract: the guard refuses
  /// to escalate on its own under that setting, and this is what the button
  /// behind [AskNotesAnswered.canRetryOnCloud] calls. Nothing reaches the
  /// network until someone presses it.
  Future<void> verifyWithCloud() async {
    final current = state;
    final guard = _guard;
    if (guard == null || _running || current is! AskNotesAnswered) return;
    if (!current.canRetryOnCloud) return;

    _running = true;
    try {
      final result = await guard.retryOnCloud(
        prompt:
            _qa.promptFor(question: current.question, sources: current.sources),
        systemPrompt: NotesQa.systemPrompt,
        options: NotesQa.answerOptions,
        quality: NotesQa.qualityContextFor(current.sources),
        onPartial: (partial) {
          if (mounted) {
            state = AskNotesAnswering(
                current.question, partial, current.sources,
                scope: current.scope);
          }
        },
        localText: current.text,
      );
      if (!mounted) return;
      final text = result.text.trim();
      state = AskNotesAnswered(
        current.question,
        text.isEmpty ? current.text : text,
        current.sources,
        scope: current.scope,
        tier: result.tier,
      );
    } catch (e) {
      if (mounted) state = _mapError(e);
    } finally {
      _running = false;
    }
  }

  Future<void> retry() async {
    final q = _lastQuestion;
    final nb = _lastNotebookId;
    if (q != null && nb != null) {
      await ask(q, notebookId: nb, scope: _lastScope);
    }
  }

  /// Downloads whichever model the current error offered, then re-runs.
  Future<void> downloadModelAndRetry() async {
    final q = _lastQuestion;
    final nb = _lastNotebookId;
    final current = state;
    if (q == null || nb == null || _running || current is! AskNotesError) return;
    final embedder = current.downloadIsEmbedder;

    state = AskNotesDownloadingModel(0, isEmbedder: embedder);
    // The two managers share no supertype, so select their (identically-typed)
    // members rather than the managers themselves.
    final Stream<int> progress =
        embedder ? _embedderDownloads.progress : _llmDownloads.progress;
    final Future<void> Function() startDownload =
        embedder ? _embedderDownloads.download : _llmDownloads.download;
    final sub = progress.listen((p) {
      if (mounted && state is AskNotesDownloadingModel) {
        state = AskNotesDownloadingModel(p, isEmbedder: embedder);
      }
    });
    try {
      await startDownload();
    } catch (e) {
      if (mounted) state = _mapError(e);
      return;
    } finally {
      await sub.cancel();
    }
    if (!mounted) return;
    await ask(q, notebookId: nb, scope: _lastScope);
  }

  void cancelModelDownload() {
    _llmDownloads.cancelDownload();
    _embedderDownloads.cancelDownload();
  }

  /// Dismisses the answer and returns the sidebar to the live context.
  void reset() {
    if (!_running) state = const AskNotesIdle();
  }

  /// True when the model produced (essentially) the ordered refusal — matched
  /// leniently since models rarely echo a canned line byte-for-byte.
  static bool _isRefusal(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains("couldn't find") &&
        normalized.contains('your notes') &&
        text.length < NotesQa.notFoundReply.length + 40;
  }

  AskNotesState _mapError(Object e) {
    return switch (e) {
      // A missing embedder surfaces during retrieval; a missing LLM during the
      // answer. Both offer their own download.
      AiModelNotReadyException(:final message) =>
        _notReadyError(message),
      AiException(:final message) => AskNotesError(message),
      InsufficientStorageException(:final message) =>
        AskNotesError('Not enough storage for the model. $message'),
      // The input box keeps the typed question via its own controller, so a
      // cancel just returns to idle.
      ModelDownloadCancelledException _ => const AskNotesIdle(),
      LlmException(:final message) => AskNotesError(message),
      _ => const AskNotesError('Something went wrong answering that.'),
    };
  }

  /// Distinguishes which model is missing from the exception message, so the
  /// offered download targets the right one.
  AskNotesError _notReadyError(String message) {
    final embedder = message.toLowerCase().contains('embedding') ||
        message.toLowerCase().contains('search');
    return AskNotesError(
      embedder
          ? 'The search model needs to be downloaded to look through your notes.'
          : 'The on-device model needs to be downloaded to answer.',
      offerModelDownload: true,
      downloadIsEmbedder: embedder,
    );
  }
}
