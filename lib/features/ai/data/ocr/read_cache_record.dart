// Isar persistence for the vision-read cache (see `domain/read_cache.dart`).
//
// One row per remembered read. The key is looked up by equality, through a hash
// index. It is NOT a unique index: that would make the generator emit Isar's
// `@experimental` by-index helpers, which the analyzer then flags — the same
// reason NoteChunkRecord and PageTextRecord keep their natural keys out of one
// — so a save deletes any row for the key and inserts a fresh one in a single
// transaction instead.

import 'package:isar/isar.dart';

part 'read_cache_record.g.dart';

@collection
class ReadCacheRecord {
  /// Auto-increment, so a larger id is a later save — which is how the oldest
  /// rows are found when the cache is trimmed.
  Id id = Isar.autoIncrement;

  /// See `readCacheKey`: kind, hash of the exact image sent, prompt version and
  /// model. Never contains the content itself.
  @Index(type: IndexType.hash)
  late String key;

  /// The transcription ('' when the read yielded no text).
  late String text;

  /// The figure as JSON text, or null when the read found none.
  String? figureJson;
}
