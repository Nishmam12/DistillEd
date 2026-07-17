// Flashcard Generator: builds a study deck from a page.
//
// Two sources, merged and de-duplicated (front, case-insensitive):
//   * the note's own definitions ([PageContext.definitions]) → faithful
//     term→definition cards, verbatim from what the writer wrote.
//   * a structured model call that turns the key concepts into concise
//     front/back cards, grounded in the page text (reuses the Loop 1.1
//     robustness ladder: schema → tryExtractJsonObject → one retry → parse).
//
// Malformed model output yields no LLM cards (the definition cards still
// stand); real provider failures ([AiException]) propagate so the caller can
// offer the model download.

import '../ai_provider.dart';
import '../ai_router.dart';
import '../context_engine/context_engine.dart';
import '../context_engine/page_context.dart';
import '../models/flashcard.dart';
import '../text_budget.dart';

class FlashcardGenerator {
  static const String _schemaInstruction = '''
You create study flashcards from a student's OWN notes. Use ONLY facts present in the note — never invent content it doesn't support. Reply with ONLY a single JSON object — no markdown, no code fences, no text before or after it — in exactly this shape:

{"cards": [
  {"front": "a term or a short question", "back": "a concise, self-contained answer"}
]}

Rules:
- Make one card per important idea. Keep the back to 1–2 sentences.
- The front should be answerable on its own (a term to define, or a question).
- At most 20 cards. If there is little to learn, return {"cards": []}.''';

  static const String _retryNudge =
      'Reply with ONLY one valid JSON object in the required shape '
      '({"cards": [...]}). No markdown fences, no commentary.';

  static const int maxCards = 20;

  final AiProvider _provider;
  const FlashcardGenerator({required AiProvider provider})
      : _provider = provider;

  /// Generates cards for ([notebookId], [pageId]). [context] supplies the
  /// note's definitions and the key concepts to prioritise; [pageText] grounds
  /// the model. Returns at most [maxCards], de-duplicated by front.
  Future<List<Flashcard>> generate({
    required PageContext context,
    required String pageText,
    required int notebookId,
    required int pageId,
  }) async {
    // The model call happens first so a missing model surfaces before we build
    // anything (consistent with the other features' download-offer flow).
    final llm = await _generateLlm(context, pageText);

    final now = DateTime.now();
    final seen = <String>{};
    final cards = <Flashcard>[];

    void add(String front, String back) {
      final f = front.trim();
      final b = back.trim();
      if (f.isEmpty || b.isEmpty) return;
      if (!seen.add(f.toLowerCase())) return;
      if (cards.length >= maxCards) return;
      cards.add(Flashcard(
        front: f,
        back: b,
        notebookId: notebookId,
        pageId: pageId,
        createdAt: now,
      ));
    }

    // Definitions first — they're verbatim from the note, so they win on
    // duplicate fronts.
    context.definitions.forEach(add);
    for (final (front, back) in llm) {
      add(front, back);
    }
    return cards;
  }

  Future<List<(String, String)>> _generateLlm(
      PageContext context, String pageText) async {
    final budget = AiRouter.inputWordBudgetFor(_provider.capabilities);
    final hint = context.keyConcepts.isEmpty
        ? ''
        : '\n\nPrioritise cards for these concepts: '
            '${context.keyConcepts.join(', ')}.';
    final prompt = 'NOTE:\n${truncateToWords(pageText.trim(), budget)}$hint';

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
          options: const AiGenerationOptions(temperature: 0.0, maxTokens: 1024),
        )
        .toList();
    return chunks.join();
  }

  static List<(String, String)> _parse(Map<String, dynamic> json) {
    final raw = json['cards'];
    if (raw is! List) return const [];
    final out = <(String, String)>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final front = entry['front'];
      final back = entry['back'];
      if (front is String && back is String) {
        out.add((front, back));
      }
    }
    return out;
  }
}
