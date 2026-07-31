// Model TONE cannot be unit tested — there is no model in a unit test, and the
// same prompt yields different prose every run. What CAN be tested, and what
// actually regresses, is the prompt engineering that drives it: that every
// feature which speaks to the student carries the anti-AI-voice instructions,
// that the maths convention reaches every surface that can produce a formula,
// and — the part most at risk from a well-meaning edit — that none of the new
// naturalness wording has displaced a faithfulness contract.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/context_engine/context_engine.dart';
import 'package:inkflow/features/ai/domain/features/explainer.dart';
import 'package:inkflow/features/ai/domain/features/notes_qa.dart';
import 'package:inkflow/features/ai/domain/tutor_voice.dart';
import 'package:inkflow/features/summarize/domain/services/summarization_service.dart';

/// Every prose-speaking prompt in the app, by the name a failure should name.
Map<String, String> prosePrompts() => {
      for (final mode in ExplainMode.values)
        'Explain (${mode.label})': Explainer.systemPromptFor(mode),
      'Ask your notes': NotesQa.systemPrompt,
      'Summarize (note)': SummarizationService.noteInstruction,
      'Summarize (section pass)': SummarizationService.sectionInstruction,
      'Summarize (reduce pass)': SummarizationService.reduceInstruction,
    };

void main() {
  group('the tutor voice reaches every prose feature', () {
    test('each prose prompt carries the shared voice verbatim', () {
      prosePrompts().forEach((name, prompt) {
        expect(prompt, contains(kTutorVoice),
            reason: '$name must use the shared voice, not its own copy of it');
      });
    });

    test('each prose prompt carries the maths convention', () {
      prosePrompts().forEach((name, prompt) {
        expect(prompt, contains(kMathMarkup), reason: name);
      });
    });
  });

  group('the voice names the specific AI tells, not just "be natural"', () {
    // Each of these is a documented tell (see tutor_voice.dart's header). A
    // model given a general instruction keeps its defaults, so the named ones
    // are the whole mechanism — dropping any is a silent regression in tone.
    const mustName = [
      'As an AI',
      "I'd be happy to",
      'Certainly',
      'Great question',
      "Let's break this down step by step",
      'it is important to note that',
      'delve into',
      'Furthermore',
      'Moreover',
      'In conclusion',
      'experts say',
      'studies show',
    ];

    for (final phrase in mustName) {
      test('forbids $phrase', () {
        expect(kTutorVoice, contains(phrase));
      });
    }

    test('caps dash use rather than leaving it to the model', () {
      expect(kTutorVoice, contains('At most one dash'));
    });

    test('forbids rule-of-three padding', () {
      expect(kTutorVoice.toLowerCase(), contains('threes'));
    });

    test('forbids bullet lists, headings and emoji in the reply', () {
      expect(kTutorVoice, contains('No headings, no bullet lists'));
      expect(kTutorVoice, contains('emoji'));
    });
  });

  group('the voice asks for the positive tutor behaviours too', () {
    test('varied sentence length', () {
      expect(kTutorVoice, contains('Vary your sentence length'));
    });

    test('direct address', () {
      expect(kTutorVoice, contains('directly as "you"'));
    });

    test("concrete specifics from the student's own material", () {
      expect(kTutorVoice, contains('concrete specifics from their own'));
    });

    test('plain confident statements instead of blanket hedging', () {
      expect(kTutorVoice, contains('plainly and confidently'));
    });

    test('a check for understanding, without the generic version of it', () {
      expect(kTutorVoice, contains('checking understanding'));
      expect(kTutorVoice, contains('does that make sense'),
          reason: 'the generic form is named so the model avoids it');
    });
  });

  group('faithfulness survives the rewrite', () {
    // The naturalness instructions must not have loosened any grounding rule.
    // These assertions are the contract, and are deliberately literal.
    test('Ask still orders the exact refusal string', () {
      expect(NotesQa.systemPrompt, contains(NotesQa.notFoundReply));
    });

    test('the refusal string itself is unchanged', () {
      expect(NotesQa.notFoundReply,
          "I couldn't find the answer to that in your notes.");
    });

    test('Ask still forbids falling back on outside knowledge', () {
      expect(NotesQa.systemPrompt, contains('ONLY the passages'));
      expect(NotesQa.systemPrompt, contains('do NOT guess'));
      expect(NotesQa.systemPrompt, contains('Never invent facts'));
    });

    test('Ask states the grounding rule before the style rules', () {
      // Order matters: "state it confidently" read before "only use the
      // passages" is an invitation to fill a gap confidently.
      expect(NotesQa.systemPrompt.indexOf('ONLY the passages'),
          lessThan(NotesQa.systemPrompt.indexOf(kTutorVoice)));
    });

    test('Explain still refuses to contradict the passage, in every mode', () {
      for (final mode in ExplainMode.values) {
        final prompt = Explainer.systemPromptFor(mode);
        expect(prompt, contains('never invent specifics'), reason: mode.label);
        expect(prompt, contains('contradict it'), reason: mode.label);
      }
    });

    test('Explain still teaches the subject rather than describing the text',
        () {
      for (final mode in ExplainMode.values) {
        expect(Explainer.systemPromptFor(mode), contains('SUBJECT of the passage'),
            reason: mode.label);
      }
    });

    test('Summarize still forbids inventing facts', () {
      expect(SummarizationService.noteInstruction,
          contains('never invent facts, names, dates, or numbers'));
      expect(SummarizationService.reduceInstruction,
          contains('never invent facts, names, dates, or numbers'));
    });

    test('the Context Engine still forbids invention', () {
      expect(ContextEngine.schemaInstruction,
          contains('Never invent facts, names, or definitions'));
    });
  });

  group('the maths convention is specific enough to parse against', () {
    test('names the inline and block delimiters', () {
      expect(kMathMarkup, contains(r'$E = mc^2$'));
      expect(kMathMarkup, contains(r'$$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$'));
    });

    test('forbids bare Unicode and undelimited LaTeX', () {
      expect(kMathMarkup, contains('Unicode symbols'));
      expect(kMathMarkup, contains('without their dollar delimiters'));
    });

    test('reaches the Context Engine, whose definitions can be formulas', () {
      // The Context Engine emits JSON, so it takes the maths rule WITHOUT the
      // prose voice — asserted both ways so neither is bolted on by accident.
      expect(ContextEngine.schemaInstruction, contains(kMathMarkup));
      expect(ContextEngine.schemaInstruction, isNot(contains(kTutorVoice)));
    });
  });
}
