// Writing Assistant: opportunistic, non-intrusive suggestions on the writer's
// TYPED text — grammar, clarity, repetition, unsupported claims, missing
// structure.
//
// Deliberately typed-text only for now: handwriting-recognition text is noisier,
// so grammar-level nitpicks on it would misfire. Ink is revisited in a later
// pass (flag as lower-confidence / content-level only).
//
// Structured JSON output reuses the Context Engine's robustness ladder: a strict
// schema in the system prompt, greedy decoding, balanced-brace extraction
// ([ContextEngine.tryExtractJsonObject]), one stricter retry, and a tolerant
// parse that never throws on malformed output (an advisory feature must fail
// quietly, never with a red error). Real provider failures ([AiException]) DO
// propagate for the caller to handle.

import '../ai_provider.dart';
import '../ai_router.dart';
import '../context_engine/context_engine.dart';
import '../text_budget.dart';

/// The kind of writing issue a suggestion flags.
enum WritingSuggestionKind { grammar, clarity, repetition, weakClaim, structure, other }

extension WritingSuggestionKindLabel on WritingSuggestionKind {
  String get label => switch (this) {
        WritingSuggestionKind.grammar => 'Grammar',
        WritingSuggestionKind.clarity => 'Clarity',
        WritingSuggestionKind.repetition => 'Repetition',
        WritingSuggestionKind.weakClaim => 'Needs support',
        WritingSuggestionKind.structure => 'Structure',
        WritingSuggestionKind.other => 'Suggestion',
      };
}

/// One non-blocking writing suggestion.
class WritingSuggestion {
  final WritingSuggestionKind kind;

  /// The advice, e.g. "This claim has no supporting detail."
  final String message;

  /// The snippet the suggestion refers to ('' when it's about the text overall).
  final String excerpt;

  /// A concrete rewrite, when the model offered one ('' otherwise).
  final String replacement;

  /// 0.0–1.0 model confidence.
  final double confidence;

  const WritingSuggestion({
    required this.kind,
    required this.message,
    this.excerpt = '',
    this.replacement = '',
    this.confidence = 0.5,
  });

  /// Tolerant parse — unknown/missing fields fall back, never throws. Returns
  /// null when there is no usable message (a suggestion with nothing to say is
  /// dropped by the caller).
  static WritingSuggestion? fromJson(Map<String, dynamic> json) {
    final message = _str(json['message']);
    if (message.isEmpty) return null;
    return WritingSuggestion(
      kind: _kind(_str(json['type'])),
      message: message,
      excerpt: _str(json['excerpt']),
      replacement: _str(json['suggestion']),
      confidence: _confidence(json['confidence']),
    );
  }

  static String _str(Object? v) => v is String ? v.trim() : '';

  static double _confidence(Object? v) {
    final d = v is num ? v.toDouble() : 0.5;
    return d.clamp(0.0, 1.0);
  }

  static WritingSuggestionKind _kind(String raw) {
    final key = raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return switch (key) {
      'grammar' || 'spelling' || 'typo' => WritingSuggestionKind.grammar,
      'clarity' || 'clear' || 'wordy' || 'conciseness' =>
        WritingSuggestionKind.clarity,
      'repetition' || 'repeat' || 'repeated' || 'redundant' =>
        WritingSuggestionKind.repetition,
      'weakclaim' || 'claim' || 'unsupported' || 'support' =>
        WritingSuggestionKind.weakClaim,
      'structure' || 'organization' || 'flow' => WritingSuggestionKind.structure,
      _ => WritingSuggestionKind.other,
    };
  }
}

class WritingAssistant {
  static const String _schemaInstruction = '''
You are a supportive writing coach reviewing a student's TYPED notes. Point out only real, useful issues — do not invent problems, and never rewrite the whole thing. Reply with ONLY a single JSON object — no markdown, no code fences, no text before or after it — in exactly this shape:

{"suggestions": [
  {"type": "grammar", "excerpt": "the exact phrase from the note this is about", "message": "one short, kind sentence of advice", "suggestion": "a concrete fix, or empty string", "confidence": 0.7}
]}

Rules:
- "type" is one of: "grammar", "clarity", "repetition", "weak-claim" (a claim stated with no supporting detail), "structure".
- Base every suggestion on the note's actual text. Quote the relevant phrase in "excerpt".
- Prefer a few high-value suggestions over many nitpicks. At most 6.
- If the writing is already clear, return {"suggestions": []}.
- "confidence" is 0.0 to 1.0.''';

  static const String _retryNudge =
      'Reply with ONLY one valid JSON object in the required shape '
      '({"suggestions": [...]}). No markdown fences, no commentary.';

  /// Below this many words the text is too short to review usefully.
  static const int minWords = 12;

  /// Cap on returned suggestions, regardless of what the model emits.
  static const int maxSuggestions = 6;

  final AiProvider _provider;
  const WritingAssistant({required AiProvider provider}) : _provider = provider;

  /// Reviews [typedText] and returns suggestions (possibly empty). Malformed
  /// model output yields an empty list; [AiException]s propagate.
  Future<List<WritingSuggestion>> review(String typedText) async {
    final text = typedText.trim();
    if (countWords(text) < minWords) return const [];

    final budget = AiRouter.inputWordBudgetFor(_provider.capabilities);
    final prompt = 'NOTE:\n${truncateToWords(text, budget)}';

    var json = ContextEngine.tryExtractJsonObject(await _complete(prompt));
    json ??= ContextEngine.tryExtractJsonObject(
        await _complete('$prompt\n\n$_retryNudge'));
    if (json == null) return const [];

    return _parse(json);
  }

  Future<String> _complete(String prompt) async {
    final chunks = await _provider
        .generate(
          prompt: prompt,
          systemPrompt: _schemaInstruction,
          // Greedy: structured extraction wants determinism, and small models
          // emit valid JSON far more reliably without sampling.
          options: const AiGenerationOptions(temperature: 0.0, maxTokens: 512),
        )
        .toList();
    return chunks.join();
  }

  static List<WritingSuggestion> _parse(Map<String, dynamic> json) {
    final raw = json['suggestions'];
    if (raw is! List) return const [];
    final out = <WritingSuggestion>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final suggestion =
          WritingSuggestion.fromJson(entry.cast<String, dynamic>());
      if (suggestion != null) out.add(suggestion);
      if (out.length >= maxSuggestions) break;
    }
    return out;
  }
}
