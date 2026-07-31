// State machine driving the Summarize flow:
//   idle → recognizing → summarizing → success
//              ↘ downloadingModel(progress) → (re-run) …
//              ↘ error(message, retryable, offerModelDownload)
//
// The 2.4 GB LLM download is never started silently: a missing model surfaces
// as an error state offering the download; only an explicit user tap starts it.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/data/llm/llm_exceptions.dart';
import '../../ai/domain/quality/ai_quality_guard.dart';
import '../../ai/data/llm/model_download_manager.dart';
import '../../ai/data/handwriting/handwriting_recognition_service.dart';
import '../domain/services/summarization_service.dart';
import 'summarize_providers.dart';

// The scope types are part of this notifier's request API (SummarizeRequest),
// so callers get them without importing the service directly.
export '../domain/services/summarization_service.dart'
    show
        SummarizeScope,
        SelectionScope,
        PageScope,
        ImportGroupScope,
        NotebookScope;

sealed class SummarizeState {
  const SummarizeState();
}

class SummarizeIdle extends SummarizeState {
  const SummarizeIdle();
}

class SummarizeDownloadingModel extends SummarizeState {
  final int progress; // 0–100
  const SummarizeDownloadingModel(this.progress);
}

class SummarizeRecognizing extends SummarizeState {
  const SummarizeRecognizing();
}

class SummarizeSummarizing extends SummarizeState {
  const SummarizeSummarizing();
}

class SummarizeSuccess extends SummarizeState {
  final String summary;
  final String recognizedText;
  final bool fromCache;

  /// The note exceeded the local context window and was summarized in passes
  /// (chunk-and-reduce) — the whole note was read, not truncated.
  final bool chunked;
  final String modelUsed;

  /// Which tier produced this — the sheet warns on
  /// [AnswerTier.localLowConfidence] and badges [AnswerTier.cloudVerified].
  final AnswerTier tier;
  const SummarizeSuccess({
    required this.summary,
    required this.recognizedText,
    required this.fromCache,
    required this.chunked,
    required this.modelUsed,
    this.tier = AnswerTier.local,
  });
}

class SummarizeError extends SummarizeState {
  final String message;
  final bool retryable;

  /// When true the UI offers the on-device model download as the fix.
  final bool offerModelDownload;
  const SummarizeError(
    this.message, {
    this.retryable = true,
    this.offerModelDownload = false,
  });
}

/// What the notifier needs to (re-)run one summarization.
class SummarizeRequest {
  final int notebookId;

  /// Resolves the scope to summarize (selection / page / notebook) — called
  /// fresh on every attempt so a notebook retry sees the latest pages. Page
  /// content itself is read through the AI platform's PageContentExtractor.
  final Future<SummarizeScope> Function() resolveScope;
  final String languageCode;
  final bool cloudEnabled;

  const SummarizeRequest({
    required this.notebookId,
    required this.resolveScope,
    required this.languageCode,
    required this.cloudEnabled,
  });
}

class SummarizeNotifier extends StateNotifier<SummarizeState> {
  final SummarizationService _service;
  final ModelDownloadManager _downloads;
  final HandwritingRecognitionService _recognition;

  SummarizeNotifier({
    required SummarizationService service,
    required ModelDownloadManager downloads,
    required HandwritingRecognitionService recognition,
  })  : _service = service,
        _downloads = downloads,
        _recognition = recognition,
        super(const SummarizeIdle());

  SummarizeRequest? _lastRequest;
  bool _running = false;

  Future<void> run(SummarizeRequest request) async {
    if (_running) return;
    _lastRequest = request;
    _running = true;
    try {
      state = const SummarizeRecognizing();

      // Recognition language model (~20 MB, managed by ML Kit) — quick enough
      // to live inside the "Reading handwriting…" state.
      await _recognition.ensureModelDownloaded(request.languageCode);

      final scope = await request.resolveScope();
      final result = await _service.summarizeScope(
        notebookId: request.notebookId,
        scope: scope,
        languageCode: request.languageCode,
        cloudEnabled: request.cloudEnabled,
        onStage: (stage) {
          if (!mounted) return;
          state = switch (stage) {
            SummarizeStage.recognizing => const SummarizeRecognizing(),
            SummarizeStage.summarizing => const SummarizeSummarizing(),
          };
        },
      );

      if (!mounted) return;
      state = SummarizeSuccess(
        summary: result.summary,
        recognizedText: result.recognizedText,
        fromCache: result.fromCache,
        chunked: result.chunked,
        modelUsed: result.modelUsed,
        tier: result.tier,
      );
    } catch (e) {
      if (!mounted) return;
      state = _mapError(e);
    } finally {
      _running = false;
    }
  }

  /// Starts the LLM download (explicit user action) and re-runs the last
  /// request when it completes.
  Future<void> downloadModelAndRetry() async {
    final request = _lastRequest;
    if (request == null || _running) return;

    state = const SummarizeDownloadingModel(0);
    final sub = _downloads.progress.listen((p) {
      if (mounted && state is SummarizeDownloadingModel) {
        state = SummarizeDownloadingModel(p);
      }
    });
    try {
      await _downloads.download();
    } catch (e) {
      if (mounted) state = _mapError(e);
      return;
    } finally {
      await sub.cancel();
    }
    if (!mounted) return;
    await run(request);
  }

  void cancelModelDownload() {
    _downloads.cancelDownload();
  }

  Future<void> retry() async {
    final request = _lastRequest;
    if (request != null) await run(request);
  }

  void reset() {
    if (!_running) state = const SummarizeIdle();
  }

  SummarizeState _mapError(Object e) {
    return switch (e) {
      NotMeaningfulException _ =>
        SummarizeError(e.message, retryable: false),
      LocalModelRequiredException(offline: true) =>
        SummarizeError(e.message, retryable: true),
      LocalModelRequiredException _ =>
        SummarizeError(e.message, offerModelDownload: true),
      RecognitionException(:final message) => SummarizeError(message),
      InsufficientStorageException _ =>
        SummarizeError('Not enough storage for the model. ${e.message}'),
      ModelDownloadCancelledException _ => const SummarizeIdle(),
      LlmException(:final message) => SummarizeError(message),
      SummarizeException(:final message, :final retryable) =>
        SummarizeError(message, retryable: retryable),
      _ => const SummarizeError('Something went wrong while summarizing.'),
    };
  }
}

/// Session-scoped (not autoDispose): closing the sheet must not abort an
/// in-flight 2.4 GB model download; reopening shows the live state.
final summarizeNotifierProvider =
    StateNotifierProvider<SummarizeNotifier, SummarizeState>((ref) {
  return SummarizeNotifier(
    service: ref.watch(summarizationServiceProvider),
    downloads: ref.watch(modelDownloadManagerProvider),
    recognition: ref.watch(handwritingRecognitionServiceProvider),
  );
});
