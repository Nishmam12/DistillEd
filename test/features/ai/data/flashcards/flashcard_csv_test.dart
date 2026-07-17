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
}
