// Plan 5.7: the teacher persona must not be paid for out of the student's
// passages.
//
// Ask is the feature measured, because it is the one that carries passages.
// The persona is NOT wired into Ask yet, so `_askWithPersona` builds the
// prompt the way plan 5.4 says Ask will: contract first, then role, rules,
// voice, and the per-call tail last.
//
// TODO(part 2 wiring): once `NotesQa.systemPromptFor` exists, build the prompt
// with it here instead of `_askWithPersona`, and delete the helper. The
// numbers asserted must not change.

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/core/providers/settings_provider.dart' show TeachingStyle;
import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/ai_router.dart';
import 'package:margo/features/ai/domain/context_engine/page_context.dart';
import 'package:margo/features/ai/domain/features/explainer.dart';
import 'package:margo/features/ai/domain/features/notes_qa.dart';
import 'package:margo/features/ai/domain/tutor/tutor_prompt.dart';
import 'package:margo/features/ai/domain/tutor_voice.dart';

AiCapabilities _caps(int window) => AiCapabilities(
      modelId: 'm$window',
      displayName: 'm$window',
      contextWindowTokens: window,
      isLocal: true,
    );

/// The most a tail can cost: guide style in a grounded feature, with every
/// profile field set and five concept names at the length limit.
final _worstCase = TutorContext(
  style: TeachingStyle.guide,
  profile: LearnerProfile(
    level: KnowledgeLevel.intermediate,
    weakConcepts: [
      for (var i = 0; i < 5; i++) '$i${'m' * (kMaxConceptNameChars - 1)}',
    ],
    preferredMode: ExplainMode.mathematical,
  ),
);

String _askWithPersona(TutorContext context, int window) {
  final constantPart = NotesQa.systemPrompt.replaceFirst(
    kTutorVoiceWithMath,
    '$kTutorRole\n\n$kTeachingRules\n\n$kTutorVoiceWithMath',
  );
  return withTutorTail(
    constantPart,
    tutorTail(context,
        windowTokens: window, allowCheckQuestion: true, grounded: true),
  );
}

int _words(String system, int window) => AiRouter.inputWordBudgetFor(
      _caps(window),
      systemPrompt: system,
      responseTokens: NotesQa.answerOptions.maxTokens!,
    );

void main() {
  test('the helper really inserts the persona', () {
    final prompt = _askWithPersona(_worstCase, 4096);
    expect(prompt, contains(kTutorRole));
    expect(prompt, contains(kTeachingRules));
    expect(prompt, contains(kTutorVoiceWithMath));
    expect(prompt, endsWith(kStyleGuideGrounded));
    // Grounding before persona (plan 5.8).
    expect(prompt.indexOf('ONLY the passages'),
        lessThan(prompt.indexOf(kTutorRole)));
  });

  test('on the 4,096 window five 250-word passages still fit, at worst', () {
    expect(_words(_askWithPersona(_worstCase, 4096), 4096),
        greaterThanOrEqualTo(1250));
  });

  test('on the 2,048 window the persona costs at most 60 words of passage',
      () {
    // 690 is what Ask's prompt left for passages on this window BEFORE the
    // persona existed, measured on 2026-11-17 with this same call on
    // `NotesQa.systemPrompt`. It is a literal on purpose: once the persona is
    // part of that constant, measuring "today" here would compare the persona
    // with itself and pass whatever it cost.
    //
    // Measured the same day: 644 with the plain context, 631 with a guide
    // tail. One word of room, so re-measure after any change to a compact
    // constant.
    const beforePersona = 690;
    const window = kCompactPromptWindowTokens;
    for (final context in [TutorContext.plain, _worstCase]) {
      final withPersona = _words(_askWithPersona(context, window), window);
      expect(withPersona, greaterThanOrEqualTo(beforePersona - 60),
          reason: 'style ${context.style.name}: $withPersona words left');
    }
  });

  test('on the 2,048 window the composed prompt, a passage and a reply fit',
      () {
    // The same check `lite_window_budget_test.dart` makes of today's prompts.
    const window = kCompactPromptWindowTokens;
    const reply = 512;
    final system = _askWithPersona(_worstCase, window);
    final words = _words(system, window);
    expect(words, greaterThanOrEqualTo(300));

    final sent = compactForWindow(system, window);
    final replyCap = AiRouter.replyCapFor(window);
    final total = sent.length / AiRouter.charsPerToken +
        AiRouter.scaffoldingReserveTokens +
        words * AiRouter.tokensPerWord +
        (reply < replyCap ? reply : replyCap);
    expect(total, lessThanOrEqualTo(window));
  });

  test('a tail built for a large window still leaves room on a small one', () {
    // A caller that sizes the tail for a cloud model and then falls back to
    // the lite on-device model sends the long tail to a 2,048 window. That is
    // a wiring mistake, but it must cost passages, not overflow.
    const window = kCompactPromptWindowTokens;
    final system = _askWithPersona(_worstCase, 128000);
    expect(_words(system, window), greaterThanOrEqualTo(300));
  });
}
