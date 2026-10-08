// The vision-read cache on disk (Isar).
//
// Bounded: a read is a few KB at most, but nothing deletes a page's reads when
// its notebook goes, so left alone the table only grows. Past [maxEntries] the
// OLDEST reads are dropped — a read costs a model load and a vision pass to make
// again, so what was read recently is what is worth keeping — and a little extra
// ([trimBatch]) so trimming does not run on every single save.

import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../../../../shared/isar/isar_service.dart';
import '../../domain/figure.dart';
import '../../domain/read_cache.dart';
import 'read_cache_record.dart';

class IsarReadCache implements ReadCache {
  final Isar Function() _isar;
  final int maxEntries;
  final int trimBatch;

  /// [isar] defaults to the app's shared database; tests pass their own.
  IsarReadCache({
    Isar Function()? isar,
    this.maxEntries = 4000,
    this.trimBatch = 250,
  }) : _isar = isar ?? (() => IsarService.instance);

  @override
  Future<CachedRead?> find(String key) async {
    final row = await _isar().readCacheRecords.where().keyEqualTo(key).findFirst();
    if (row == null) return null;

    FigureDescription? figure;
    final json = row.figureJson;
    if (json != null) {
      try {
        figure = FigureDescription.fromJson(jsonDecode(json) as Map<String, dynamic>);
      } catch (_) {
        // A damaged figure is a missing figure; the text is still good.
      }
    }
    return CachedRead(text: row.text, figure: figure);
  }

  @override
  Future<void> save(String key, CachedRead read) {
    final isar = _isar();
    final rows = isar.readCacheRecords;
    return isar.writeTxn(() async {
      // Delete-then-insert in one transaction keeps it to one row per key
      // without a unique index (see [ReadCacheRecord]), and the fresh row gets a
      // later id — so re-saving a read also makes it "recent" again.
      await rows.where().keyEqualTo(key).deleteAll();
      await rows.put(ReadCacheRecord()
        ..key = key
        ..text = read.text
        ..figureJson =
            read.figure == null ? null : jsonEncode(read.figure!.toJson()));

      final excess = await rows.count() - maxEntries;
      if (excess > 0) {
        final oldest =
            await rows.where().anyId().limit(excess + trimBatch).idProperty().findAll();
        await rows.deleteAll(oldest);
      }
    });
  }
}
