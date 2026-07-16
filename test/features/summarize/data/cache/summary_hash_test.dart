import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/summarize/data/cache/summary_store.dart';

void main() {
  group('hashRecognizedText (summary cache key)', () {
    test('matches the SHA-256 reference vector', () {
      // Known vector: sha256("abc")
      expect(
        hashRecognizedText('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('is deterministic across calls', () {
      const text = 'meeting notes\n\nsecond page';
      expect(hashRecognizedText(text), hashRecognizedText(text));
    });

    test('any text change produces a different hash', () {
      expect(hashRecognizedText('meeting notes'),
          isNot(hashRecognizedText('meeting note')));
      // Even whitespace/page-boundary changes count as changes.
      expect(hashRecognizedText('a\n\nb'), isNot(hashRecognizedText('a b')));
    });

    test('handles non-Latin scripts via UTF-8', () {
      final bn = hashRecognizedText('আজকের সভা');
      expect(bn, hasLength(64));
      expect(bn, isNot(hashRecognizedText('আজকের সভায়')));
    });
  });
}
