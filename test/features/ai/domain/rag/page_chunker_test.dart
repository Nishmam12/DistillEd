import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/rag/page_chunker.dart';
import 'package:inkflow/features/ai/domain/text_budget.dart';

/// A paragraph of [words] distinct, countable words: "p1w1 p1w2 …".
String paragraph(int index, int words) =>
    List.generate(words, (i) => 'p${index}w${i + 1}').join(' ');

void main() {
  test('blank input yields no chunks', () {
    expect(chunkPage(text: '', notebookId: 1, pageId: 1), isEmpty);
    expect(chunkPage(text: '   \n\n  ', notebookId: 1, pageId: 1), isEmpty);
  });

  test('text that fits is one chunk with no overlap prefix', () {
    final chunks =
        chunkPage(text: 'a short page of notes', notebookId: 3, pageId: 9);
    expect(chunks, hasLength(1));
    expect(chunks.single.text, 'a short page of notes');
    expect(chunks.single.source.notebookId, 3);
    expect(chunks.single.source.pageId, 9);
    expect(chunks.single.source.ordinal, 0);
  });

  test('every chunk stays within the word budget, overlap included', () {
    final text = List.generate(6, (i) => paragraph(i, 40)).join('\n\n');
    final chunks = chunkPage(
      text: text,
      notebookId: 1,
      pageId: 1,
      maxWords: 100,
      overlapWords: 20,
    );

    expect(chunks.length, greaterThan(1), reason: 'the page must actually split');
    for (final chunk in chunks) {
      expect(countWords(chunk.text), lessThanOrEqualTo(100));
    }
  });

  test('each chunk after the first repeats the tail of the previous body', () {
    final text = List.generate(4, (i) => paragraph(i, 40)).join('\n\n');
    final chunks = chunkPage(
      text: text,
      notebookId: 1,
      pageId: 1,
      maxWords: 100,
      overlapWords: 10,
    );

    for (var i = 1; i < chunks.length; i++) {
      final previousWords = chunks[i - 1].text.trim().split(RegExp(r'\s+'));
      final overlap = previousWords.sublist(previousWords.length - 10).join(' ');
      expect(chunks[i].text, startsWith(overlap),
          reason: 'chunk $i must carry chunk ${i - 1}\'s tail');
    }
  });

  test('ordinals number the chunks in reading order', () {
    final text = List.generate(5, (i) => paragraph(i, 40)).join('\n\n');
    final chunks = chunkPage(
        text: text, notebookId: 7, pageId: 2, maxWords: 100, overlapWords: 20);

    expect([for (final c in chunks) c.source.ordinal],
        List.generate(chunks.length, (i) => i));
    expect(chunks.every((c) => c.source.notebookId == 7), isTrue);
    expect(chunks.every((c) => c.source.pageId == 2), isTrue);
  });

  test('no words are lost: every chunk body appears in reading order', () {
    final text = List.generate(4, (i) => paragraph(i, 30)).join('\n\n');
    final chunks = chunkPage(
        text: text, notebookId: 1, pageId: 1, maxWords: 60, overlapWords: 10);

    // Concatenating the chunks must contain every original word.
    final joined = chunks.map((c) => c.text).join(' ');
    for (final word in text.split(RegExp(r'\s+'))) {
      expect(joined, contains(word));
    }
  });

  test('a single over-long paragraph is hard-split rather than dropped', () {
    final chunks = chunkPage(
      text: paragraph(0, 200),
      notebookId: 1,
      pageId: 1,
      maxWords: 50,
      overlapWords: 10,
    );
    expect(chunks.length, greaterThan(1));
    for (final chunk in chunks) {
      expect(countWords(chunk.text), lessThanOrEqualTo(50));
    }
    expect(chunks.first.text, contains('p0w1'));
    expect(chunks.map((c) => c.text).join(' '), contains('p0w200'));
  });

  test('zero overlap is honoured', () {
    final text = List.generate(4, (i) => paragraph(i, 30)).join('\n\n');
    final chunks = chunkPage(
        text: text, notebookId: 1, pageId: 1, maxWords: 60, overlapWords: 0);
    // With no overlap, the first word of chunk 1 is new content, not a repeat.
    expect(chunks.length, greaterThan(1));
    for (final chunk in chunks) {
      expect(countWords(chunk.text), lessThanOrEqualTo(60));
    }
  });

  test('an overlap wider than the budget cannot starve the body', () {
    final chunks = chunkPage(
      text: List.generate(4, (i) => paragraph(i, 20)).join('\n\n'),
      notebookId: 1,
      pageId: 1,
      maxWords: 10,
      overlapWords: 999, // absurd on purpose
    );
    expect(chunks, isNotEmpty, reason: 'must still make progress, not hang');
    expect(chunks.first.text.trim(), isNotEmpty);
  });

  test('the shipped defaults sit inside the spec + model limits', () {
    expect(kChunkWords, inInclusiveRange(150, 400));
    // ~10-15% overlap per the phase spec.
    const ratio = kChunkOverlapWords / kChunkWords;
    expect(ratio, inInclusiveRange(0.10, 0.15));
  });

  group('chunkTitle', () {
    test('names the notebook and the imported document it came from', () {
      expect(
        chunkTitle(notebookTitle: 'Organic Chemistry', sourceName: 'lecture3.pdf'),
        'Organic Chemistry · lecture3.pdf',
      );
    });

    test('a hand-written page is named by its notebook alone', () {
      expect(chunkTitle(notebookTitle: 'Organic Chemistry'), 'Organic Chemistry');
    });

    test('a document with the same name as its notebook is not said twice', () {
      // Importing "lecture3.pdf" into a notebook that has the same title is the
      // common case, and "lecture3.pdf · lecture3.pdf" would only dilute it.
      expect(
        chunkTitle(notebookTitle: 'Lecture3.pdf', sourceName: ' lecture3.pdf '),
        'Lecture3.pdf',
      );
    });

    test('nothing usable gives no title, rather than an empty prefix', () {
      expect(chunkTitle(), isNull);
      expect(chunkTitle(notebookTitle: '  ', sourceName: ''), isNull);
    });
  });

  group('Indic scripts', () {
    // A 6-letter Bangla word is ~3 tokens, so 2.2 budget words; English is 1.0.
    final bangla = List.filled(400, 'বাংলাভাষা').join(' ');

    test('an English word costs exactly one budget word', () {
      expect(wordCost('internationalization'), 1.0);
      expect(budgetWords('one two three'), 3);
    });

    test('a Bangla page is cut into smaller chunks than an English one', () {
      final english = List.filled(400, 'word').join(' ');
      final enChunks = chunkPage(text: english, notebookId: 1, pageId: 1);
      final bnChunks = chunkPage(text: bangla, notebookId: 1, pageId: 1);

      expect(bnChunks.length, greaterThan(enChunks.length));
      for (final c in bnChunks) {
        expect(budgetWords(c.text), lessThanOrEqualTo(kChunkWords));
      }
    });

    test('truncation keeps whole Bangla words within the budget', () {
      final cut = truncateToWords(bangla, 100);
      expect(budgetWords(cut), lessThanOrEqualTo(100));
      expect(cut.split(' ').length, lessThan(100));
    });
  });
}
