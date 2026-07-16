// Isar collection caching one summary per notebook, keyed by a SHA-256 hash
// of the recognized text — unchanged note → instant cached summary.

import 'package:isar/isar.dart';

part 'summary_cache.g.dart';

@collection
class SummaryCache {
  Id id = Isar.autoIncrement;

  /// One entry per notebook — enforced by [IsarSummaryStore.save] (a unique
  /// index would generate Isar's experimental ByIndex accessors and trip
  /// `flutter analyze`; a plain index only emits stable where-clauses).
  @Index()
  late int notebookId;

  /// SHA-256 (hex) of the page-order-concatenated recognized text.
  late String textHash;

  late String summary;

  /// Which model produced it (e.g. 'gemma4-e2b-local', 'cloud-stub').
  late String modelUsed;

  late DateTime createdAt;
}
