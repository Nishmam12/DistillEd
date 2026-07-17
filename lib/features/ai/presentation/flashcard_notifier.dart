// Drives flashcard generation and persistence:
//   idle → generating → ready(cards)
//            ↘ downloadingModel(progress) → (re-run) …
//            ↘ error(message, retryable, offerModelDownload)
//
// On success the deck is SAVED to Isar (flashcards are durable, unlike a quiz
// attempt) — regenerating a page replaces its deck rather than duplicating it.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/flashcards/flashcard_store.dart';
import '../data/handwriting/handwriting_recognition_service.dart';
import '../data/llm/llm_exceptions.dart';
import '../data/llm/model_download_manager.dart';
import '../domain/ai_provider.dart';
import '../domain/context_engine/page_context.dart';
import '../domain/features/flashcard_generator.dart';
import '../domain/models/flashcard.dart';
import '../domain/text_budget.dart' as text_budget;

sealed class FlashcardState {
  const FlashcardState();
}

class FlashcardIdle extends FlashcardState {
  const FlashcardIdle();
}

class FlashcardGenerating extends FlashcardState {
  const FlashcardGenerating();
}

class FlashcardDownloadingModel extends FlashcardState {
  final int progress; // 0–100
  const FlashcardDownloadingModel(this.progress);
}

class FlashcardReady extends FlashcardState {
  final List<Flashcard> cards;
  const FlashcardReady(this.cards);
}

class FlashcardError extends FlashcardState {
  final String message;
  final bool retryable;
  final bool offerModelDownload;
  const FlashcardError(
    this.message, {
    this.retryable = true,
    this.offerModelDownload = false,
  });
}

/// What the notifier needs to (re-)build one deck. [resolveText] is read fresh
/// each attempt (the current page); [context] supplies definitions + concepts.
class FlashcardRequest {
  final int notebookId;
  final int pageId;
  final PageContext context;
  final Future<String> Function() resolveText;
  const FlashcardRequest({
    required this.notebookId,
    required this.pageId,
    required this.context,
    required this.resolveText,
  });
}

class FlashcardNotifier extends StateNotifier<FlashcardState> {
  final FlashcardGenerator _generator;
  final FlashcardStore _store;
  final ModelDownloadManager _downloads;

  static const int _minWords = 15;

  FlashcardNotifier({
    required FlashcardGenerator generator,
    required FlashcardStore store,
    required ModelDownloadManager downloads,
  })  : _generator = generator,
        _store = store,
        _downloads = downloads,
        super(const FlashcardIdle());

  FlashcardRequest? _last;
  bool _running = false;

  Future<void> generate(FlashcardRequest request) async {
    if (_running) return;
    _last = request;
    _running = true;
    try {
      state = const FlashcardGenerating();
      final text = await request.resolveText();
      if (text_budget.countWords(text) < _minWords) {
        state = const FlashcardError(
          "There isn't enough on this page to make flashcards yet.",
          retryable: false,
        );
        return;
      }

      final cards = await _generator.generate(
        context: request.context,
        pageText: text,
        notebookId: request.notebookId,
        pageId: request.pageId,
      );
      if (cards.isEmpty) {
        state = const FlashcardError(
            "Couldn't find enough to turn into flashcards here.");
        return;
      }

      await _store.replaceForPage(request.notebookId, request.pageId, cards);
      if (!mounted) return;
      state = FlashcardReady(cards);
    } catch (e) {
      if (!mounted) return;
      state = _mapError(e);
    } finally {
      _running = false;
    }
  }

  Future<void> retry() async {
    final last = _last;
    if (last != null) await generate(last);
  }

  Future<void> downloadModelAndRetry() async {
    final last = _last;
    if (last == null || _running) return;

    state = const FlashcardDownloadingModel(0);
    final sub = _downloads.progress.listen((p) {
      if (mounted && state is FlashcardDownloadingModel) {
        state = FlashcardDownloadingModel(p);
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
    if (!_running) state = const FlashcardIdle();
  }

  FlashcardState _mapError(Object e) {
    return switch (e) {
      AiModelNotReadyException _ => const FlashcardError(
          'The on-device model needs to be downloaded first.',
          offerModelDownload: true),
      AiException(:final message) => FlashcardError(message),
      RecognitionException(:final message) => FlashcardError(message),
      InsufficientStorageException(:final message) =>
        FlashcardError('Not enough storage for the model. $message'),
      ModelDownloadCancelledException _ => const FlashcardIdle(),
      LlmException(:final message) => FlashcardError(message),
      _ => const FlashcardError('Something went wrong while making flashcards.'),
    };
  }
}
