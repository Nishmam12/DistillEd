// Builds a real Anki `.apkg` — a ZIP of `collection.anki2` (a SQLite database)
// plus a `media` manifest — from a deck of flashcards.
//
// All format-critical content (schema, rows, checksums, config JSON) is built
// in pure Dart by `anki_collection.dart` and unit-tested there; this file is the
// thin native layer that replays it into a SQLite file (package:sqlite3 supplies
// the engine via native assets) and zips it (package:archive). If the native
// engine is ever unavailable, callers fall back to the directive-CSV export.

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/models/flashcard.dart';
import 'anki_collection.dart';

/// The two entries every `.apkg` archive contains.
const String _dbEntryName = 'collection.anki2';
const String _mediaEntryName = 'media';

/// Builds a `.apkg` for [cards] in a deck named [deckName] (blank → the default
/// name), returning the ZIP bytes for ExportShareService to share.
///
/// [nowMillis] seeds timestamps and note/card IDs; it is injectable so tests are
/// deterministic. Throws if the native SQLite engine can't be loaded — callers
/// should catch that and fall back to CSV.
Uint8List flashcardsToApkg(
  List<Flashcard> cards, {
  required String? deckName,
  int? nowMillis,
}) {
  final collection = AnkiCollection.fromCards(
    cards,
    deckName: deckName,
    nowMillis: nowMillis ?? DateTime.now().millisecondsSinceEpoch,
  );
  final dbBytes = _buildCollectionDb(collection);

  final archive = Archive()
    ..add(ArchiveFile.bytes(_dbEntryName, dbBytes))
    // No media referenced by the cards → an empty JSON map.
    ..add(ArchiveFile.string(_mediaEntryName, '{}'));
  return ZipEncoder().encodeBytes(archive);
}

/// Writes [collection] into a throwaway on-disk SQLite database and returns its
/// bytes. On-disk (not in-memory) so the returned file is a complete, flushed
/// `.anki2`; the temp directory is always cleaned up.
Uint8List _buildCollectionDb(AnkiCollection collection) {
  final dir = Directory.systemTemp.createTempSync('inkflow_apkg');
  final path = '${dir.path}/$_dbEntryName';
  final db = sqlite3.open(path);
  try {
    db.execute('BEGIN;');
    for (final statement in ankiSchemaStatements) {
      db.execute(statement);
    }
    _insertRows(db, 'INSERT INTO col VALUES (${_placeholders(13)})',
        [collection.colValues]);
    _insertRows(db, 'INSERT INTO notes VALUES (${_placeholders(11)})',
        [for (final n in collection.notes) n.values]);
    _insertRows(db, 'INSERT INTO cards VALUES (${_placeholders(18)})',
        [for (final c in collection.cards) c.values]);
    db.execute('COMMIT;');
  } finally {
    db.close();
  }
  try {
    return File(path).readAsBytesSync();
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void _insertRows(Database db, String sql, List<List<Object?>> rows) {
  final statement = db.prepare(sql);
  try {
    for (final row in rows) {
      statement.execute(row);
    }
  } finally {
    statement.close();
  }
}

String _placeholders(int count) => List.filled(count, '?').join(',');
