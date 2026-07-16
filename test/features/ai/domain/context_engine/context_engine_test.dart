import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/ai_router.dart';
import 'package:inkflow/features/ai/domain/context_engine/context_engine.dart';
import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';
import 'package:inkflow/features/ai/domain/page_content.dart';

// ---- Fakes ------------------------------------------------------------------

/// Replies with a script (one entry per generate() call) and records inputs.
class ScriptedAiProvider implements AiProvider {
  final List<String> replies;
  final prompts = <String>[];
  final systemPrompts = <String?>[];
  final options = <AiGenerationOptions?>[];
  AiException? throwOnGenerate;

  ScriptedAiProvider(this.replies);

  int get calls => prompts.length;

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
    final error = throwOnGenerate;
    if (error != null) throw error;
    prompts.add(prompt);
    systemPrompts.add(systemPrompt);
    this.options.add(options);
    yield replies[prompts.length - 1];
  }

  @override
  Future<List<double>> embed(String text) async =>
      throw const AiUnsupportedOperationException('not needed here');
}

// ---- Tests ------------------------------------------------------------------

void main() {
  const meaningful =
      'the meeting covered budget planning and the new hiring timeline '
      'for the design team';

  const goodJson = '''
{"currentTopic": "Budget planning",
 "subtopics": ["hiring timeline"],
 "keyConcepts": ["budget", "hiring"],
 "namedEntities": ["design team"],
 "definitions": {"budget": "a plan for spending"},
 "knowledgeGaps": ["hiring timeline mentioned but not detailed"],
 "estimatedLevel": "intermediate",
 "confidence": 0.8}''';

  PageContent content(String text) =>
      PageContent(recognizedInkText: text, typedText: '');

  group('ContextEngine.analyze', () {
    test('clean JSON reply → fully parsed PageContext', () async {
      final provider = ScriptedAiProvider([goodJson]);
      final engine = ContextEngine(provider: provider);

      final context = await engine.analyze(content(meaningful));

      expect(context.currentTopic, 'Budget planning');
      expect(context.keyConcepts, ['budget', 'hiring']);
      expect(context.definitions, {'budget': 'a plan for spending'});
      expect(context.estimatedLevel, KnowledgeLevel.intermediate);
      expect(context.confidence, 0.8);
      expect(provider.calls, 1);
      expect(provider.prompts.single, contains(meaningful));
      expect(provider.systemPrompts.single, contains('JSON'));
      // Structured extraction runs greedy with a bounded response.
      expect(provider.options.single?.temperature, 0.0);
      expect(provider.options.single?.maxTokens, 512);
    });

    test('JSON wrapped in fences and prose still parses on the first try',
        () async {
      final provider = ScriptedAiProvider([
        'Sure! Here is the analysis:\n```json\n$goodJson\n```\nHope it helps.',
      ]);
      final engine = ContextEngine(provider: provider);

      final context = await engine.analyze(content(meaningful));

      expect(context.currentTopic, 'Budget planning');
      expect(provider.calls, 1);
    });

    test('malformed reply → one stricter retry, then parsed', () async {
      final provider = ScriptedAiProvider(['I cannot do JSON today', goodJson]);
      final engine = ContextEngine(provider: provider);

      final context = await engine.analyze(content(meaningful));

      expect(context.currentTopic, 'Budget planning');
      expect(provider.calls, 2);
      expect(provider.prompts[1], contains('ONLY one valid JSON object'));
    });

    test('malformed twice → empty context, never a throw', () async {
      final provider =
          ScriptedAiProvider(['nope', 'still {broken and unclosed']);
      final engine = ContextEngine(provider: provider);

      final context = await engine.analyze(content(meaningful));

      expect(context.isEmpty, isTrue);
      expect(context.confidence, 0.0);
      expect(provider.calls, 2);
    });

    test('too little text fails the gate → empty context, zero model calls',
        () async {
      final provider = ScriptedAiProvider([goodJson]);
      final engine = ContextEngine(provider: provider);

      final context = await engine.analyze(content('only four words here'));

      expect(context.isEmpty, isTrue);
      expect(provider.calls, 0);
    });

    test('over-budget note is truncated to the shared word budget', () async {
      final provider = ScriptedAiProvider([goodJson]);
      final engine = ContextEngine(provider: provider);
      final budget = AiRouter.inputWordBudgetFor(provider.capabilities);

      await engine.analyze(content(List.filled(budget + 50, 'word').join(' ')));

      final wordsInPrompt =
          RegExp(r'\bword\b').allMatches(provider.prompts.single);
      expect(wordsInPrompt.length, budget);
    });

    test('previous context is offered as a continuity hint', () async {
      final provider = ScriptedAiProvider([goodJson]);
      final engine = ContextEngine(provider: provider);

      await engine.analyze(
        content(meaningful),
        previousContext: const PageContext(currentTopic: 'Sprint retro'),
      );

      expect(provider.prompts.single, contains('Sprint retro'));
      expect(provider.prompts.single, contains('continuity'));
    });

    test('an empty previous context adds no continuity hint', () async {
      final provider = ScriptedAiProvider([goodJson]);
      final engine = ContextEngine(provider: provider);

      await engine.analyze(content(meaningful),
          previousContext: PageContext.empty);

      expect(provider.prompts.single, isNot(contains('continuity')));
    });

    test('provider failures propagate (caller decides how to surface them)',
        () {
      final provider = ScriptedAiProvider([goodJson])
        ..throwOnGenerate = const AiModelNotReadyException('no model');
      final engine = ContextEngine(provider: provider);

      expect(engine.analyze(content(meaningful)),
          throwsA(isA<AiModelNotReadyException>()));
    });
  });

  group('tryExtractJsonObject', () {
    test('finds the object among prose and fences', () {
      final json = ContextEngine.tryExtractJsonObject(
          'noise before ```json\n{"a": 1}\n``` noise after');
      expect(json, {'a': 1});
    });

    test('braces inside string values do not confuse the scan', () {
      final json = ContextEngine.tryExtractJsonObject(
          '{"a": "has } and { inside", "b": {"c": 1}}');
      expect(json, {
        'a': 'has } and { inside',
        'b': {'c': 1},
      });
    });

    test('escaped quotes inside strings are honored', () {
      final json =
          ContextEngine.tryExtractJsonObject(r'{"a": "say \"hi\" {"}');
      expect(json, {'a': 'say "hi" {'});
    });

    test('no object or unbalanced braces → null', () {
      expect(ContextEngine.tryExtractJsonObject('no json here'), isNull);
      expect(ContextEngine.tryExtractJsonObject('{"a": 1'), isNull);
      expect(ContextEngine.tryExtractJsonObject('{"a" 1e}'), isNull);
    });
  });
}
