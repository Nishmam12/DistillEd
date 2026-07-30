// Turns raw page content into structured understanding — one
// structured-output call to the local provider asking for JSON in
// [PageContext]'s shape.
//
// Robustness over elegance: a small on-device model returns imperfect JSON,
// so the reply goes through balanced-brace extraction (which also strips
// markdown fences and surrounding prose), one stricter retry, and a graceful
// [PageContext.empty] fallback — malformed model output never throws.
// Provider failures ([AiModelNotReadyException] etc.) DO propagate: the
// caller decides how to surface "no model yet".

import 'dart:convert';

import '../ai_provider.dart';
import '../ai_router.dart';
import '../meaningfulness_gate.dart';
import '../page_content.dart';
import '../text_budget.dart';
import 'page_context.dart';

class ContextEngine {
  static const String _schemaInstruction = '''
You analyze one page of a student's notes. Reply with ONLY a single JSON object — no markdown, no code fences, no text before or after it — in exactly this shape:

{"currentTopic": "short phrase naming the main topic",
 "subtopics": ["subtopic"],
 "keyConcepts": ["concept"],
 "namedEntities": ["person, place, work, or thing the note names"],
 "definitions": {"term": "definition exactly as the note states it"},
 "knowledgeGaps": ["gap"],
 "relatedConcepts": [{"from": "concept", "to": "concept", "relation": "is-a"}],
 "estimatedLevel": "beginner",
 "confidence": 0.5}

Rules:
- Use only what the note actually says. Never invent facts, names, or definitions.
- The note was transcribed from handwriting, so parts of it are misread: expect wrong letters, run-together words, and fragments that are not English at all. Read past them. Never quote a garbled fragment as a topic, concept, entity, definition, or gap — if you cannot tell what a fragment was meant to say, leave it out entirely. A short list of things you actually understood beats a long one padded with noise.
- Put a term in "definitions" only when the note itself defines it.
- "knowledgeGaps" are study gaps a tutor would flag: terms used but never defined, sections that end mid-thought, claims with no supporting detail.
- "relatedConcepts" captures how the concepts connect, as directed pairs. "relation" is a short label such as "is-a", "part-of", "leads-to", "causes", or "related-to". Only include a pair when the note itself implies the link; both ends should be concepts you listed.
- "estimatedLevel" is the writer's apparent understanding: "beginner", "intermediate", or "advanced".
- "confidence" is 0.0 to 1.0 — how sure you are of the topic read; very little text deserves a low value.
- Keep each list to at most 8 short items. Use [] or {} when there is nothing to report.''';

  static const String _retryNudge =
      'Reply with ONLY one valid JSON object in the required shape. '
      'No markdown fences, no commentary, nothing before or after it.';

  final AiProvider _provider;
  final MeaningfulnessGate _gate;

  ContextEngine({
    required AiProvider provider,
    MeaningfulnessGate gate = const MeaningfulnessGate(),
  })  : _provider = provider,
        _gate = gate;

  /// Analyzes [content]. Returns [PageContext.empty] when the page doesn't
  /// carry enough readable text (gate) or the model's output is unusable
  /// after one retry. [previousContext] is offered to the model as a
  /// continuity hint, never as ground truth.
  Future<PageContext> analyze(
    PageContent content, {
    PageContext? previousContext,
  }) async {
    // Figures are part of what the page is ABOUT — a page whose only content is
    // a labelled circuit diagram has a topic and key concepts, and gating on
    // the written words alone would report it as empty.
    final text = content.combinedTextWithFigures;
    final gate = _gate.evaluate(text, topScores: [
      if (content.inkTopScore != null) content.inkTopScore!,
    ]);
    if (!gate.passed) return PageContext.empty;

    final budget = AiRouter.inputWordBudgetFor(_provider.capabilities);
    final prompt = _buildPrompt(truncateToWords(text, budget), previousContext);

    var json = tryExtractJsonObject(await _complete(prompt));
    json ??= tryExtractJsonObject(await _complete('$prompt\n\n$_retryNudge'));
    return json == null ? PageContext.empty : PageContext.fromJson(json);
  }

  static String _buildPrompt(String noteText, PageContext? previous) {
    final continuity = previous != null && previous.currentTopic.isNotEmpty
        ? '\n\nFor continuity: the previous analysis of this page detected '
            'the topic "${previous.currentTopic}". The note may have stayed '
            'on it or moved on — judge from the text alone.'
        : '';
    return 'NOTE:\n$noteText$continuity';
  }

  Future<String> _complete(String prompt) async {
    final chunks = await _provider
        .generate(
          prompt: prompt,
          systemPrompt: _schemaInstruction,
          // Greedy decoding: structured extraction wants determinism, and
          // small models emit valid JSON far more reliably without sampling.
          options: const AiGenerationOptions(temperature: 0.0, maxTokens: 512),
        )
        .toList();
    return chunks.join();
  }

  /// Extracts the first balanced JSON object from [raw], tolerating markdown
  /// fences and prose around it. Null when there is none or it doesn't parse.
  static Map<String, dynamic>? tryExtractJsonObject(String raw) {
    final start = raw.indexOf('{');
    if (start < 0) return null;
    final end = _matchingBrace(raw, start);
    if (end < 0) return null;
    try {
      final decoded = jsonDecode(raw.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Index of the brace closing the object opened at [start], honoring string
  /// literals and escapes; -1 when unbalanced.
  static int _matchingBrace(String text, int start) {
    var depth = 0;
    var inString = false;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (inString) {
        if (c == r'\') {
          i++; // skip the escaped character
        } else if (c == '"') {
          inString = false;
        }
      } else if (c == '"') {
        inString = true;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }
}
