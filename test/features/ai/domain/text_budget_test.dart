import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/text_budget.dart';

void main() {
  group('countWords', () {
    test('counts whitespace-separated tokens; blank is zero', () {
      expect(countWords(''), 0);
      expect(countWords('   '), 0);
      expect(countWords('one two\nthree'), 3);
    });
  });

  group('truncateToWords', () {
    test('keeps text under budget intact and cuts over-budget text', () {
      expect(truncateToWords('a b c', 5), 'a b c');
      expect(truncateToWords('a b c d e f', 3), 'a b c');
    });
  });

  group('chunkByWords', () {
    test('text within budget is a single chunk', () {
      expect(chunkByWords('one two three', 10), ['one two three']);
    });

    test('blank input yields no chunks', () {
      expect(chunkByWords('   ', 10), isEmpty);
    });

    test('packs whole paragraphs greedily, never over budget', () {
      final text = ['a a a', 'b b b', 'c c c'].join('\n\n');
      final chunks = chunkByWords(text, 6);

      expect(chunks, ['a a a\n\nb b b', 'c c c']);
      for (final c in chunks) {
        expect(countWords(c), lessThanOrEqualTo(6));
      }
    });

    test('a single paragraph over budget is hard-split by words', () {
      final chunks = chunkByWords(List.filled(25, 'w').join(' '), 10);

      expect(chunks.length, 3); // 10 + 10 + 5
      expect(countWords(chunks[0]), 10);
      expect(countWords(chunks[1]), 10);
      expect(countWords(chunks[2]), 5);
    });

    test('mixed content: every chunk fits the budget and no words are lost',
        () {
      final text = '${List.filled(23, 'x').join(' ')}\n\nshort para';
      final chunks = chunkByWords(text, 10);

      for (final c in chunks) {
        expect(countWords(c), lessThanOrEqualTo(10));
      }
      expect(chunks.map(countWords).reduce((a, b) => a + b), 25);
    });

    test('a non-positive budget returns the whole text as one chunk', () {
      expect(chunkByWords('a b c', 0), ['a b c']);
    });
  });
}
