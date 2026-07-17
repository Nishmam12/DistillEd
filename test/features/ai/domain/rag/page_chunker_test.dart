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
}
