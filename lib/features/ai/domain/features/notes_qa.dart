// "Ask your notes": answer a question grounded in the user's own notes (Phase 2,
// Loop 2.3). RAG retrieves the most relevant chunks; the model answers from
// THOSE passages and nothing else.
//
// The whole value here is faithfulness — an answer the notes don't support is
// worse than no answer, because the user trusts it *because* it claims to come
// from their notes. So the design refuses in two places rather than guessing:
//   1. No relevant passages retrieved → we never call the model at all (see
//      [findSources] returning empty; the notifier reports "not in your notes").
//   2. Passages retrieved but thin → the system prompt orders the model to say
//      it couldn't find the answer instead of falling back on world knowledge.
//
// Retrieval and generation are split so the caller can show the two phases
// ("searching…" → "answering, drawing on N pages") and render the sources.

import '../ai_provider.dart';
import '../ai_router.dart';
import '../rag/rag_retriever.dart';
import '../text_budget.dart';

class NotesQa {
  final AiProvider _provider;
  final RagRetriever _retriever;

  const NotesQa({
    required AiProvider provider,
    required RagRetriever retriever,
  })  : _provider = provider,
        _retriever = retriever;

  /// The grounding contract — identical every call, exposed for prompt review
  /// and tests.
  ///
  /// The register is pinned as deliberately as the grounding is: left to its
  /// default, a small on-device model answers like a chatbot — a "Certainly!"
  /// preamble, a recap of the question, a closing offer of more help. The
  /// student asked their own notes a question, so the answer should sound like
  /// the tutor who read those notes with them. Same voice [Explainer] uses.
  static const String systemPrompt =
      'You are a tutor answering a student\'s question about their own notes, '
      'using ONLY the passages from those notes given below. These passages are '
      'the only source of truth. '
      'If they do not contain enough to answer, reply exactly: '
      '"I couldn\'t find the answer to that in your notes." and stop — do NOT '
      'fall back on outside knowledge, and do NOT guess. Never invent facts, '
      'numbers, names, dates, or quotes that are not in the passages. Answer in '
      'a few clear sentences, and refer to the passages by their number (e.g. '
      '[1]) when you use them. '
      'Answer the way a tutor would say it out loud: go straight to the answer '
      'with no preamble, no greeting, no restating of the question, and no '
      'closing offer of further help. Talk about the material rather than the '
      'passages as documents — "the reaction needs a catalyst [2]", not "the '
      'passages indicate that…". Plain, warm, direct prose; no bullet points, '
      'no bold labels, no emoji, and no filler like "certainly" or "it is '
      'important to note".';

  /// The exact refusal the model is told to emit — surfaced so the UI can
  /// recognise a grounded "not found" and present it plainly (no source chips,
  /// no "insert as note") rather than as a normal answer.
  static const String notFoundReply =
      "I couldn't find the answer to that in your notes.";

  /// Retrieves the passages most relevant to [question] within [notebookId].
  ///
  /// Empty means "ask anyway produced nothing" — an empty/unindexed notebook,
  /// a model not downloaded, or simply a question the notes don't touch. The
  /// caller must treat empty as a grounded "not found" and NOT call [answer].
  Future<List<RetrievedChunk>> findSources({
    required String question,
    required int notebookId,
    int topK = kRetrievalTopK,
  }) {
    return _retriever.search(
      query: question,
      notebookId: notebookId,
      topK: topK,
    );
  }

  /// Streams an answer to [question] grounded in [sources].
  ///
  /// [sources] must be non-empty (retrieve first via [findSources]); passing
  /// none is a programming error, since with nothing to ground on the honest
  /// output is the [notFoundReply], decided without the model. Provider failures
  /// propagate as the stream's error — nothing here swallows them.
  Stream<String> answer({
    required String question,
    required List<RetrievedChunk> sources,
  }) {
    assert(sources.isNotEmpty,
        'answer() needs sources; call findSources first and handle empty.');

    final passages = _formatPassages(sources);
    final prompt = 'PASSAGES FROM YOUR NOTES:\n$passages\n\n'
        'QUESTION: ${question.trim()}';

    return _provider.generate(
      prompt: prompt,
      systemPrompt: systemPrompt,
      options: const AiGenerationOptions(
        // Low temperature: this is grounded extraction, not creative writing.
        temperature: 0.2,
        topP: 0.9,
        maxTokens: 512,
      ),
    );
  }

  /// Numbers the passages ([1], [2], …) so the model can reference them and the
  /// numbers line up with the source chips the UI shows in the same order.
  ///
  /// The combined passages are budgeted to the provider's input window: with
  /// top-5 ~250-word chunks that's ~1,250 words (well under Gemma's budget), but
  /// a larger topK or model swap must truncate rather than overrun. Whole
  /// passages are dropped from the end rather than cutting one mid-sentence, so
  /// every number the model sees maps to a passage it saw in full.
  String _formatPassages(List<RetrievedChunk> sources) {
    final budget = AiRouter.inputWordBudgetFor(_provider.capabilities);
    final buffer = StringBuffer();
    var used = 0;
    for (var i = 0; i < sources.length; i++) {
      final text = sources[i].chunk.text.trim();
      final cost = countWords(text);
      if (i > 0 && used + cost > budget) break;
      if (i > 0) buffer.write('\n\n');
      buffer.write('[${i + 1}] $text');
      used += cost;
    }
    return buffer.toString();
  }
}
