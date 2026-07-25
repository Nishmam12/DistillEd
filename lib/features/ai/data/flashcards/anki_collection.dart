// The pure, dependency-free model of an Anki `collection.anki2` database — the
// SQLite file that lives inside a `.apkg`. Everything format-critical is here
// (table schema, exact row values, the field checksum, note GUIDs, and the
// `col` JSON config blobs) so it can be unit-tested WITHOUT a SQLite engine.
// The thin native writer (`flashcard_apkg.dart`) just replays these into a real
// database and zips it.
//
// Schema + row shapes follow Anki's own `collection.anki2` (ver 11) and the
// conventions of the reference exporter (genanki): one Basic notetype (Front /
// Back), one card template, cards scheduled as fresh "new" cards.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/models/flashcard.dart';
import 'flashcard_csv.dart' show sanitizeAnkiDeckName;

/// Stable, app-specific IDs for the single notetype and deck we emit. Anki
/// keys models/decks by these; fixed values keep re-exports referring to the
/// same notetype/deck rather than piling up new ones.
const int kAnkiModelId = 1740006000001;
const int kAnkiDeckId = 1740006000002;

/// The field separator Anki uses to pack multiple fields into `notes.flds`
/// (a literal U+001F unit separator — written as an escape so it stays visible).
const String _fieldSeparator = '\x1F';

/// The `CREATE TABLE`/`CREATE INDEX` statements for a ver-11 Anki collection.
/// Executed verbatim by the writer before any rows are inserted.
const List<String> ankiSchemaStatements = [
  '''
CREATE TABLE col (
  id integer PRIMARY KEY,
  crt integer NOT NULL,
  mod integer NOT NULL,
  scm integer NOT NULL,
  ver integer NOT NULL,
  dty integer NOT NULL,
  usn integer NOT NULL,
  ls integer NOT NULL,
  conf text NOT NULL,
  models text NOT NULL,
  decks text NOT NULL,
  dconf text NOT NULL,
  tags text NOT NULL
);''',
  '''
CREATE TABLE notes (
  id integer PRIMARY KEY,
  guid text NOT NULL,
  mid integer NOT NULL,
  mod integer NOT NULL,
  usn integer NOT NULL,
  tags text NOT NULL,
  flds text NOT NULL,
  sfld integer NOT NULL,
  csum integer NOT NULL,
  flags integer NOT NULL,
  data text NOT NULL
);''',
  '''
CREATE TABLE cards (
  id integer PRIMARY KEY,
  nid integer NOT NULL,
  did integer NOT NULL,
  ord integer NOT NULL,
  mod integer NOT NULL,
  usn integer NOT NULL,
  type integer NOT NULL,
  queue integer NOT NULL,
  due integer NOT NULL,
  ivl integer NOT NULL,
  factor integer NOT NULL,
  reps integer NOT NULL,
  lapses integer NOT NULL,
  left integer NOT NULL,
  odue integer NOT NULL,
  odid integer NOT NULL,
  flags integer NOT NULL,
  data text NOT NULL
);''',
  '''
CREATE TABLE revlog (
  id integer PRIMARY KEY,
  cid integer NOT NULL,
  usn integer NOT NULL,
  ease integer NOT NULL,
  ivl integer NOT NULL,
  lastIvl integer NOT NULL,
  factor integer NOT NULL,
  time integer NOT NULL,
  type integer NOT NULL
);''',
  '''
CREATE TABLE graves (
  usn integer NOT NULL,
  oid integer NOT NULL,
  type integer NOT NULL
);''',
  'CREATE INDEX ix_notes_usn ON notes (usn);',
  'CREATE INDEX ix_cards_usn ON cards (usn);',
  'CREATE INDEX ix_revlog_usn ON revlog (usn);',
  'CREATE INDEX ix_cards_nid ON cards (nid);',
  'CREATE INDEX ix_cards_sched ON cards (did, queue, due);',
  'CREATE INDEX ix_revlog_cid ON revlog (cid);',
  'CREATE INDEX ix_notes_csum ON notes (csum);',
];

