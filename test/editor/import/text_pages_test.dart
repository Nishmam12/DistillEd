import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/editor/import/text_pages.dart';

void main() {
  // One line per 10 characters, each line 1 unit tall.
  double height(String t) => t
      .split('\n')
      .fold(0, (sum, line) => sum + (line.isEmpty ? 1 : (line.length / 10).ceil()));

  group('paginateText', () {
    test('keeps paragraphs whole and breaks between them', () {
      final pages = paginateText('aaaa\nbbbb\ncccc', 2, height);
      expect(pages, ['aaaa\nbbbb', 'cccc']);
    });

    test('breaks a paragraph longer than a page between words', () {
      final long = List.filled(10, 'word').join(' '); // 49 chars = 5 lines
      final pages = paginateText(long, 2, height);
      expect(pages.every((p) => height(p) <= 2), isTrue);
      expect(pages.join(' '), long);
    });

    test('blank-only text gives no pages', () {
      expect(paginateText('\n\n', 5, height), isEmpty);
    });
  });

  test('plainFromMarkdown strips syntax but keeps the words', () {
    const md = '# Cells\n'
        '\n'
        '> A **cell** is the _unit_ of life.\n'
        '- Item one\n'
        '* [x] done\n'
        '```dart\n'
        'code()\n'
        '```\n'
        'See [the notes](https://example.com "t") and `mitosis`.\n'
        '![diagram](a.png)\n'
        '---\n'
        'snake_case_name stays';
    expect(
        plainFromMarkdown(md),
        'Cells\n'
        '\n'
        'A cell is the unit of life.\n'
        '• Item one\n'
        '• done\n'
        'code()\n'
        'See the notes (https://example.com) and mitosis.\n'
        'diagram\n'
        '\n'
        'snake_case_name stays');
  });

  test('decodeTextFile drops the BOM, normalises line ends, survives bad bytes',
      () {
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('a\r\nb\rc'), 0xFF];
    expect(decodeTextFile(bytes), 'a\nb\nc�');
  });

  test('isMarkdownName', () {
    expect(isMarkdownName('Notes.MD'), isTrue);
    expect(isMarkdownName('notes.txt'), isFalse);
  });
}
