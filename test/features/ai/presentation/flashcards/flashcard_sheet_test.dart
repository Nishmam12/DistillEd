import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/flashcards/flashcard_store.dart';
import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/features/flashcard_generator.dart';
import 'package:inkflow/features/ai/domain/models/flashcard.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';
import 'package:inkflow/features/ai/presentation/flashcard_notifier.dart';
import 'package:inkflow/features/ai/presentation/flashcards/flashcard_sheet.dart';

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

class _NoopStore implements FlashcardStore {
  @override
  Future<void> replaceForPage(int n, int p, List<Flashcard> c) async {}
  @override
  Future<List<Flashcard>> forNotebook(int n) async => const [];
  @override
  Future<List<Flashcard>> forPage(int p) async => const [];
  @override
  Future<List<Flashcard>> dueForNotebook(int n, DateTime now) async => const [];
  @override
  Future<void> updateSchedule(Flashcard card) async {}
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

class _FixedFlashcards extends FlashcardNotifier {
  _FixedFlashcards(List<Flashcard> cards)
      : super(
          generator: FlashcardGenerator(provider: _NoopProvider()),
          store: _NoopStore(),
          downloads: ModelDownloadManager(
              installer: _FakeInstaller(), storage: _FakeStorage()),
        ) {
    state = FlashcardReady(cards);
  }
}

Flashcard card(String front, String back) => Flashcard(
    front: front,
    back: back,
    notebookId: 1,
    pageId: 1,
    createdAt: DateTime(2026));

void main() {
  Future<void> open(WidgetTester tester, List<Flashcard> deck) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flashcardNotifierProvider
              .overrideWith((ref) => _FixedFlashcards(deck)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showFlashcardSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the deck front, count and export action', (tester) async {
    await open(tester, [
      card('What is ATP?', 'The cell energy currency.'),
      card('Define mitosis', 'Cell division.'),
    ]);

    expect(find.text('What is ATP?'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Export to Anki (.apkg)'), findsOneWidget);
    expect(find.text('Export as CSV'), findsOneWidget);
  });

  testWidgets('tapping a card flips it to the answer', (tester) async {
    await open(tester, [card('What is ATP?', 'The cell energy currency.')]);

    expect(find.text('The cell energy currency.'), findsNothing);

    await tester.tap(find.text('What is ATP?'));
    await tester.pump();

    expect(find.text('The cell energy currency.'), findsOneWidget);
  });
}
