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
import '../ai_scope.dart';
import '../quality/output_quality.dart';
import '../rag/rag_retriever.dart';
import '../text_budget.dart';
import '../tutor_voice.dart';

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
  /// the tutor who read those notes with them. That register is [kTutorVoice],
  /// shared with [Explainer] and Summarize.
  ///
  /// The grounding half is unconditional and is stated FIRST, before the voice,
  /// so that nothing in the style instructions can read as licence to fill a
  /// gap: "state it plainly and confidently" applies to what the passages
  /// support, and to nothing else. When they support nothing, the only correct
  /// output is [notFoundReply].
  static const String systemPrompt =
      'You are a tutor answering a student\'s question about their own notes, '
      'using ONLY the passages from those notes given below. These passages are '
      'the only source of truth. '
      'If they do not contain enough to answer, reply exactly: '
      '"I couldn\'t find the answer to that in your notes." and stop — do NOT '
      'fall back on outside knowledge, and do NOT guess. Never invent facts, '
      'numbers, names, dates, or quotes that are not in the passages. '
      'Answer in a few clear sentences, and refer to the passages by their '
      'number (e.g. [1]) when you use them. Talk about the material rather '
      'than about the passages as documents: "the reaction needs a catalyst '
      '[2]", not "the passages indicate that…". Go straight to the answer, '
      'with no restating of the question.\n\n'
      '$kTutorVoiceWithMath';

  /// The exact refusal the model is told to emit — surfaced so the UI can
  /// recognise a grounded "not found" and present it plainly (no source chips,
  /// no "insert as note") rather than as a normal answer.
  static const String notFoundReply =
      "I couldn't find the answer to that in your notes.";

  /// Retrieves the passages most relevant to [question] within [notebookId].
  ///
  /// [scope] narrows the search to one page or one imported PDF; omitting it
  /// searches the whole notebook, which is what this did before scopes existed.
  /// Scoping happens HERE, at retrieval, rather than by filtering an answer
  /// afterwards — the grounding contract is that the model only ever sees
  /// passages from inside the scope, so a passage outside it must never reach
  /// the prompt in the first place.
  ///
  /// Empty means "ask anyway produced nothing" — an empty/unindexed notebook,
  /// a model not downloaded, or simply a question the notes don't touch. The
  /// caller must treat empty as a grounded "not found" and NOT call [answer].
  Future<List<RetrievedChunk>> findSources({
    required String question,
    required int notebookId,
    AiScope? scope,
    int topK = kRetrievalTopK,
  }) {
    return _retriever.search(
      query: question,
      notebookId: notebookId,
      pageIds: scope?.kind == AiScopeKind.notebook ? null : scope?.pageIdSet,
      topK: topK,
    );
  }

  /// Sampling for a grounded answer. Low temperature: this is grounded
  /// extraction, not creative writing. A constant so the quality guard's cloud
  /// re-run asks the cloud tier for the same thing the local tier was asked.
  static const AiGenerationOptions answerOptions = AiGenerationOptions(
    temperature: 0.2,
    topP: 0.9,
    maxTokens: 512,
  );

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
    // Refusing, rather than the assert this used to carry.
    //
    // An assert is debug-only, and this is the one place where a caller bug
    // becomes a BROKEN PROMISE rather than a crash: with no passages the prompt
    // reduces to a bare question under a system prompt that says "use only the
    // passages below", and a model shown no passages answers from world
    // knowledge while the UI presents it as coming from the student's notes.
    // A release build must not do that, so the guard is real code — and being
    // real code, it is also testable, which an assert is not.
    //
    // Callers should still retrieve first and handle empty themselves (the
    // notifier does, and reports a grounded "not found" without paying for a
    // model load); this is the backstop, not the intended path.
    if (sources.isEmpty) return Stream.value(notFoundReply);

    return _provider.generate(
      prompt: promptFor(question: question, sources: sources),
      systemPrompt: systemPrompt,
      options: answerOptions,
    );
  }

  /// The exact user-side prompt for a grounded answer.
  ///
  /// Exposed so [AiQualityGuard] can re-run the SAME question against the cloud
  /// tier when the local answer fails its quality check. Building it here rather
  /// than in the guard keeps one definition of what the model is shown — a
  /// cloud re-run that saw different passages would not be a check on anything.
  String promptFor({
    required String question,
    required List<RetrievedChunk> sources,
  }) =>
      'PASSAGES FROM YOUR NOTES:\n${_formatPassages(sources)}\n\n'
      'QUESTION: ${question.trim()}';

  /// What the answer must be grounded in, for the quality check.
  ///
  /// Carries [notFoundReply] as the permitted refusal: a correct refusal is
  /// short and shares no vocabulary with the passages, which is exactly what the
  /// "ignored its sources" heuristic looks for. Without this the app would
  /// escalate every honest "not in your notes" to the cloud and have it answered
  /// from world knowledge — the precise failure the whole feature exists to
  /// prevent.
  static QualityContext qualityContextFor(List<RetrievedChunk> sources) =>
      QualityContext(
        sourcePassages: [for (final s in sources) s.chunk.text],
        allowedRefusal: notFoundReply,
      );

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
