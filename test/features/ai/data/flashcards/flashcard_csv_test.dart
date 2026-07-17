import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/flashcards/flashcard_csv.dart';
import 'package:inkflow/features/ai/domain/models/flashcard.dart';

Flashcard card(String front, String back) => Flashcard(
      front: front,
      back: back,
      notebookId: 1,
      pageId: 1,
      createdAt: DateTime(2026),
    );

void main() {
  test('plain fields become bare comma-separated rows, CRLF-joined', () {
    final csv = flashcardsToCsv([card('front one', 'back one'), card('q', 'a')]);
    expect(csv, 'front one,back one\r\nq,a');
  });

  test('fields with commas, quotes or newlines are quoted and escaped', () {
    final csv = flashcardsToCsv([
      card('has, comma', 'has "quotes"'),
      card('line1\nline2', 'plain'),
    ]);
    expect(
      csv,
      '"has, comma","has ""quotes"""\r\n"line1\nline2",plain',
    );
  });

  test('an empty deck is an empty string', () {
    expect(flashcardsToCsv(const []), '');
  });

  group('flashcardsToAnkiCsv', () {
    test('prepends the four header directives, in order, before the rows', () {
      final out = flashcardsToAnkiCsv([card('q', 'a')], deckName: 'Biology');
      expect(
        out,
        '#separator:Comma\r\n'
        '#html:false\r\n'
        '#notetype:Basic\r\n'
        '#deck:Biology\r\n'
        'q,a',
      );
    });

    test('names the deck after the topic, spaces preserved', () {
      final out =
          flashcardsToAnkiCsv([card('q', 'a')], deckName: 'Cell Biology 101');
      expect(out, contains('#deck:Cell Biology 101\r\n'));
    });

    test('a blank, whitespace, or missing deck name falls back to the default',
        () {
      for (final name in <String?>['', '   ', null]) {
        final out = flashcardsToAnkiCsv([card('q', 'a')], deckName: name);
        expect(out, contains('#deck:$kDefaultAnkiDeckName\r\n'),
            reason: 'deckName=${name == null ? 'null' : '"$name"'}');
      }
    });

    test('CR/LF in the deck name are collapsed so #deck stays one line', () {
      final out =
          flashcardsToAnkiCsv([card('q', 'a')], deckName: 'Line1\nLine2\r\n');
      expect(
        out.split('\r\n'),
        ['#separator:Comma', '#html:false', '#notetype:Basic',
         '#deck:Line1 Line2', 'q,a'],
      );
    });

    test('the body rows are still RFC-4180 escaped behind the header', () {
      final out =
          flashcardsToAnkiCsv([card('a,b', 'c"d')], deckName: 'X');
      expect(out, endsWith('\r\n"a,b","c""d"'));
    });

    test('an empty deck is just the directive header, no trailing separator',
        () {
      final out = flashcardsToAnkiCsv(const [], deckName: 'X');
      expect(
        out,
        '#separator:Comma\r\n#html:false\r\n#notetype:Basic\r\n#deck:X',
      );
    });
  });
}
