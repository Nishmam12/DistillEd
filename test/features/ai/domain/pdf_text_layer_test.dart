import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/domain/pdf_text_layer.dart';

void main() {
  group('hasUsablePdfText — is the PDF\'s own text worth using', () {
    // A real paragraph: well over the bar.
    const paragraph = 'Photosynthesis converts light energy into chemical energy '
        'stored in glucose, releasing oxygen as a by-product of the reaction.';

    test('a paragraph of real text is usable', () {
      expect(hasUsablePdfText(paragraph), isTrue);
    });

    test('a page number or running header is not — a scan often has only those',
        () {
      expect(hasUsablePdfText('12'), isFalse);
      expect(hasUsablePdfText('Chapter 3 · Cell Biology'), isFalse);
    });

    test('nothing, or only whitespace, is not', () {
      expect(hasUsablePdfText(''), isFalse);
      expect(hasUsablePdfText('  \n\t \n  '), isFalse);
    });

    test('exactly kMinPdfTextChars meaningful characters is usable, one fewer '
        'is not', () {
      expect(hasUsablePdfText('a' * kMinPdfTextChars), isTrue);
      expect(hasUsablePdfText('a' * (kMinPdfTextChars - 1)), isFalse);
    });

    test('whitespace and punctuation do not count toward the bar', () {
      final padded = '${'a ' * (kMinPdfTextChars - 1)}.....,,,,;;;;----\n\n\n';

      expect(hasUsablePdfText(padded), isFalse);
    });

    test('digits count — a page of figures is content', () {
      expect(hasUsablePdfText('1234567890' * 8), isTrue);
    });

    test('Bengali counts, vowel signs and all', () {
      // Vowel signs are combining marks, not letters; a page of Bangla must not
      // be judged short for it.
      final bangla = 'আমারসোনারবাংলাআমিতোমায়ভালোবাসি' * 3;

      expect(hasUsablePdfText(bangla), isTrue);
    });
  });

  group('normalizePdfText', () {
    test('Windows line endings become newlines', () {
      expect(normalizePdfText('one\r\ntwo\r\nthree'), 'one\ntwo\nthree');
    });

    test('control characters and noncharacters PDFium can emit are dropped',
        () {
      expect(normalizePdfText('a\u0000b￾c￿d'), 'abcd');
    });

    test('surrounding whitespace is trimmed, the inside is kept', () {
      expect(normalizePdfText('  \n first line\nsecond line \n\n'),
          'first line\nsecond line');
    });
  });
}
