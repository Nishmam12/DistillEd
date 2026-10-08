// The corpus the embedding evaluation reads (docs/TECH_MIGRATION_PLAN.md, phase
// 4.9). Every page is written at every chunk size, under its own page id, so one
// set of questions scores every size: a chunk id changes with its size, a page id
// does not.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/domain/rag/rag_corpus.dart';

List<Map<String, dynamic>> _lines(String jsonl) => [
      for (final line in const LineSplitter().convert(jsonl))
        jsonDecode(line) as Map<String, dynamic>,
    ];

void main() {
  const twelveWords = 'one two three four five six seven eight nine ten eleven '
      'twelve';

  test('a page is written at every size, with ids that name both', () {
    final lines = _lines(ragCorpusJsonl(
      [
        const CorpusPage(
          notebookId: 1,
          pageId: 2,
          title: 'Biology',
          text: twelveWords,
        ),
      ],
      chunkSizes: const [4, 250],
    ));

    expect([
      for (final line in lines) line['id']
    ], [
      'w4-p2-c0',
      'w4-p2-c1',
      'w4-p2-c2',
      'w250-p2-c0',
    ]);
  });

  test('each chunk carries its size, its page id and the page title', () {
    final lines = _lines(ragCorpusJsonl(
      [
        const CorpusPage(
          notebookId: 1,
          pageId: 2,
          title: 'Biology',
          text: twelveWords,
        ),
      ],
      chunkSizes: const [4],
    ));

    expect(lines.first['chunk_words'], 4);
    expect(lines.first['page_id'], 2);
    expect(lines.first['title'], 'Biology');
    expect(lines.first['text'], 'one two three four');
  });

  test('a page with no title says so with null, not an empty string', () {
    final lines = _lines(ragCorpusJsonl(
      [
        const CorpusPage(
          notebookId: 1,
          pageId: 3,
          title: null,
          text: 'Cells divide by mitosis.',
        ),
      ],
      chunkSizes: const [250],
    ));

    expect(lines.single['title'], isNull);
  });

  test('a blank page writes nothing', () {
    expect(
      ragCorpusJsonl(
        [
          const CorpusPage(notebookId: 1, pageId: 4, title: null, text: '  \n ')
        ],
        chunkSizes: const [250],
      ),
      isEmpty,
    );
  });
}
