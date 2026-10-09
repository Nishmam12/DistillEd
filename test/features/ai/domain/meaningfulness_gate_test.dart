import 'package:flutter_test/flutter_test.dart';

import 'package:distill_ed/features/ai/domain/meaningfulness_gate.dart';

void main() {
  const gate = MeaningfulnessGate();

  group('MeaningfulnessGate', () {
    test('fails text with fewer than 10 words', () {
      final r = gate.evaluate('meeting notes about the project');
      expect(r.passed, isFalse);
      expect(r.failure, GateFailure.tooShort);
    });

    test('passes a plausible 10+ word note', () {
      final r = gate.evaluate(
          'the meeting covered budget planning and the new hiring timeline for the design team');
      expect(r.passed, isTrue);
      expect(r.failure, isNull);
    });

    test('fails symbol/number gibberish (low alphabetic-token ratio)', () {
      final r = gate.evaluate('7 42 -- 13 * 99 ++ 3.14 // 8 == 0 %% 5');
      expect(r.passed, isFalse);
      expect(r.failure, GateFailure.lowAlphaRatio);
    });

    test('Bengali counts as alphabetic (Unicode letters, not just Latin)', () {
      final r = gate.evaluate(
          'আজকের সভায় বাজেট পরিকল্পনা এবং নতুন নিয়োগের সময়সূচি নিয়ে আলোচনা হয়েছে বিস্তারিতভাবে');
      expect(r.passed, isTrue);
    });

    test('fails when average candidate score is high (low confidence)', () {
      const text =
          'these ten recognized words look fine but the recognizer was actually guessing';
      final bad = gate.evaluate(text, topScores: [12.0, 15.0]);
      expect(bad.passed, isFalse);
      expect(bad.failure, GateFailure.lowConfidence);

      final good = gate.evaluate(text, topScores: [1.2, 0.8]);
      expect(good.passed, isTrue);
    });

    group('digits as content', () {
      // A page-level "is this real writing" gate is right to count letters only:
      // a screen of numbers is not a note worth summarising. A line reading is a
      // different question — `x^2 + 3x = 0` is plainly content, and a bare page
      // number is too — so the gate can be told to count digits.
      const strict = MeaningfulnessGate(minWords: 1, minAlphaRatio: 0.5);
      const lenient = MeaningfulnessGate(
          minWords: 1, minAlphaRatio: 0.5, countDigits: true);

      test('by default digits do not count (the existing behaviour)', () {
        expect(strict.evaluate('x^2 + 3x = 0').passed, isFalse);
        expect(strict.evaluate('42').passed, isFalse);
      });

      test('when asked, maths and numbers are content', () {
        expect(lenient.evaluate('x^2 + 3x = 0').passed, isTrue);
        expect(lenient.evaluate('42').passed, isTrue);
      });

      test('symbol soup is still rejected either way', () {
        expect(lenient.evaluate(':::::::::').passed, isFalse);
        expect(lenient.evaluate(r'### $$$ %%%').passed, isFalse);
      });
    });

    test('score rule is skipped when no scores are available', () {
      const text =
          'these ten recognized words look fine and no scores were reported at all';
      expect(gate.evaluate(text).passed, isTrue);
    });

    test('empty text fails as too short', () {
      final r = gate.evaluate('');
      expect(r.passed, isFalse);
      expect(r.failure, GateFailure.tooShort);
    });

    test('thresholds are injectable for calibration', () {
      const strict = MeaningfulnessGate(minWords: 3, maxAvgScore: 1.0);
      expect(strict.evaluate('short note here').passed, isTrue);
      expect(
        strict.evaluate('short note here', topScores: [2.0]).failure,
        GateFailure.lowConfidence,
      );
    });
  });
}
