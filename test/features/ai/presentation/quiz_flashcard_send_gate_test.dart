// Quiz and flashcards ask before they send a page to a cloud model the student
// picked. Each makes more than one request for one tap (a failed parse is asked
// again), so the question belongs to the tap, not to the request.

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/data/flashcards/flashcard_store.dart';
import 'package:margo/features/ai/data/llm/model_download_manager.dart';
import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/context_engine/page_context.dart';
import 'package:margo/features/ai/domain/features/flashcard_generator.dart';
import 'package:margo/features/ai/domain/features/quiz_generator.dart';
import 'package:margo/features/ai/domain/models/flashcard.dart';
import 'package:margo/features/ai/presentation/flashcard_notifier.dart';
import 'package:margo/features/ai/presentation/quiz_notifier.dart';

const _enough = 'Photosynthesis converts light energy into chemical energy '
    'stored in glucose, using water and carbon dioxide and releasing oxygen.';

class _NoopProvider implements AiProvider {
  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'noop',
        displayName: 'noop',
        contextWindowTokens: 4096,
      );
  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) =>
      throw UnimplementedError();
}

class _CountingQuizGenerator extends QuizGenerator {
  int calls = 0;
  _CountingQuizGenerator() : super(provider: _NoopProvider());

  @override
  Future<List<QuizQuestion>> generate({
    required String text,
    required KnowledgeLevel level,
    bool allowCoding = false,
    int count = 5,
  }) async {
    calls++;
    return const [];
  }
}

class _CountingFlashcardGenerator extends FlashcardGenerator {
  int calls = 0;
  _CountingFlashcardGenerator() : super(provider: _NoopProvider());

  @override
  Future<List<Flashcard>> generate({
    required PageContext context,
    required String pageText,
    required int notebookId,
    required int pageId,
  }) async {
    calls++;
    return const [];
  }
}

class _NoStore implements FlashcardStore {
  @override
  Future<void> replaceForPage(
      int notebookId, int pageId, List<Flashcard> cards) async {}
  @override
  Future<List<Flashcard>> forNotebook(int notebookId) async => const [];
  @override
  Future<List<Flashcard>> forPage(int pageId) async => const [];
  @override
  Future<List<Flashcard>> dueForNotebook(int notebookId, DateTime now) async =>
      const [];
  @override
  Future<void> updateSchedule(Flashcard card) async {}
}

void main() {
  group('quiz', () {
    late _CountingQuizGenerator generator;
    late int asked;

    QuizNotifier build({required bool allow}) => QuizNotifier(
          generator: generator,
          downloads: ModelDownloadManager(),
          confirmSend: () async {
            asked++;
            return allow;
          },
        );

    QuizRequest request({String text = _enough}) => QuizRequest(
          resolveText: () async => text,
          level: KnowledgeLevel.intermediate,
          pageId: 1,
        );

    setUp(() {
      generator = _CountingQuizGenerator();
      asked = 0;
    });

    test('a yes lets the quiz be built, after one question', () async {
      await build(allow: true).generate(request());

      expect(asked, 1);
      expect(generator.calls, 1);
    });

    test('a no builds nothing and goes back to idle', () async {
      final notifier = build(allow: false);

      await notifier.generate(request());

      expect(generator.calls, 0);
      expect(notifier.state, isA<QuizIdle>());
    });

    test('a page too thin for a quiz is not asked about', () async {
      await build(allow: true).generate(request(text: 'too short'));

      expect(asked, 0);
    });

    test('after a no, the same page can be asked for again', () async {
      final notifier = build(allow: false);
      await notifier.generate(request());

      await notifier.generate(request());

      expect(asked, 2);
    });
  });

  group('flashcards', () {
    late _CountingFlashcardGenerator generator;
    late int asked;

    FlashcardNotifier build({required bool allow}) => FlashcardNotifier(
          generator: generator,
          store: _NoStore(),
          downloads: ModelDownloadManager(),
          confirmSend: () async {
            asked++;
            return allow;
          },
        );

    FlashcardRequest request({String text = _enough}) => FlashcardRequest(
          notebookId: 1,
          pageId: 1,
          context: const PageContext(currentTopic: 'Photosynthesis'),
          resolveText: () async => text,
        );

    setUp(() {
      generator = _CountingFlashcardGenerator();
      asked = 0;
    });

    test('a yes lets the cards be made, after one question', () async {
      await build(allow: true).generate(request());

      expect(asked, 1);
      expect(generator.calls, 1);
    });

    test('a no makes nothing and goes back to idle', () async {
      final notifier = build(allow: false);

      await notifier.generate(request());

      expect(generator.calls, 0);
      expect(notifier.state, isA<FlashcardIdle>());
    });

    test('a page too thin for cards is not asked about', () async {
      await build(allow: true).generate(request(text: 'too short'));

      expect(asked, 0);
    });
  });
}
