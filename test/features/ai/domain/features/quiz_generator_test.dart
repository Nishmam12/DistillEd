import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/ai_router.dart';
import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';
import 'package:inkflow/features/ai/domain/features/quiz_generator.dart';

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
  const source = 'a page of notes with plenty of words to quiz on here today';

  Future<List<QuizQuestion>> gen(
    List<String> responses, {
    KnowledgeLevel level = KnowledgeLevel.intermediate,
    bool allowCoding = false,
  }) =>
      QuizGenerator(provider: _ScriptedProvider(responses)).generate(
        text: source,
        level: level,
        allowCoding: allowCoding,
      );

  group('parsing', () {
    test('reads mcq, true/false and fill-blank into gradeable questions',
        () async {
      final result = await gen([
        '{"questions":['
            '{"type":"mcq","prompt":"Capital of France?",'
            '"options":["Paris","London","Rome","Berlin"],"answer":"Paris",'
            '"explanation":"It is Paris."},'
            '{"type":"true-false","prompt":"The sky is green.","answer":"false"},'
            '{"type":"fill-blank","prompt":"Water is H2 ___.","answer":"O"}]}'
      ]);

      expect(result, hasLength(3));

      final mcq = result[0];
      expect(mcq.type, QuestionType.mcq);
      expect(mcq.correctIndex, 0);
      expect(mcq.correctAnswer, 'Paris');
      expect(mcq.explanation, 'It is Paris.');

      final tf = result[1];
      expect(tf.type, QuestionType.trueFalse);
      expect(tf.options, ['True', 'False']);
      expect(tf.correctIndex, 1);

      final fb = result[2];
      expect(fb.type, QuestionType.fillBlank);
      expect(fb.correctAnswer, 'O');
    });

    test('drops every ungradeable entry', () async {
      final result = await gen([
        '{"questions":['
            '{"type":"mcq","prompt":"Q","options":["a","b"],"answer":"z"},'
            '{"type":"mystery","prompt":"Q","answer":"x"},'
            '{"type":"true-false","prompt":"Q","answer":"maybe"},'
            '{"type":"fill-blank","prompt":"","answer":"x"},'
            '{"type":"mcq","prompt":"Real","options":["a","b","c","d"],'
            '"answer":"c"}]}'
      ]);

      expect(result, hasLength(1));
      expect(result.single.correctAnswer, 'c');
    });

    test('malformed output after a retry yields no questions', () async {
      final provider = _ScriptedProvider(['not json', 'still not json']);
      final result = await QuizGenerator(provider: provider)
          .generate(text: source, level: KnowledgeLevel.beginner);

      expect(result, isEmpty);
      expect(provider.calls, 2);
    });
  });

  group('prompting', () {
    test('difficulty follows the level; coding is excluded by default',
        () async {
      final provider = _ScriptedProvider(['{"questions":[]}']);
      await QuizGenerator(provider: provider)
          .generate(text: source, level: KnowledgeLevel.beginner);

      expect(provider.lastSystemPrompt, contains('easy'));
      expect(provider.lastSystemPrompt, contains('Do NOT include coding'));
      expect(provider.lastOptions?.temperature, 0.0);
      expect(provider.lastOptions?.maxTokens, 1024);
    });

    test('coding questions are offered only when allowed', () async {
      final provider = _ScriptedProvider(['{"questions":[]}']);
      await QuizGenerator(provider: provider).generate(
          text: source, level: KnowledgeLevel.advanced, allowCoding: true);

      expect(provider.lastSystemPrompt, contains('hard'));
      expect(provider.lastSystemPrompt, contains('coding'));
      expect(provider.lastSystemPrompt, isNot(contains('Do NOT include coding')));
    });

    test('over-budget content is truncated before prompting', () async {
      final provider = _ScriptedProvider(['{"questions":[]}']);
      final budget = AiRouter.inputWordBudgetFor(provider.capabilities);
      final long = List.filled(budget + 100, 'word').join(' ');

      await QuizGenerator(provider: provider)
          .generate(text: long, level: KnowledgeLevel.intermediate);

      final words = RegExp(r'\bword\b').allMatches(provider.lastPrompt!).length;
      expect(words, budget);
    });
  });

  group('grading helpers', () {
    test('choice grading compares the index', () {
      const q = QuizQuestion(
          type: QuestionType.mcq,
          prompt: 'q',
          options: ['a', 'b'],
          correctIndex: 1,
          correctAnswer: 'b');
      expect(q.isCorrectChoice(1), isTrue);
      expect(q.isCorrectChoice(0), isFalse);
    });

    test('text grading is case/space/punctuation-insensitive', () {
      const q = QuizQuestion(
          type: QuestionType.fillBlank, prompt: 'q', correctAnswer: 'H2O');
      expect(q.isCorrectText('  h2o. '), isTrue);
      expect(q.isCorrectText('water'), isFalse);
    });
  });

  group('looksLikeProgramming', () {
    test('true for a programming topic', () {
      expect(
          QuizGenerator.looksLikeProgramming(const PageContext(
            currentTopic: 'Python functions and loops',
            estimatedLevel: KnowledgeLevel.beginner,
            confidence: 0.6,
          )),
          isTrue);
    });

    test('false for a non-programming topic', () {
      expect(
          QuizGenerator.looksLikeProgramming(const PageContext(
            currentTopic: 'The French Revolution',
            keyConcepts: ['monarchy', 'guillotine'],
            estimatedLevel: KnowledgeLevel.intermediate,
            confidence: 0.7,
          )),
          isFalse);
    });
  });
}
