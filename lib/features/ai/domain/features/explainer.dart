// Explain: turn a selected passage (or an undefined term flagged by the Context
// Engine) into a streamed explanation, at a chosen depth/register.
//
// A thin feature on the AI platform: it builds a per-mode system prompt and
// streams straight from the local [AiProvider]. Content is budgeted to the
// provider's context window (an explanation target is normally a short passage,
// but a big lasso selection is truncated rather than overrunning the model).
// Provider failures ([AiModelNotReadyException] etc.) propagate as the stream's
// error for the caller to surface — nothing here swallows them.

import '../ai_provider.dart';
import '../ai_router.dart';
import '../text_budget.dart';
import '../tutor_voice.dart';

/// How the explanation should be pitched. The first four are the Phase-1
/// definition-of-done set; the rest come from the plan doc.
enum ExplainMode {
  beginner,
  intermediate,
  advanced,
  child,
  visual,
  mathematical,
  realWorld,
}

extension ExplainModeLabel on ExplainMode {
  /// Short label for the mode picker / header.
  String get label => switch (this) {
        ExplainMode.beginner => 'Beginner',
        ExplainMode.intermediate => 'Intermediate',
        ExplainMode.advanced => 'Advanced',
        ExplainMode.child => 'Like I\'m 10',
        ExplainMode.visual => 'Visual',
        ExplainMode.mathematical => 'Mathematical',
        ExplainMode.realWorld => 'Real-world',
      };
}

/// One explanation request: the text to explain and the register to use.
class ExplainInput {
  final String content;
  final ExplainMode mode;
  const ExplainInput({required this.content, required this.mode});
}

class Explainer {
  /// Shared preamble — the faithfulness contract is identical across modes.
  ///
  /// The explicit "never talk about the passage itself" line exists because
  /// small on-device models, given a short passage (a bare term or a single
  /// clause), default to describing/critiquing the passage as text ("this
  /// passage points out a gap...") instead of teaching its subject. Confirmed
  /// on-device with Gemma 4 E2B, 2026-07-18 — a full paragraph passage didn't
  /// trigger it, but the knowledge-gap explain flow's short input reliably did.
  ///
  /// The register comes from [kTutorVoice], shared with Ask and Summarize so a
  /// student hears one voice across the app rather than three. What stays here
  /// is only what is specific to explaining: teach the SUBJECT, not the text,
  /// and never contradict the passage.
  static const String _base = 'You are a patient tutor helping one student '
      'understand a topic from their own notes.\n\n'
      '$kTutorVoiceWithMath\n\n'
      'Explain the SUBJECT of the passage below, the way a tutor teaches a '
      'topic out loud. Never describe, summarize, or comment on the passage '
      'itself as a piece of text (nothing like "this passage states" or "the '
      'notes don\'t cover"). Base the explanation on the passage; you may add '
      'widely-known background that helps understanding, but never invent '
      'specifics (names, dates, numbers, quotes) that contradict it. Be '
      'concise, and do not restate the whole passage before you start.';

  static const Map<ExplainMode, String> _modeInstruction = {
    ExplainMode.beginner:
        'Explain for a beginner: plain language, no jargon; define any term '
            'you must use.',
    ExplainMode.intermediate:
        'Explain for someone with some background: normal terminology, focus '
            'on the why and how.',
    ExplainMode.advanced:
        'Explain for an advanced learner: precise terminology, underlying '
            'mechanisms, edge cases and caveats.',
    ExplainMode.child:
        'Explain as if to a curious 10-year-old: short sentences, everyday '
            'words, one friendly example.',
    ExplainMode.visual:
        'Describe it visually: lay out the structure as a described diagram — '
            'components and how they connect, as text (do NOT attempt to draw '
            'an image).',
    ExplainMode.mathematical:
        'Explain the mathematics: define the symbols, state the relationships '
            'or formulas, and walk through the reasoning a step at a time. '
            'Every symbol and formula goes in LaTeX dollar delimiters, and a '
            'formula the student needs to look at gets its own \$\$…\$\$ line.',
    ExplainMode.realWorld:
        'Explain with a real-world analogy: map the idea onto a concrete, '
            'familiar situation, then connect the analogy back to the passage.',
  };

  final AiProvider _provider;
  const Explainer({required AiProvider provider}) : _provider = provider;

  /// System prompt for [mode] — exposed for tests and prompt review.
  static String systemPromptFor(ExplainMode mode) =>
      '$_base\n\n${_modeInstruction[mode]}';

  /// Sampling for an explanation. A constant so a cloud re-run through
  /// [AiQualityGuard] asks the cloud tier for the same thing the local tier was
  /// asked, rather than quietly changing the request along with the model.
  static const AiGenerationOptions explainOptions = AiGenerationOptions(
    temperature: 0.4,
    topP: 0.95,
    maxTokens: 512,
  );

  /// The user-side prompt for [content]. Exposed alongside [systemPromptFor] so
  /// the quality guard can re-issue an identical request to the cloud tier.
  static String promptFor(String content) => 'PASSAGE:\n${content.trim()}';

  /// Streams the explanation for [input]. Emits incremental chunks (concatenate
  /// in order). Throws/streams-errors from the provider are not caught here.
  Stream<String> explain(ExplainInput input) {
    final budget = AiRouter.inputWordBudgetFor(_provider.capabilities);
    final content = truncateToWords(input.content.trim(), budget);
    return _provider.generate(
      prompt: promptFor(content),
      systemPrompt: systemPromptFor(input.mode),
      options: explainOptions,
    );
  }
}
