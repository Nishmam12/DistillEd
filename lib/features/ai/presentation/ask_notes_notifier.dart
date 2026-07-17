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
import '../domain/features/notes_qa.dart';
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
  const AskNotesSearching(this.question);
}

class AskNotesAnswering extends AskNotesState {
  final String question;
  final String text;
  final List<RetrievedChunk> sources;
  const AskNotesAnswering(this.question, this.text, this.sources);
}

class AskNotesAnswered extends AskNotesState {
  final String question;
  final String text;
  final List<RetrievedChunk> sources;
  const AskNotesAnswered(this.question, this.text, this.sources);
}

/// Retrieval returned nothing relevant — a grounded "not in your notes". Not an
/// error: the feature worked, the notes just don't cover it (or aren't indexed
/// yet). Distinct so the UI can nudge toward downloading/indexing when apt.
class AskNotesNotFound extends AskNotesState {
  final String question;
  const AskNotesNotFound(this.question);
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

  AskNotesNotifier({
    required NotesQa qa,
    required ModelDownloadManager llmDownloads,
    required EmbedderDownloadManager embedderDownloads,
  })  : _qa = qa,
        _llmDownloads = llmDownloads,
        _embedderDownloads = embedderDownloads,
        super(const AskNotesIdle());

  String? _lastQuestion;
  int? _lastNotebookId;
  bool _running = false;

  /// Opens the query box (footer "Ask" chip). No-op mid-run.
  void startComposing() {
    if (!_running) state = const AskNotesComposing();
  }

  /// [notebookId] is passed per-call (not held in the provider) so this notifier
  /// stays a plain session-scoped provider like Explain/Quiz, rather than a
  /// per-notebook family.
  Future<void> ask(String question, {required int notebookId}) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _running) return;
    _lastQuestion = trimmed;
    _lastNotebookId = notebookId;
    _running = true;
    try {
      state = AskNotesSearching(trimmed);
      final sources =
          await _qa.findSources(question: trimmed, notebookId: notebookId);
      if (!mounted) return;
      if (sources.isEmpty) {
        // Grounded refusal decided WITHOUT the LLM — nothing to answer from.
        state = AskNotesNotFound(trimmed);
        return;
      }

      final buffer = StringBuffer();
      state = AskNotesAnswering(trimmed, '', sources);
      await for (final chunk
          in _qa.answer(question: trimmed, sources: sources)) {
        if (!mounted) return;
        buffer.write(chunk);
        state = AskNotesAnswering(trimmed, buffer.toString(), sources);
      }
      if (!mounted) return;

      final text = buffer.toString().trim();
      // The model may still conclude the passages don't answer it — honour that
      // as a not-found rather than showing a bare refusal next to source chips.
      if (text.isEmpty || _isRefusal(text)) {
        state = AskNotesNotFound(trimmed);
      } else {
        state = AskNotesAnswered(trimmed, text, sources);
      }
    } catch (e) {
      if (!mounted) return;
      state = _mapError(e);
    } finally {
      _running = false;
    }
  }

  Future<void> retry() async {
    final q = _lastQuestion;
    final nb = _lastNotebookId;
    if (q != null && nb != null) await ask(q, notebookId: nb);
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
    await ask(q, notebookId: nb);
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
