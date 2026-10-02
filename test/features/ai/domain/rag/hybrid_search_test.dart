// The model-free half of retrieval: keyword ranking and rank fusion.
//
// Embeddings blur exactly the things a student searches for by name — a course
// code, a formula, a defined term — and handwriting recognition makes it worse.
// These pin what the keyword side must get right, with expectations worked out
// by hand rather than computed by the code under test.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/rag/hybrid_search.dart';

void main() {
  group('keywordTokens', () {
    test('lowercases and splits on punctuation, keeping codes and digits', () {
      expect(keywordTokens('Gibbs Free-Energy (CSE-101), type 2 diabetes'),
          ['gibbs', 'free', 'energy', 'cse', '101', 'type', '2', 'diabetes']);
    });

    test('drops stray single letters but not single digits', () {
      // "Bernoulli's" must not leave a lone "s" that matches half the notebook.
      expect(keywordTokens("Bernoulli's law, 5 a"), ['bernoulli', 'law', '5']);
    });

    test('keeps Bengali words whole — combining vowel signs are not separators',
        () {
      expect(keywordTokens('আমার সোনার বাংলা'), ['আমার', 'সোনার', 'বাংলা']);
    });
  });

  group('queryTerms', () {
    test('drops filler words, leaving what the question is about', () {
      expect(queryTerms('What is the powerhouse of the cell?'),
          ['powerhouse', 'cell']);
    });

    test('is distinct, so repeating a word does not count it twice', () {
      expect(queryTerms('cell cell membrane cell'), ['cell', 'membrane']);
    });

    test('a question made only of filler has no terms', () {
      expect(queryTerms('what is the'), isEmpty);
    });
  });

  group('keywordRank', () {
    test('finds the passage that holds the exact words, best first', () {
      final ranked = keywordRank([
        'the cat sat on the mat',
        'Gibbs free energy decides spontaneity',
        'free speech is a right',
      ], 'Gibbs free energy');

      // Index 2 shares only "free", which is 1 of 3 terms — under the bar.
      expect(ranked, [1]);
    });

    test('a course code matches however it is punctuated', () {
      final ranked = keywordRank([
        'CSE-101 syllabus and grading',
        'CSE 202 syllabus',
        'general notes',
      ], 'CSE 101');

      expect(ranked, [0]);
    });

    test('requires most of the query, so one shared common word is not a hit',
        () {
      final ranked = keywordRank([
        'enthalpy of formation',
        'the cell membrane',
        'cell division and enthalpy',
      ], 'cell enthalpy');

      // 2 terms need 2 matches (60% rounded up): only the passage with both.
      expect(ranked, [2]);
    });

    test('a single-word query needs that word', () {
      expect(keywordRank(['alpha beta', 'gamma'], 'gamma'), [1]);
    });

    test('a match on a rarer term outranks a match on a commoner one', () {
      // 3 terms, so 2 must match. Passages 0 and 1 both qualify and are the same
      // length; they differ only in WHICH second term they hold. "enthalpy" is
      // in one passage of five (idf = ln 4 = 1.386), "capacity" in two
      // (idf = ln 3.4 = 0.876), so the enthalpy passage must come first even
      // though the capacity one is listed earlier.
      final ranked = keywordRank([
        'heat capacity of water',
        'heat and enthalpy changes',
        'heat flows',
        'heat engines',
        'capacity planning',
      ], 'heat capacity enthalpy');

      expect(ranked, [1, 0]);
    });

    test('matches a Bengali term exactly', () {
      final ranked = keywordRank(['আমার সোনার বাংলা', 'আমি তোমায় ভালোবাসি'], 'বাংলা');
      expect(ranked, [0]);
    });

    test('an all-filler or empty query ranks nothing', () {
      expect(keywordRank(['anything at all'], 'what is the'), isEmpty);
      expect(keywordRank(['anything at all'], '   '), isEmpty);
      expect(keywordRank(const [], 'cell'), isEmpty);
    });
  });

  group('reciprocalRankFusion', () {
    test('an item both lists agree on beats items only one list found', () {
      final fused = reciprocalRankFusion<String>([
        ['a', 'b', 'c'],
        ['c', 'a', 'd'],
      ]);

      // Worked by hand with k = 60:
      //   a = 1/61 + 1/62 = 0.032522   c = 1/63 + 1/61 = 0.032266
      //   b = 1/62        = 0.016129   d = 1/63        = 0.015873
      expect([for (final f in fused) f.item], ['a', 'c', 'b', 'd']);
      expect(fused[0].score, closeTo(0.032522, 1e-6));
      expect(fused[1].score, closeTo(0.032266, 1e-6));
      expect(fused[2].score, closeTo(0.016129, 1e-6));
      expect(fused[3].score, closeTo(0.015873, 1e-6));
    });

    test('a single list keeps its order', () {
      final fused = reciprocalRankFusion<int>([
        [3, 1, 2]
      ]);
      expect([for (final f in fused) f.item], [3, 1, 2]);
    });

    test('no lists, or empty lists, fuse to nothing', () {
      expect(reciprocalRankFusion<int>(const []), isEmpty);
      expect(
          reciprocalRankFusion<int>([const [], const []]), isEmpty);
    });

    test('ties keep the first list\'s order, so the result is stable', () {
      // x only in list 1 at rank 1, y only in list 2 at rank 1: equal scores.
      final fused = reciprocalRankFusion<String>([
        ['x'],
        ['y'],
      ]);
      expect([for (final f in fused) f.item], ['x', 'y']);
    });
  });
}
