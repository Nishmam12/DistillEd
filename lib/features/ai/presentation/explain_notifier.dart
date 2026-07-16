// Drives one Explain request into the sidebar:
//   idle → preparing → streaming(partial) → ready(full)
//            ↘ downloadingModel(progress) → (re-run) …
//            ↘ error(message, retryable, offerModelDownload)
//
// Content is resolved lazily (a selection extraction, or a knowledge-gap term)
// so a retry re-reads it; the streamed reply accumulates into the state so the
// view can render live token output. The LLM download is never silent — a
// missing model surfaces as an error offering the (explicit) download.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/handwriting/handwriting_recognition_service.dart';
import '../data/llm/llm_exceptions.dart';
import '../data/llm/model_download_manager.dart';
import '../domain/ai_provider.dart';
import '../domain/features/explainer.dart';

sealed class ExplainState {
  const ExplainState();
}

class ExplainIdle extends ExplainState {
  const ExplainIdle();
}

/// Resolving the passage to explain (e.g. reading the selected notes).
class ExplainPreparing extends ExplainState {
  const ExplainPreparing();
}

class ExplainStreaming extends ExplainState {
  final String text;
  final ExplainMode mode;
  const ExplainStreaming(this.text, this.mode);
}

class ExplainReady extends ExplainState {
  final String text;
  final ExplainMode mode;
  const ExplainReady(this.text, this.mode);
}

class ExplainDownloadingModel extends ExplainState {
  final int progress; // 0–100
  const ExplainDownloadingModel(this.progress);
}

class ExplainError extends ExplainState {
  final String message;
  final bool retryable;

  /// When true the UI offers the on-device model download as the fix.
  final bool offerModelDownload;
  const ExplainError(
    this.message, {
    this.retryable = true,
    this.offerModelDownload = false,
  });
}

/// What the notifier needs to (re-)run one explanation. [resolveContent] is
/// called fresh on every attempt (a selection is re-read; a gap term is
/// returned verbatim) so retries and mode-changes always see current content.
class ExplainRequest {
  final Future<String> Function() resolveContent;
  final ExplainMode mode;
  const ExplainRequest({required this.resolveContent, required this.mode});
}

class ExplainNotifier extends StateNotifier<ExplainState> {
  final Explainer _explainer;
  final ModelDownloadManager _downloads;

  ExplainNotifier({
    required Explainer explainer,
    required ModelDownloadManager downloads,
  })  : _explainer = explainer,
        _downloads = downloads,
        super(const ExplainIdle());

  ExplainRequest? _last;
  bool _running = false;

  Future<void> run(ExplainRequest request) async {
    if (_running) return;
    _last = request;
    _running = true;
    try {
      state = const ExplainPreparing();
      final content = await request.resolveContent();
      if (content.trim().isEmpty) {
        state = const ExplainError(
          "There's nothing to explain here yet — select some notes first.",
          retryable: false,
        );
        return;
      }

      final buffer = StringBuffer();
      state = ExplainStreaming('', request.mode);
      await for (final chunk
          in _explainer.explain(ExplainInput(content: content, mode: request.mode))) {
        if (!mounted) return;
        buffer.write(chunk);
        state = ExplainStreaming(buffer.toString(), request.mode);
      }

      if (!mounted) return;
      final text = buffer.toString().trim();
      state = text.isEmpty
          ? const ExplainError("The model didn't return an explanation. "
              'Try again.')
          : ExplainReady(text, request.mode);
    } catch (e) {
      if (!mounted) return;
      state = _mapError(e);
    } finally {
      _running = false;
    }
  }

  /// Re-runs the current passage in a different mode.
  Future<void> changeMode(ExplainMode mode) async {
    final last = _last;
    if (last == null || _running) return;
    await run(ExplainRequest(resolveContent: last.resolveContent, mode: mode));
  }

  Future<void> retry() async {
    final last = _last;
    if (last != null) await run(last);
  }

  /// Starts the LLM download (explicit user action) and re-runs when it lands.
  Future<void> downloadModelAndRetry() async {
    final last = _last;
    if (last == null || _running) return;

    state = const ExplainDownloadingModel(0);
    final sub = _downloads.progress.listen((p) {
      if (mounted && state is ExplainDownloadingModel) {
        state = ExplainDownloadingModel(p);
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
    await run(last);
  }

  void cancelModelDownload() => _downloads.cancelDownload();

  /// Dismisses the explanation and returns the sidebar to the live context.
  void reset() {
    if (!_running) state = const ExplainIdle();
  }

  ExplainState _mapError(Object e) {
    return switch (e) {
      AiModelNotReadyException _ => const ExplainError(
          'The on-device model needs to be downloaded first.',
          offerModelDownload: true),
      AiException(:final message) => ExplainError(message),
      RecognitionException(:final message) => ExplainError(message),
      InsufficientStorageException(:final message) =>
        ExplainError('Not enough storage for the model. $message'),
      ModelDownloadCancelledException _ => const ExplainIdle(),
      LlmException(:final message) => ExplainError(message),
      _ => const ExplainError('Something went wrong while explaining.'),
    };
  }
}
