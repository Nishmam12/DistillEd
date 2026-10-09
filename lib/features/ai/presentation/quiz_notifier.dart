// Drives quiz generation:
//   idle → generating → ready(questions)
//            ↘ downloadingModel(progress) → (re-run) …
//            ↘ error(message, retryable, offerModelDownload)
//
// Content is resolved lazily (the current page's text) so a retry re-reads it.
// A missing model surfaces as an error offering the (explicit) download, like
// Summarize/Explain. Taking + scoring the quiz remains UI-local state, but the
// notifier now carries the quiz's provenance (notebook/page/concepts) through to
// [QuizReady] so the sheet can file the graded result into the Learning
// Memory. This notifier still persists nothing itself.

import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;

import '../data/handwriting/handwriting_recognition_service.dart';
import '../data/llm/llm_exceptions.dart';
import '../data/llm/model_download_manager.dart';
import '../domain/ai_provider.dart';
import '../domain/context_engine/page_context.dart';
import '../domain/features/quiz_generator.dart';
import '../domain/text_budget.dart' as text_budget;

sealed class QuizState {
  const QuizState();
}

class QuizIdle extends QuizState {
  const QuizIdle();
}

class QuizGenerating extends QuizState {
  const QuizGenerating();
}

class QuizDownloadingModel extends QuizState {
  final int progress; // 0–100
  const QuizDownloadingModel(this.progress);
}

class QuizReady extends QuizState {
  final List<QuizQuestion> questions;

  /// Where the quiz came from, and what it's about — carried through so the
  /// sheet can file a durable [QuizAttempt] against the right notebook/page
  /// and attribute each question to the concepts it tests.
  final int notebookId;
  final int pageId;
  final List<String> concepts;

  const QuizReady(
    this.questions, {
    this.notebookId = 0,
    this.pageId = 0,
    this.concepts = const [],
  });
}

class QuizError extends QuizState {
  final String message;
  final bool retryable;
  final bool offerModelDownload;
  const QuizError(
    this.message, {
    this.retryable = true,
    this.offerModelDownload = false,
  });
}

/// What the notifier needs to (re-)build one quiz. [resolveText] is called fresh
/// each attempt (reads the current page), so retries see the latest content.
class QuizRequest {
  final Future<String> Function() resolveText;
  final KnowledgeLevel level;
  final bool allowCoding;
  final int count;

  /// Provenance + subject matter, passed straight through to [QuizReady] so the
  /// graded attempt can be recorded in Learning Memory.
  final int notebookId;
  final int pageId;
  final List<String> concepts;

  const QuizRequest({
    required this.resolveText,
    required this.level,
    this.allowCoding = false,
    this.count = 5,
    this.notebookId = 0,
    this.pageId = 0,
    this.concepts = const [],
  });
}

class QuizNotifier extends StateNotifier<QuizState> {
  final QuizGenerator _generator;
  final ModelDownloadManager _downloads;

  /// Below this the page is too thin to make a worthwhile quiz.
  static const int _minWords = 15;

  QuizNotifier({
    required this._generator,
    required this._downloads,
  })  : super(const QuizIdle());

  QuizRequest? _last;
  bool _running = false;
  int _run = 0;

  /// Starts a quiz. A second tap for the same page while one is building is
  /// ignored; a request for a different page supersedes the in-flight one
  /// (whose result is then discarded) so the sheet never shows the old page.
  Future<void> generate(QuizRequest request) async {
    if (_running && _last?.pageId == request.pageId) return;
    _last = request;
    _running = true;
    final run = ++_run;
    try {
      state = const QuizGenerating();
      final text = await request.resolveText();
      if (!mounted || run != _run) return;
      if (text_budget.countWords(text) < _minWords) {
        state = const QuizError(
          "There isn't enough on this page to build a quiz yet.",
          retryable: false,
        );
        return;
      }

      final questions = await _generator.generate(
        text: text,
        level: request.level,
        allowCoding: request.allowCoding,
        count: request.count,
      );
      if (!mounted || run != _run) return;
      state = questions.isEmpty
          ? const QuizError(
              "Couldn't put a quiz together from this page. Try again.")
          : QuizReady(
              questions,
              notebookId: request.notebookId,
              pageId: request.pageId,
              concepts: request.concepts,
            );
    } catch (e) {
      if (!mounted || run != _run) return;
      state = _mapError(e);
    } finally {
      if (run == _run) _running = false;
    }
  }

  Future<void> retry() async {
    final last = _last;
    if (last != null) await generate(last);
  }

  Future<void> downloadModelAndRetry() async {
    final last = _last;
    if (last == null || _running) return;

    state = const QuizDownloadingModel(0);
    final sub = _downloads.progress.listen((p) {
      if (mounted && state is QuizDownloadingModel) {
        state = QuizDownloadingModel(p);
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
    await generate(last);
  }

  void cancelModelDownload() => _downloads.cancelDownload();

  void reset() {
    if (!_running) state = const QuizIdle();
  }

  QuizState _mapError(Object error) {
    // Riverpod 3 wraps an error thrown while a provider is built in ProviderException.
    final e = error is ProviderException ? error.exception : error;
    return switch (e) {
      AiModelNotReadyException _ => const QuizError(
          'The on-device model needs to be downloaded first.',
          offerModelDownload: true),
      AiException(:final message) => QuizError(message),
      RecognitionException(:final message) => QuizError(message),
      InsufficientStorageException(:final message) =>
        QuizError('Not enough storage for the model. $message'),
      ModelDownloadCancelledException _ => const QuizIdle(),
      LlmException(:final message) => QuizError(message),
      _ => const QuizError('Something went wrong while building the quiz.'),
    };
  }
}
