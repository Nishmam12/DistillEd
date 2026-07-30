import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/flashcards/flashcard_store.dart';
import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';
import 'package:inkflow/features/ai/domain/features/flashcard_generator.dart';
import 'package:inkflow/features/ai/domain/models/flashcard.dart';
import 'package:inkflow/features/ai/presentation/flashcard_notifier.dart';

// ---- Fakes ------------------------------------------------------------------

class _NoopProvider implements AiProvider {
  @override
  AiCapabilities get capabilities => const AiCapabilities(
      modelId: 'noop',
      displayName: 'noop',
      contextWindowTokens: 4096,
      isLocal: true);
  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) =>
      throw UnimplementedError();
  @override
  Future<List<double>> embed(String text) => throw UnimplementedError();
}

class _FakeStore implements FlashcardStore {
  List<Flashcard>? savedCards;
  int? savedPage;

  @override
  Future<void> replaceForPage(int notebookId, int pageId, List<Flashcard> cards) async {
    savedPage = pageId;
    savedCards = cards;
  }

  @override
  Future<List<Flashcard>> forNotebook(int notebookId) async =>
      savedCards ?? const [];
  @override
  Future<List<Flashcard>> forPage(int pageId) async => savedCards ?? const [];
  @override
  Future<List<Flashcard>> dueForNotebook(int notebookId, DateTime now) async =>
      selectDue(savedCards ?? const [], now);
  @override
  Future<void> updateSchedule(Flashcard card) async {
    final cards = savedCards;
    if (cards == null) return;
    final i = cards.indexWhere((c) => c.identityKey == card.identityKey);
    if (i >= 0) cards[i] = card;
  }
}

class _FakeGenerator extends FlashcardGenerator {
  final List<Flashcard> result;
  final Object? error;
  int calls = 0;

  _FakeGenerator({this.result = const [], this.error})
      : super(provider: _NoopProvider());

  @override
  Future<List<Flashcard>> generate({
    required PageContext context,
    required String pageText,
    required int notebookId,
    required int pageId,
  }) async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}

class _FakeInstaller implements ModelInstaller {
  @override
  Future<bool> isInstalled(String modelId) async => true;
  @override
  Future<void> install({
    required LlmModelSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<void> uninstall(String modelId) async {}
}

class _FakeStorage implements DeviceStorage {
  @override
  Future<int> freeBytes() async => 1 << 62;
}

Flashcard card(String front) => Flashcard(
    front: front,
    back: 'back',
    notebookId: 3,
    pageId: 9,
    createdAt: DateTime(2026));

// ---- Tests ------------------------------------------------------------------

void main() {
  const enough =
      'a page with well over fifteen words of real content to turn into flashcards today';

  ({FlashcardNotifier notifier, _FakeStore store}) build(
      _FakeGenerator generator) {
    final store = _FakeStore();
    return (
      notifier: FlashcardNotifier(
        generator: generator,
        store: store,
        downloads: ModelDownloadManager(
            installer: _FakeInstaller(), storage: _FakeStorage()),
      ),
      store: store,
    );
  }

  FlashcardRequest request({
    String text = enough,
    PageContext context = PageContext.empty,
  }) =>
      FlashcardRequest(
        notebookId: 3,
        pageId: 9,
        context: context,
        resolveText: () async => text,
      );

  test('generates, persists the deck, and lands ready', () async {
    final env = build(_FakeGenerator(result: [card('A'), card('B')]));

    await env.notifier.generate(request());

    final ready = env.notifier.state as FlashcardReady;
    expect(ready.cards, hasLength(2));
    expect(ready.deckName, isEmpty,
        reason: 'no topic → blank; the default name is applied at export');
    expect(env.store.savedPage, 9);
    expect(env.store.savedCards, hasLength(2),
        reason: 'the deck is saved to Isar on success');
  });

  test('names the ready deck after the page topic', () async {
    final env = build(_FakeGenerator(result: [card('A')]));

    await env.notifier.generate(
        request(context: const PageContext(currentTopic: 'Photosynthesis')));

    expect((env.notifier.state as FlashcardReady).deckName, 'Photosynthesis');
  });

  test('too little content is a non-retryable error, nothing generated/saved',
      () async {
    final generator = _FakeGenerator(result: [card('A')]);
    final env = build(generator);

    await env.notifier.generate(request(text: 'too short'));

    expect((env.notifier.state as FlashcardError).retryable, isFalse);
    expect(generator.calls, 0);
    expect(env.store.savedCards, isNull);
  });

  test('an empty deck is a retryable error and is not saved', () async {
    final env = build(_FakeGenerator(result: const []));

    await env.notifier.generate(request());

    expect((env.notifier.state as FlashcardError).retryable, isTrue);
    expect(env.store.savedCards, isNull);
  });

  test('a missing model offers the download', () async {
    final env = build(
        _FakeGenerator(error: const AiModelNotReadyException('no model')));

    await env.notifier.generate(request());

    expect((env.notifier.state as FlashcardError).offerModelDownload, isTrue);
  });
}
