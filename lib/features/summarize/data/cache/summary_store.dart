// Summary cache access — a small seam over Isar so the summarization flow is
// unit-testable, plus the canonical text-hash function.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';

import '../../../../shared/isar/isar_service.dart';
import 'summary_cache.dart';

/// SHA-256 (hex) of the recognized text — the cache key discriminator. Pure
/// function so hash semantics are testable and never drift from the cache.
String hashRecognizedText(String text) =>
    sha256.convert(utf8.encode(text)).toString();

abstract class SummaryStore {
  Future<SummaryCache?> find(int notebookId);
  Future<void> save(SummaryCache entry);
}

class IsarSummaryStore implements SummaryStore {
  @override
  Future<SummaryCache?> find(int notebookId) => IsarService
      .instance.summaryCaches
      .where()
      .notebookIdEqualTo(notebookId)
      .findFirst();

  @override
  Future<void> save(SummaryCache entry) =>
      IsarService.instance.writeTxn(() async {
        final caches = IsarService.instance.summaryCaches;
        // One entry per notebook: replace any existing row inside the txn.
        await caches.where().notebookIdEqualTo(entry.notebookId).deleteAll();
        await caches.put(entry);
      });
}
