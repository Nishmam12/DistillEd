import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/quality/output_quality.dart';

const _passages = [
  'Photosynthesis converts light energy into glucose inside the chloroplast. '
      'The light-dependent reactions happen in the thylakoid membrane.',
  'Respiration releases the energy stored in glucose. In humans this happens '
      'in the mitochondria and produces 36 ATP per molecule.',
];

const _grounded = QualityContext(
  sourcePassages: _passages,
  allowedRefusal: "I couldn't find the answer to that in your notes.",
);

void main() {
  group('good output passes', () {
    test('a citation marker is not read as an unsupported number', () {
      // NotesQa ORDERS the model to cite passages as [1]/[2]; flagging those
      // would fail every correctly-cited answer.
      const answer = 'Photosynthesis happens in the chloroplast [1], and '
          'respiration happens in the mitochondria [2].';
      expect(checkOutputQuality(answer, context: _grounded).passed, isTrue);
    });

    test('an ordinary grounded answer', () {
      const answer = 'Photosynthesis happens in the chloroplast, where the '
          'light-dependent reactions take place in the thylakoid membrane [1].';
      expect(checkOutputQuality(answer, context: _grounded).passed, isTrue);
    });

    test('an ordinary ungrounded explanation', () {
      const answer = 'A catalyst lowers the activation energy a reaction needs, '
          'so more collisions have enough energy to succeed. It is not used up '
          'along the way, which is why a small amount goes a long way.';
      expect(checkOutputQuality(answer).passed, isTrue);
    });

    test('a short but complete answer', () {
      expect(checkOutputQuality('In the mitochondria.', context: _grounded).passed,
          isTrue);
    });

    test('an answer that repeats a topic word often is not degeneration', () {
      const answer = 'Photosynthesis needs light. Photosynthesis happens in the '
          'chloroplast, and photosynthesis produces glucose from that light '
          'energy inside the thylakoid membrane of the chloroplast.';
      expect(checkOutputQuality(answer, context: _grounded).passed, isTrue);
    });
  });

  group('broken output is caught', () {
    test('an empty reply', () {
      expect(checkOutputQuality('').issue, QualityIssue.empty);
      expect(checkOutputQuality('   \n  ').issue, QualityIssue.empty);
    });

    test('a reply with almost nothing in it', () {
      expect(checkOutputQuality('ok.').issue, QualityIssue.empty);
    });

    test('a repetition loop', () {
      const looping = 'The answer is in the notes. The answer is in the notes. '
          'The answer is in the notes. The answer is in the notes.';
      expect(checkOutputQuality(looping).issue, QualityIssue.repetition);
    });

    test('a degenerate reply with almost no distinct words', () {
      final degenerate = List.filled(40, 'the cell').join(' ');
      expect(checkOutputQuality(degenerate).issue, isNotNull);
    });
  });

  group('grounding checks (only for grounded features)', () {
    test('an answer written from world knowledge is caught', () {
      // Nothing here comes from the passages: this is the model answering from
      // its training data while claiming to read the student's notes.
      const answer = 'Napoleon Bonaparte was crowned Emperor of the French in '
          'a ceremony at Notre-Dame, having risen through the artillery during '
          'the revolutionary wars in Corsica and Italy.';
      expect(checkOutputQuality(answer, context: _grounded).issue,
          QualityIssue.ignoredSources);
    });

    test('a number the passages never state is caught', () {
      const answer = 'Respiration in the mitochondria produces 38 ATP per '
          'glucose molecule, releasing the stored energy.';
      expect(checkOutputQuality(answer, context: _grounded).issue,
          QualityIssue.unsupportedClaim);
    });

    test('a number the passages DO state is fine', () {
      const answer = 'Respiration in the mitochondria produces 36 ATP per '
          'glucose molecule, releasing the stored energy.';
      expect(checkOutputQuality(answer, context: _grounded).passed, isTrue);
    });

    test('the same off-source answer passes when the feature is ungrounded',
        () {
      // Explain may bring in widely-known background; the grounding checks must
      // not fire on a feature that was never grounded in the first place.
      const answer = 'Napoleon Bonaparte was crowned Emperor of the French in '
          'a ceremony at Notre-Dame, having risen through the artillery during '
          'the revolutionary wars in Corsica and Italy.';
      expect(checkOutputQuality(answer).passed, isTrue);
    });
  });

  group('a grounded refusal is a GOOD answer', () {
    // The most damaging false positive available: escalating an honest "not in
    // your notes" to the cloud, which would then answer it from world
    // knowledge — destroying the exact contract the feature is built on.
    test('the exact refusal passes', () {
      expect(
        checkOutputQuality("I couldn't find the answer to that in your notes.",
                context: _grounded)
            .passed,
        isTrue,
      );
    });

    test('a refusal with trailing whitespace passes', () {
      expect(
        checkOutputQuality(
                "  I couldn't find the answer to that in your notes.  \n",
                context: _grounded)
            .passed,
        isTrue,
      );
    });

    test('a refusal is only exempt where one is permitted', () {
      // With no allowedRefusal declared, the same short off-source sentence is
      // just a short off-source sentence.
      const noRefusal = QualityContext(sourcePassages: _passages);
      expect(
        checkOutputQuality(
                "I couldn't find the answer to that in your notes anywhere at "
                'all, sorry about that, please try another question entirely.',
                context: noRefusal)
            .passed,
        isFalse,
      );
    });
  });

  test('issues carry a message written for a student', () {
    for (final issue in QualityIssue.values) {
      expect(issue.message, isNotEmpty);
      expect(issue.message, isNot(contains('QualityIssue')));
    }
  });
}
