import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/ai_router.dart';
import 'package:inkflow/features/ai/domain/features/writing_assistant.dart';

/// Replays one scripted response per generate call and records the inputs.
class _ScriptedProvider implements AiProvider {
  final List<String> responses;
  int calls = 0;
  String? lastPrompt;
  String? lastSystemPrompt;
  AiGenerationOptions? lastOptions;

  _ScriptedProvider(this.responses);

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
    lastPrompt = prompt;
    lastSystemPrompt = systemPrompt;
    lastOptions = options;
    final r = calls < responses.length ? responses[calls] : responses.last;
    calls++;
    yield r;
  }

  @override
  Future<List<double>> embed(String text) async => throw UnimplementedError();
}

void main() {
  // 15 words — comfortably over the review threshold.
  const longEnough =
      'the quick brown fox jumps over the lazy dog and then runs away back home';

  Future<List<WritingSuggestion>> review(
    List<String> responses, {
    String text = longEnough,
  }) =>
      WritingAssistant(provider: _ScriptedProvider(responses)).review(text);

  test('parses well-formed suggestions with the deterministic preset',
      () async {
    final provider = _ScriptedProvider([
      '{"suggestions":[{"type":"grammar","excerpt":"recieve",'
          '"message":"Spelling: it should be receive.","suggestion":"receive",'
          '"confidence":0.9}]}'
    ]);

    final result =
        await WritingAssistant(provider: provider).review(longEnough);

    expect(result, hasLength(1));
    final s = result.first;
    expect(s.kind, WritingSuggestionKind.grammar);
    expect(s.message, 'Spelling: it should be receive.');
    expect(s.excerpt, 'recieve');
    expect(s.replacement, 'receive');
    expect(s.confidence, 0.9);
    expect(provider.lastOptions?.temperature, 0.0);
    expect(provider.lastOptions?.maxTokens, 512);
    expect(provider.lastSystemPrompt, contains('writing coach'));
  });

  test('text below the word threshold is not sent to the model', () async {
    final provider = _ScriptedProvider(['{"suggestions":[]}']);
    final result = await WritingAssistant(provider: provider).review('too short');

    expect(result, isEmpty);
    expect(provider.calls, 0);
  });

  test('malformed output after a retry yields no suggestions', () async {
    final provider = _ScriptedProvider(['sorry, cannot', 'still not json']);
    final result = await WritingAssistant(provider: provider).review(longEnough);

    expect(result, isEmpty);
    expect(provider.calls, 2, reason: 'one stricter retry before giving up');
  });

  test('a stricter retry recovers when the first reply is junk', () async {
    final result = await review([
      'here you go: not actually json',
      '{"suggestions":[{"type":"clarity","message":"Tighten this sentence."}]}',
    ]);

    expect(result, hasLength(1));
    expect(result.first.kind, WritingSuggestionKind.clarity);
  });

  test('the number of suggestions is capped', () async {
    final many = jsonEncode({
      'suggestions': [
        for (var i = 0; i < 10; i++) {'type': 'clarity', 'message': 'm$i'}
      ]
    });
    final result = await review([many]);

    expect(result, hasLength(WritingAssistant.maxSuggestions));
  });

  test('entries with no message are dropped; unknown types map to other',
      () async {
    final result = await review([
      '{"suggestions":['
          '{"type":"grammar","message":""},'
          '{"type":"weak-claim","message":"This claim needs support."},'
          '{"type":"mystery","message":"Something else."}]}'
    ]);

    expect(result, hasLength(2));
    expect(result[0].kind, WritingSuggestionKind.weakClaim);
    expect(result[1].kind, WritingSuggestionKind.other);
  });

  test('over-budget text is truncated before prompting', () async {
    final provider = _ScriptedProvider(['{"suggestions":[]}']);
    final budget = AiRouter.inputWordBudgetFor(provider.capabilities);
    final long = List.filled(budget + 100, 'word').join(' ');

    await WritingAssistant(provider: provider).review(long);

    final words = RegExp(r'\bword\b').allMatches(provider.lastPrompt!).length;
    expect(words, budget);
  });
}
