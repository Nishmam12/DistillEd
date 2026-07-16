// Quiz Generator: turns a page's content into gradeable practice questions.
//
// Structured JSON output reuses the Context Engine's robustness ladder (Loop
// 1.1): a strict schema in the system prompt, greedy decoding, balanced-brace
// extraction ([ContextEngine.tryExtractJsonObject]), one stricter retry, and a
// tolerant parse that NEVER throws on malformed output and drops any question it
// can't grade. Real provider failures ([AiException]) propagate.
//
// Difficulty follows the writer's apparent level ([PageContext.estimatedLevel]).
// Coding challenges are only requested when the page looks like programming
// (see [looksLikeProgramming]) — never for, say, a history notebook.

import '../ai_provider.dart';
import '../ai_router.dart';
import '../context_engine/context_engine.dart';
import '../context_engine/page_context.dart';
import '../text_budget.dart';

enum QuestionType { mcq, trueFalse, fillBlank, coding }

extension QuestionTypeLabel on QuestionType {
  String get label => switch (this) {
        QuestionType.mcq => 'Multiple choice',
        QuestionType.trueFalse => 'True / False',
        QuestionType.fillBlank => 'Fill in the blank',
        QuestionType.coding => 'Coding',
      };
}

/// One quiz question. [options]/[correctIndex] apply to the choice types
/// (mcq, trueFalse); [correctAnswer] is the canonical answer text for every
/// type. Coding questions are self-assessed (no objective grade).
class QuizQuestion {
  final QuestionType type;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String correctAnswer;
  final String explanation;

  const QuizQuestion({
    required this.type,
    required this.prompt,
    required this.correctAnswer,
    this.options = const [],
    this.correctIndex = -1,
    this.explanation = '',
  });

  bool get isChoice =>
      type == QuestionType.mcq || type == QuestionType.trueFalse;

  /// Coding answers can't be graded objectively — the taker self-marks.
  bool get isSelfAssessed => type == QuestionType.coding;

  bool isCorrectChoice(int index) => index == correctIndex;

  bool isCorrectText(String input) =>
      _normalize(input) == _normalize(correctAnswer);

  static String _normalize(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[.,!?;:]+$'), '');

  /// Tolerant parse. Returns null when the entry can't be turned into a
  /// gradeable question (unknown type, blank prompt, mcq whose answer isn't one
  /// of its options, true/false or fill-blank with no answer).
  static QuizQuestion? fromJson(Map<String, dynamic> json) {
    final prompt = _str(json['prompt']);
    if (prompt.isEmpty) return null;
    final type = _type(_str(json['type']));
    if (type == null) return null;
    final explanation = _str(json['explanation']);
    final answer = _str(json['answer']);

    switch (type) {
      case QuestionType.mcq:
        final options = _stringList(json['options']);
        if (options.length < 2) return null;
        final index = options
            .indexWhere((o) => _normalize(o) == _normalize(answer));
        if (index < 0) return null;
        return QuizQuestion(
          type: type,
          prompt: prompt,
          options: options,
          correctIndex: index,
          correctAnswer: options[index],
          explanation: explanation,
        );

      case QuestionType.trueFalse:
        final truthy = _bool(answer);
        if (truthy == null) return null;
        return QuizQuestion(
          type: type,
          prompt: prompt,
          options: const ['True', 'False'],
          correctIndex: truthy ? 0 : 1,
          correctAnswer: truthy ? 'True' : 'False',
          explanation: explanation,
        );

      case QuestionType.fillBlank:
        if (answer.isEmpty) return null;
        return QuizQuestion(
          type: type,
          prompt: prompt,
          correctAnswer: answer,
          explanation: explanation,
        );

      case QuestionType.coding:
        return QuizQuestion(
          type: type,
          prompt: prompt,
          correctAnswer: answer,
          explanation: explanation,
        );
    }
  }

  static String _str(Object? v) => v is String ? v.trim() : '';

  static List<String> _stringList(Object? v) => v is List
      ? [
          for (final e in v)
            if (e is String && e.trim().isNotEmpty) e.trim()
        ]
      : const [];

  static QuestionType? _type(String raw) {
    final key = raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return switch (key) {
      'mcq' || 'multiplechoice' || 'choice' => QuestionType.mcq,
      'truefalse' || 'boolean' || 'tf' => QuestionType.trueFalse,
      'fillblank' || 'fillintheblank' || 'fillinblank' || 'cloze' =>
        QuestionType.fillBlank,
      'coding' || 'code' || 'programming' => QuestionType.coding,
      _ => null,
    };
  }

  static bool? _bool(String raw) {
    final v = raw.toLowerCase().trim();
    if (v == 'true' || v == 't' || v == 'yes') return true;
    if (v == 'false' || v == 'f' || v == 'no') return false;
    return null;
  }
}

class QuizGenerator {
  static const String _retryNudge =
      'Reply with ONLY one valid JSON object in the required shape '
      '({"questions": [...]}). No markdown fences, no commentary.';