/// Anki's note checksum: the first 8 hex digits of SHA1 over the first field
/// (with any HTML stripped), as an integer. Anki uses it to spot duplicates,
/// so it must match Anki's own computation.
int ankiFieldChecksum(String firstField) {
  final digest = sha1.convert(utf8.encode(_stripHtml(firstField)));
  return int.parse(digest.toString().substring(0, 8), radix: 16);
}

/// A stable, unique note GUID derived from [seed]. Base64url of the leading
/// SHA1 bytes: deterministic (a re-export of the same card reuses its GUID, so
/// re-importing updates rather than duplicates) and collision-free per input.
String ankiGuid(String seed) {
  final digest = sha1.convert(utf8.encode(seed)).bytes.sublist(0, 8);
  return base64Url.encode(digest).replaceAll('=', '');
}

String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');

/// One row of the `notes` table.
class AnkiNote {
  final int id;
  final String guid;
  final int modSeconds;
  final String front;
  final String back;

  const AnkiNote({
    required this.id,
    required this.guid,
    required this.modSeconds,
    required this.front,
    required this.back,
  });

  String get flds => '$front$_fieldSeparator$back';
  int get checksum => ankiFieldChecksum(front);

  /// Column-ordered values for `INSERT INTO notes VALUES(...)`:
  /// id, guid, mid, mod, usn(-1), tags(''), flds, sfld, csum, flags(0), data('').
  List<Object?> get values =>
      [id, guid, kAnkiModelId, modSeconds, -1, '', flds, front, checksum, 0, ''];
}

/// One row of the `cards` table — a fresh "new" card for its note.
class AnkiCard {
  final int id;
  final int noteId;
  final int modSeconds;
  final int due; // 1-based position among new cards

  const AnkiCard({
    required this.id,
    required this.noteId,
    required this.modSeconds,
    required this.due,
  });

  /// Column-ordered values for `INSERT INTO cards VALUES(...)`:
  /// id, nid, did, ord(0), mod, usn(-1), type(0), queue(0), due,
  /// ivl(0), factor(0), reps(0), lapses(0), left(0), odue(0), odid(0),
  /// flags(0), data('').
  List<Object?> get values => [
        id, noteId, kAnkiDeckId, 0, modSeconds, -1, 0, 0, due,
        0, 0, 0, 0, 0, 0, 0, 0, '',
      ];
}

/// A complete Anki collection ready to be written to `collection.anki2`.
class AnkiCollection {
  final String deckName;
  final int crtSeconds;
  final int modMillis;
  final List<AnkiNote> notes;
  final List<AnkiCard> cards;

  const AnkiCollection._({
    required this.deckName,
    required this.crtSeconds,
    required this.modMillis,
    required this.notes,
    required this.cards,
  });

  /// Builds the collection for [cards], into a deck named [deckName] (blank →
  /// the default name). [nowMillis] seeds the timestamps and the note/card IDs
  /// (injected so tests are deterministic); pass
  /// `DateTime.now().millisecondsSinceEpoch` in production.
  factory AnkiCollection.fromCards(
    List<Flashcard> cards, {
    required String? deckName,
    required int nowMillis,
  }) {
    final name = sanitizeAnkiDeckName(deckName);
    final modSeconds = nowMillis ~/ 1000;
    final notes = <AnkiNote>[];
    final cardRows = <AnkiCard>[];
    for (var i = 0; i < cards.length; i++) {
      final id = nowMillis + i; // unique + preserves deck order
      final card = cards[i];
      notes.add(AnkiNote(
        id: id,
        guid: ankiGuid('$kAnkiDeckId:$i:${card.front}'),
        modSeconds: modSeconds,
        front: card.front,
        back: card.back,
      ));
      cardRows.add(AnkiCard(
        id: id,
        noteId: id,
        modSeconds: modSeconds,
        due: i + 1,
      ));
    }
    return AnkiCollection._(
      deckName: name,
      crtSeconds: modSeconds,
      modMillis: nowMillis,
      notes: notes,
      cards: cardRows,
    );
  }

