import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:inkflow/features/ai/data/flashcards/flashcard_apkg.dart';
import 'package:inkflow/features/ai/domain/models/flashcard.dart';

Flashcard card(String front, String back) => Flashcard(
      front: front,
      back: back,
      notebookId: 1,
      pageId: 1,
      createdAt: DateTime(2026),
    );

void main() {
  test('the .apkg is a ZIP of collection.anki2 + an empty media map', () {
    final bytes =
        flashcardsToApkg([card('Q1', 'A1')], deckName: 'Deck', nowMillis: 1000);
    final archive = ZipDecoder().decodeBytes(bytes);

    expect(archive.map((f) => f.name).toSet(),
        containsAll(<String>['collection.anki2', 'media']));
    expect(utf8.decode(archive.findFile('media')!.content), '{}');

    // The inner file really is a SQLite database (magic header).
    final db = archive.findFile('collection.anki2')!.content;
    expect(utf8.decode(db.sublist(0, 16)), 'SQLite format 3\x00');
  });

  test('round-trips: the collection DB holds the notes, cards and named deck',
      () {
    final bytes = flashcardsToApkg(
      [card('Front 1', 'Back 1'), card('Front 2', 'Back 2')],
      deckName: 'Photosynthesis',
      nowMillis: 5000,
    );
    final dbBytes = ZipDecoder()
        .decodeBytes(bytes)
        .findFile('collection.anki2')!
        .content;

    final tmp = Directory.systemTemp.createTempSync('apkg_test');
    final path = '${tmp.path}/collection.anki2';
    File(path).writeAsBytesSync(dbBytes);
    final db = sqlite3.open(path);
    try {
      expect(db.select('SELECT count(*) AS c FROM notes').first['c'], 2);
      expect(db.select('SELECT count(*) AS c FROM cards').first['c'], 2);

      final col = db.select('SELECT ver, decks FROM col').first;
      expect(col['ver'], 11);
      expect(col['decks'], contains('Photosynthesis'));

      final flds =
          db.select('SELECT flds FROM notes ORDER BY id').first['flds'];
      expect(flds, 'Front 1\x1FBack 1');

      // Every card points at a real note (no orphans).
      final orphans = db
          .select('SELECT count(*) AS c FROM cards '
              'WHERE nid NOT IN (SELECT id FROM notes)')
          .first['c'];
      expect(orphans, 0);
    } finally {
      db.close();
      tmp.deleteSync(recursive: true);
    }
  });

  test('an empty deck still produces a valid, importable collection', () {
    final bytes =
        flashcardsToApkg(const [], deckName: 'Empty', nowMillis: 1);
    final dbBytes = ZipDecoder()
        .decodeBytes(bytes)
        .findFile('collection.anki2')!
        .content;

    final tmp = Directory.systemTemp.createTempSync('apkg_empty');
    final path = '${tmp.path}/collection.anki2';
    File(path).writeAsBytesSync(dbBytes);
    final db = sqlite3.open(path);
    try {
      expect(db.select('SELECT count(*) AS c FROM notes').first['c'], 0);
      expect(db.select('SELECT count(*) AS c FROM col').first['c'], 1);
    } finally {
      db.close();
      tmp.deleteSync(recursive: true);
    }
  });
}
