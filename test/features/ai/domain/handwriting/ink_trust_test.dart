// Whether ML Kit's reading of one handwritten line can be taken as it is, or the
// line is worth loading the big vision model for.
//
// The cost of a wrong "trusted" is a misread line in the page text; the cost of
// a wrong "needs vision" is a 3.6–17 s model load. So the bar is set to catch
// what ML Kit reliably gets wrong — symbol soup, low-confidence reads, and
// two-dimensional maths — and to leave ordinary prose alone.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/handwriting/ink_trust.dart';

void main() {
  bool needs(
    String text, {
    double? score = 2.0,
    double height = 40,
    double median = 40,
  }) =>
      inkLineNeedsVision(
          text: text, score: score, lineHeight: height, medianLineHeight: median);

  group('plain writing is trusted', () {
    test('a confident line of prose', () {
      expect(needs('Mitochondria produce most of the cell\'s ATP.'), isFalse);
    });

    test('prose with a number, a hyphen and brackets is still prose', () {
      expect(needs('Chapter 3: a well-known result (see page 4)'), isFalse);
      expect(needs('Due on 12 March'), isFalse);
    });

    test('numbering, page numbers and dates are not worth a model load', () {
      // Digits are content, not symbol soup, and none of these is maths.
      expect(needs('42'), isFalse);
      expect(needs('1.'), isFalse);
      expect(needs('(a)'), isFalse);
      expect(needs('12/03/2024'), isFalse);
      expect(needs('3/4'), isFalse);
    });

    test('a line with no score is judged on its text alone', () {
      expect(needs('Newton\'s second law', score: null), isFalse);
    });

    test('nothing recognised is nothing to refine', () {
      // Ink that reads as no text at all is usually a doodle or a diagram, which
      // the figure pass owns — not handwriting for the OCR model to guess at.
      expect(needs(''), isFalse);
      expect(needs('   '), isFalse);
    });
  });

  group('lines ML Kit probably got wrong', () {
    test('a low-confidence read (a high score is a LOW likelihood)', () {
      expect(needs('Mitochondria produce ATP', score: 9.5), isTrue);
    });

    test('symbol soup', () {
      expect(needs(':::::::::'), isTrue);
      expect(needs('### %%% @@@'), isTrue);
    });
  });

  group('maths goes to the model that can see structure', () {
    test('an equation, even when ML Kit was confident', () {
      expect(needs('x^2 + 3x = 0', score: 1.0), isTrue);
      expect(needs('E = mc2', score: 1.0), isTrue);
    });

    test('calculus and set symbols', () {
      expect(needs('∫ f(x) dx'), isTrue);
      expect(needs('Σ a_n'), isTrue);
      expect(needs('√2 ≈ 1.41'), isTrue);
    });

    test('a line that is mostly numbers and operators', () {
      expect(needs('12 + 7 - 3 * 4'), isTrue);
    });

    test('a tall line — stacked fractions, limits, matrices', () {
      // Clean text, but three times the usual line height: something is stacked
      // on top of something else, and one-dimensional recognition flattens it.
      expect(needs('one over two', height: 130, median: 40), isTrue);
    });

    test('tallness is only judged against a real typical height', () {
      expect(needs('Some words', height: 130, median: 0), isFalse);
    });

    test('a heading written a little larger is not "tall"', () {
      expect(needs('Chapter Summary', height: 70, median: 40), isFalse);
    });
  });
}
