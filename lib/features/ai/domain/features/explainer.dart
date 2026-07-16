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
  static const String _base =
      'You are a patient tutor helping a student understand their own notes. '
      'Explain the passage below. Base the explanation on the passage; you may '
      'add widely-known background that helps understanding, but never invent '
      'specifics (names, dates, numbers, quotes) that contradict it. Be '
      'concise and do not restate the whole passage first.';

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
            'or formulas, and walk through the reasoning step by step.',
    ExplainMode.realWorld:
        'Explain with a real-world analogy: map the idea onto a concrete, '
            'familiar situation, then connect the analogy back to the passage.',
  };

  final AiProvider _provider;
  const Explainer({required AiProvider provider}) : _provider = provider;

  /// System prompt for [mode] — exposed for tests and prompt review.
  static String systemPromptFor(ExplainMode mode) =>
      '$_base\n\n${_modeInstruction[mode]}';

  /// Streams the explanation for [input]. Emits incremental chunks (concatenate
  /// in order). Throws/streams-errors from the provider are not caught here.
  Stream<String> explain(ExplainInput input) {
    final budget = AiRouter.inputWordBudgetFor(_provider.capabilities);
    final content = truncateToWords(input.content.trim(), budget);
    return _provider.generate(
      prompt: 'PASSAGE:\n$content',
      systemPrompt: systemPromptFor(input.mode),
      options: const AiGenerationOptions(
        temperature: 0.4,
        topP: 0.95,
        maxTokens: 512,
      ),
    );
  }
}
