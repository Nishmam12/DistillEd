import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';
import 'package:inkflow/features/ai/domain/features/flashcard_generator.dart';

class _ScriptedProvider implements AiProvider {
  final List<String> responses;
  final Object? throwError;
  int calls = 0;

  _ScriptedProvider(this.responses, {this.throwError});

  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'scripted',
        displayName: 'Scripted',
        contextWindowTokens: 4096,
        isLocal: true,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    if (throwError != null) throw throwError!;
    final r = calls < responses.length ? responses[calls] : responses.last;
    calls++;
    yield r;
  }

  @override
  Future<List<double>> embed(String text) async => throw UnimplementedError();
}

void main() {
  const pageText = 'a page of notes about cells with enough words to work on';

  PageContext context({
    Map<String, String> definitions = const {},
    List<String> keyConcepts = const [],
  }) =>
      PageContext(
        currentTopic: 'Cells',
        keyConcepts: keyConcepts,
        definitions: definitions,
        estimatedLevel: KnowledgeLevel.intermediate,
        confidence: 0.6,
      );

  Future<List<dynamic>> gen(
    List<String> responses, {
    Map<String, String> definitions = const {},
    List<String> keyConcepts = const [],
  }) =>
      FlashcardGenerator(provider: _ScriptedProvider(responses)).generate(
        context: context(definitions: definitions, keyConcepts: keyConcepts),
        pageText: pageText,
        notebookId: 7,
        pageId: 11,
      );

  test('merges definition cards with model cards; definitions win ties',
      () async {
    final cards = await gen(
      ['{"cards":[{"front":"Chlorophyll","back":"the green pigment"},'
          '{"front":"ATP","back":"a different, model-written back"}]}'],
      definitions: {'ATP': 'the cell energy currency'},
      keyConcepts: ['Chlorophyll'],
    );

    expect(cards, hasLength(2));
    final atp = cards.firstWhere((c) => c.front == 'ATP');
    expect(atp.back, 'the cell energy currency',
        reason: 'the note\'s own definition wins over the model');
    expect(cards.any((c) => c.front == 'Chlorophyll'), isTrue);
    expect(atp.notebookId, 7);
    expect(atp.pageId, 11);
  });

  test('malformed model output still yields the definition cards', () async {
    final cards = await gen(
      ['not json', 'still not json'],
      definitions: {'Mitosis': 'cell division'},
    );

    expect(cards, hasLength(1));
    expect(cards.single.front, 'Mitosis');
  });

  test('a missing model propagates (so the caller can offer the download)',
      () async {
    final generator = FlashcardGenerator(
        provider: _ScriptedProvider(const [],
            throwError: const AiModelNotReadyException('no model')));

    expect(
      () => generator.generate(
          context: context(definitions: {'X': 'y'}),
          pageText: pageText,
          notebookId: 1,
          pageId: 1),
      throwsA(isA<AiModelNotReadyException>()),
    );
  });

  test('blank fronts/backs are dropped and the deck is capped', () async {
    final many = jsonEncode({
      'cards': [
        {'front': '', 'back': 'no front'},
        for (var i = 0; i < 25; i++) {'front': 'c$i', 'back': 'b$i'},
      ]
    });
    final cards = await gen([many]);

    expect(cards, hasLength(FlashcardGenerator.maxCards));
    expect(cards.every((c) => c.front.isNotEmpty && c.back.isNotEmpty), isTrue);
  });
}