  /// Column-ordered values for the single `INSERT INTO col VALUES(...)` row:
  /// id(1), crt, mod, scm, ver(11), dty(0), usn(0), ls(0),
  /// conf, models, decks, dconf, tags('{}').
  List<Object?> get colValues => [
        1, crtSeconds, modMillis, modMillis, 11, 0, 0, 0,
        confJson, modelsJson, decksJson, dconfJson, '{}',
      ];

  String get modelsJson => jsonEncode({
        '$kAnkiModelId': {
          'id': kAnkiModelId,
          'name': 'DistillEd Basic',
          'type': 0,
          'mod': crtSeconds,
          'usn': -1,
          'sortf': 0,
          'did': kAnkiDeckId,
          'tmpls': [
            {
              'name': 'Card 1',
              'ord': 0,
              'qfmt': '{{Front}}',
              'afmt': '{{FrontSide}}\n\n<hr id=answer>\n\n{{Back}}',
              'did': null,
              'bqfmt': '',
              'bafmt': '',
            }
          ],
          'flds': [
            {'name': 'Front', 'ord': 0, 'sticky': false, 'rtl': false,
             'font': 'Arial', 'size': 20},
            {'name': 'Back', 'ord': 1, 'sticky': false, 'rtl': false,
             'font': 'Arial', 'size': 20},
          ],
          'css': '.card {\n font-family: arial;\n font-size: 20px;\n'
              ' text-align: center;\n color: black;\n'
              ' background-color: white;\n}',
          'latexPre': '\\documentclass[12pt]{article}\n'
              '\\special{papersize=3in,5in}\n'
              '\\usepackage[utf8]{inputenc}\n'
              '\\usepackage{amssymb,amsmath}\n'
              '\\pagestyle{empty}\n'
              '\\setlength{\\parindent}{0in}\n\\begin{document}\n',
          'latexPost': '\\end{document}',
          'req': [
            [0, 'any', [0]]
          ],
          'tags': [],
          'vers': [],
        }
      });

  String get decksJson => jsonEncode({
        '1': _deck(1, 'Default', collapsed: true),
        '$kAnkiDeckId': _deck(kAnkiDeckId, deckName, collapsed: false),
      });

  Map<String, Object?> _deck(int id, String name, {required bool collapsed}) => {
        'id': id,
        'name': name,
        'mod': crtSeconds,
        'usn': -1,
        'lrnToday': [0, 0],
        'revToday': [0, 0],
        'newToday': [0, 0],
        'timeToday': [0, 0],
        'collapsed': collapsed,
        'browserCollapsed': collapsed,
        'desc': '',
        'dyn': 0,
        'conf': 1,
        'extendNew': 0,
        'extendRev': 0,
      };

  String get dconfJson => jsonEncode({
        '1': {
          'id': 1,
          'name': 'Default',
          'mod': 0,
          'usn': 0,
          'maxTaken': 60,
          'autoplay': true,
          'timer': 0,
          'replayq': true,
          'new': {
            'bury': true,
            'delays': [1.0, 10.0],
            'initialFactor': 2500,
            'ints': [1, 4, 7],
            'order': 1,
            'perDay': 20,
            'separate': true,
          },
          'rev': {
            'bury': true,
            'ease4': 1.3,
            'fuzz': 0.05,
            'ivlFct': 1.0,
            'maxIvl': 36500,
            'minSpace': 1,
            'perDay': 100,
            'hardFactor': 1.2,
          },
          'lapse': {
            'delays': [10.0],
            'leechAction': 1,
            'leechFails': 8,
            'minInt': 1,
            'mult': 0.0,
          },
          'dyn': false,
        }
      });

  String get confJson => jsonEncode({
        'nextPos': notes.length + 1,
        'estTimes': true,
        'activeDecks': [1],
        'sortType': 'noteFld',
        'timeLim': 0,
        'sortBackwards': false,
        'addToCur': true,
        'curDeck': kAnkiDeckId,
        'newBury': true,
        'newSpread': 0,
        'dueCounts': true,
        'curModel': '$kAnkiModelId',
        'collapseTime': 1200,
      });
}
