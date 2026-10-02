// Remembering what the vision model has already read, so it never reads the same
// thing twice.
//
// A deep read of a page is the most expensive thing the app does — a model load
// plus a vision pass per image, per region of handwriting, per figure — and the
// content it reads almost never changes: an imported PDF page is written once
// and only ever deleted, and ink is immutable once drawn. Yet the only memory of
// those reads was per-session, so reopening a notebook after a restart, or
// re-indexing it, paid for every one again.
//
// So each read is stored under a key made of exactly what determines its answer:
// the image that was sent, what kind of read it was, which prompt wrote it and
// which model answered. A "Re-read" deliberately skips the lookup (that is what
// asking to read it again means) and replaces the entry with the new reading.
//
// Pure, with persistence behind [ReadCache], like the rest of `domain/`.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'figure.dart';

/// What one expensive vision read produced.
class CachedRead {
  /// The transcription ('' when the read yielded no text).
  final String text;

  /// The figure read off the same image, or null when there was none — an
  /// attempted read that found no figure is remembered as such, so it is not
  /// attempted again.
  final FigureDescription? figure;

  const CachedRead({required this.text, this.figure});
}

/// Durable memory of vision reads. Implementations must not throw for ordinary
/// misses; a caller treats any failure as "nothing cached" — a cache must never
/// be able to take a page read down with it.
abstract class ReadCache {
  /// The read saved under [key], or null.
  Future<CachedRead?> find(String key);

  /// Saves [read] under [key], replacing any earlier one.
  Future<void> save(String key, CachedRead read);
}

/// The key for a read: `kind|sha1(content)|version|model`.
///
/// ponytail: the hash runs on the calling isolate — a few milliseconds for a
/// multi-megabyte page image, once per read. Move it to `compute` if a profile
/// ever shows it as jank.
///
/// [kind] separates different questions asked of the same pixels (`img`, `ink`,
/// `drawn`). [content] is hashed — never stored — so a key reveals nothing about
/// what the student wrote. [version] is the prompt/parser generation (see
/// `GemmaVisionOcrService.cacheVersion`), bumped when it changes so old readings
/// are not served as if the new prompt had written them. [modelId] is the model
/// that answers now, so switching models reads afresh.
String readCacheKey({
  required String kind,
  required Uint8List content,
  required String version,
  required String modelId,
}) =>
    '$kind|${sha1.convert(content)}|$version|$modelId';

/// A [ReadCache] held in memory — for tests, and for anything that wants the
/// behaviour without a database.
class InMemoryReadCache implements ReadCache {
  final Map<String, CachedRead> entries = {};

  @override
  Future<CachedRead?> find(String key) async => entries[key];

  @override
  Future<void> save(String key, CachedRead read) async => entries[key] = read;
}
