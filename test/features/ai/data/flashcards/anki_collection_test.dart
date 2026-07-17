import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/flashcards/anki_collection.dart';
import 'package:inkflow/features/ai/data/flashcards/flashcard_csv.dart'
    show kDefaultAnkiDeckName;
import 'package:inkflow/features/ai/domain/models/flashcard.dart';

Flashcard card(String front, String back) => Flashcard(
      front: front,
      back: back,
      notebookId: 1,
      pageId: 1,
      createdAt: DateTime(2026),
    );

void main() {
  group('ankiFieldChecksum', () {
    test('is the first 8 hex digits of SHA1 over the field, as an int', () {
      final expected = int.parse(
        sha1.convert(utf8.encode('Dog')).toString().substring(0, 8),
        radix: 16,
      );
      expect(ankiFieldChecksum('Dog'), expected);
      expect(ankiFieldChecksum('Dog'), lessThan(0x100000000),
          reason: '32-bit checksum');
    });

    test('strips HTML before hashing, the way Anki does', () {
      expect(ankiFieldChecksum('<b>Dog</b>'), ankiFieldChecksum('Dog'));
    });

    test('is deterministic', () {
      expect(ankiFieldChecksum('mitochondria'),
          ankiFieldChecksum('mitochondria'));
    });
  });

  group('ankiGuid', () {
    test('is stable per seed and distinct across seeds', () {
      expect(ankiGuid('a'), ankiGuid('a'));
      expect(ankiGuid('a'), isNot(ankiGuid('b')));
    });

    test('is URL-safe with no base64 padding', () {
      final guid = ankiGuid('anything at all');
      expect(guid, isNot(contains('=')));
      expect(guid, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });
  });

  group('AnkiCollection.fromCards', () {
    final collection = AnkiCollection.fromCards(
      [card('Front A', 'Back A'), card('Front B', 'Back B')],
      deckName: 'Cell Biology',
      nowMillis: 1000000,
    );

    test('emits one note and one paired card per flashcard, IDs unique', () {
      expect(collection.notes, hasLength(2));
      expect(collection.cards, hasLength(2));
      expect(collection.notes.map((n) => n.id).toSet(), hasLength(2));
      for (var i = 0; i < collection.cards.length; i++) {
        expect(collection.cards[i].noteId, collection.notes[i].id);
      }
    });

    test('note fields are unit-separated; the sort field is the front', () {
      final note = collection.notes.first;
      expect(note.flds, 'Front A\x1FBack A');
      expect(note.values[7], 'Front A', reason: 'sfld column');
    });

    test('cards are fresh "new" cards in our deck, ordered by position', () {
      final values = collection.cards.first.values;
      expect(values[2], kAnkiDeckId, reason: 'did');
      expect(values[3], 0, reason: 'ord');
      expect(values[6], 0, reason: 'type = new');
      expect(values[7], 0, reason: 'queue = new');
      expect(values[8], 1, reason: 'due = 1-based position');
    });

    test('col row is ver 11 with valid JSON config blobs', () {
      final col = collection.colValues;
      expect(col[4], 11, reason: 'ver');

      final conf = jsonDecode(col[8]! as String) as Map<String, dynamic>;
      final models = jsonDecode(col[9]! as String) as Map<String, dynamic>;
      final decks = jsonDecode(col[10]! as String) as Map<String, dynamic>;

      expect(conf['curModel'], '$kAnkiModelId');
      expect(models.keys, contains('$kAnkiModelId'));
      final model = models['$kAnkiModelId'] as Map<String, dynamic>;
      expect((model['flds'] as List).map((f) => f['name']), ['Front', 'Back']);
      expect(model['tmpls'], hasLength(1));

      expect(decks.keys, containsAll(<String>['1', '$kAnkiDeckId']));
      expect(decks['$kAnkiDeckId']['name'], 'Cell Biology');
    });

    test('a blank deck name falls back to the default', () {
      final c = AnkiCollection.fromCards([card('q', 'a')],
          deckName: '   ', nowMillis: 1);
      final decks = jsonDecode(c.decksJson) as Map<String, dynamic>;
      expect(decks['$kAnkiDeckId']['name'], kDefaultAnkiDeckName);
    });

    test('an empty deck still yields valid, note-free config', () {
      final c =
          AnkiCollection.fromCards(const [], deckName: 'X', nowMillis: 1);
      expect(c.notes, isEmpty);
      expect(c.cards, isEmpty);
      final conf = jsonDecode(c.confJson) as Map<String, dynamic>;
      expect(conf['nextPos'], 1);
    });
  });
}
