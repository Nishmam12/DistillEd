// One row per page saying whether its search text is current: the durable
// queue behind `PageIndexQueue` (Samsung Notes' retry table, in Isar).
//
// An edit to a page's elements marks its row ready in the same transaction
// (see `IsarSceneElementStore`); the queue reads ready pages on the device and
// marks them done. A row whose page is gone is pruned by the queue.

import 'package:isar_community/isar.dart';

part 'page_index_task.g.dart';

enum PageIndexState {
  /// Changed since its text was last read.
  ready,

  /// Its search text is current.
  done,

  /// Could not be read [PageIndexTask.maxAttempts] times; waits for an edit.
  failed,
}

@collection
class PageIndexTask {
  Id id = Isar.autoIncrement;

  /// One row per page, kept by `markPageForIndex` (no unique index, for the
  /// same reason as PageTextRecord).
  @Index()
  late int pageId;

  /// When the page last changed. A read only marks the row done if this is
  /// still what it was when the read began.
  late DateTime modifiedAt;

  @Index()
  @enumerated
  PageIndexState state = PageIndexState.ready;

  /// Failed reads since the last edit.
  int attempts = 0;

  static const maxAttempts = 3;
}

/// Marks [pageId]'s search text as out of date. Must run inside a write
/// transaction; one small indexed write, cheap enough for every pen-up.
Future<void> markPageForIndex(Isar isar, int pageId) async {
  final row = await isar.pageIndexTasks
          .filter()
          .pageIdEqualTo(pageId)
          .findFirst() ??
      (PageIndexTask()..pageId = pageId);
  row
    ..modifiedAt = DateTime.now()
    ..state = PageIndexState.ready
    ..attempts = 0;
  await isar.pageIndexTasks.put(row);
}
