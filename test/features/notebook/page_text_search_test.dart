import 'package:flutter_test/flutter_test.dart';
import 'package:margo/data/persistence/page_text_store.dart';
import 'package:margo/features/notebook/domain/page_text_search.dart';

void main() {
  const texts = [
    PageText(pageId: 1, notebookId: 0, text: 'Intro to biology'),
    PageText(
        pageId: 2,
        notebookId: 0,
        text: 'A long recap of everything we covered: cell\n  DIVISION '
            'happens in phases, prophase first, then the rest of it'),
    PageText(pageId: 3, notebookId: 0, text: 'Cell division, again'),
  ];

  test('finds the pages, ignoring case and line breaks, in order', () {
    final hits = searchPageTexts(texts, 'Cell division');
    expect(hits.map((h) => h.pageId), [2, 3]);
  });

  test('a snippet shows the words around the match', () {
    final hit = searchPageTexts(texts, 'cell division', around: 10).first;
    expect(hit.snippet, startsWith('…'));
    expect(hit.snippet.toLowerCase(), contains('cell division'));
    expect(hit.snippet, endsWith('…'));
  });

  test('a blank query finds nothing', () {
    expect(searchPageTexts(texts, '  \n '), isEmpty);
  });
}