  /// Words that, in a page's topic/concepts/entities, mark it as programming
  /// content — the gate for offering coding questions.
  static const Set<String> _programmingHints = {
    'programming',
    'code',
    'coding',
    'algorithm',
    'algorithms',
    'function',
    'functions',
    'variable',
    'variables',
    'loop',
    'loops',
    'array',
    'python',
    'javascript',
    'typescript',
    'java',
    'kotlin',
    'dart',
    'flutter',
    'c++',
    'rust',
    'sql',
    'html',
    'css',
    'compiler',
    'recursion',
    'api',
    'class',
    'object-oriented',
    'data structure',
    'data structures',
  };

  /// True when the page's detected topic/subtopics/concepts/entities suggest
  /// programming — so a coding challenge is appropriate.
  static bool looksLikeProgramming(PageContext context) {
    final haystack = [
      context.currentTopic,
      ...context.subtopics,
      ...context.keyConcepts,
      ...context.namedEntities,
    ].join(' ').toLowerCase();
    return _programmingHints.any((hint) => haystack.contains(hint));
  }

  final AiProvider _provider;
  const QuizGenerator({required AiProvider provider}) : _provider = provider;

  /// Generates up to [count] questions from [text] at a difficulty derived from
  /// [level]. Coding questions are included only when [allowCoding] is true.
  /// Malformed output yields an empty list.
  Future<List<QuizQuestion>> generate({
    required String text,
    required KnowledgeLevel level,
    bool allowCoding = false,
    int count = 5,
  }) async {
    final budget = AiRouter.inputWordBudgetFor(_provider.capabilities);
    final prompt = 'NOTE:\n${truncateToWords(text.trim(), budget)}';
    final system = _schema(count: count, level: level, allowCoding: allowCoding);

    var json =
        ContextEngine.tryExtractJsonObject(await _complete(prompt, system));
    json ??= ContextEngine.tryExtractJsonObject(
        await _complete('$prompt\n\n$_retryNudge', system));
    if (json == null) return const [];
    return _parse(json);
  }

  static String difficultyFor(KnowledgeLevel level) => switch (level) {
        KnowledgeLevel.beginner => 'easy',
        KnowledgeLevel.intermediate => 'medium',
        KnowledgeLevel.advanced => 'hard',
      };

  static String _schema({
    required int count,
    required KnowledgeLevel level,
    required bool allowCoding,
  }) {
    final types = [
      '"mcq" (4 options)',
      '"true-false"',
      '"fill-blank" (put ___ where the answer goes in the prompt)',
      if (allowCoding) '"coding" (a short programming task)',
    ].join(', ');
    return '''
You write quiz questions to help a student review their OWN notes. Use ONLY facts present in the note — never invent content the note doesn't support. Reply with ONLY a single JSON object — no markdown, no code fences, no text before or after it — in exactly this shape:

{"questions": [
  {"type": "mcq", "prompt": "the question", "options": ["a", "b", "c", "d"], "answer": "the exact correct option text", "explanation": "one short sentence on why"},
  {"type": "true-false", "prompt": "a statement", "answer": "true", "explanation": "..."},
  {"type": "fill-blank", "prompt": "a sentence with ___ for the blank", "answer": "the missing word or phrase", "explanation": "..."}
]}

Rules:
- Produce at most $count questions at ${difficultyFor(level)} difficulty.
- Allowed types: $types.
- For "mcq", "answer" MUST be exactly one of the "options".
- Mix the question types. Base every question on the note.${allowCoding ? '' : '\n- Do NOT include coding questions.'}''';
  }

  Future<String> _complete(String prompt, String system) async {
    final chunks = await _provider
        .generate(
          prompt: prompt,
          systemPrompt: system,
          options: const AiGenerationOptions(temperature: 0.0, maxTokens: 1024),
        )
        .toList();
    return chunks.join();
  }

  static List<QuizQuestion> _parse(Map<String, dynamic> json) {
    final raw = json['questions'];
    if (raw is! List) return const [];
    final out = <QuizQuestion>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final q = QuizQuestion.fromJson(entry.cast<String, dynamic>());
      if (q != null) out.add(q);
    }
    return out;
  }
}
