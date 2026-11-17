// Keeps every page's search text current, so search and the tutor's keyword
// retrieval do not silently miss pages (Samsung Notes' indexing retry, in Isar).
//
// Before this, a page's text was only saved when the AI panel analysed it or a
// PDF import indexed it: handwriting on a page nobody opened the panel on could
// never be found. Now an edit marks the page ready (`markPageForIndex`), and
// [PageIndexQueue.run] reads ready pages one at a time, on the device, and
// marks them done. A failed read is tried again on a later run; a page that
// keeps failing waits for its next edit.

import 'package:isar_community/isar.dart';

import '../../features/home/domain/models/note_page.dart';
import '../../shared/isar/isar_service.dart';
import 'page_index_task.dart';
import 'page_text_store.dart';

/// A read that could not happen yet (no handwriting model on the device): the
/// page stays ready and the attempt does not count.
class PageReadDeferred implements Exception {
  const PageReadDeferred();
}

/// Reads one page's text. Throws [PageReadDeferred] when it cannot read yet,
/// anything else when the read failed.
typedef PageIndexReader = Future<({String text, String indexText})> Function(
    int pageId);

class PageIndexQueue {
  PageIndexQueue({
    required this.readPage,
    required this.texts,
    this.shouldPause,
    Isar Function()? isar,
  }) : _isarOverride = isar;

  final PageIndexReader readPage;
  final PageTextStore texts;

  /// True while background work should wait (a hot or low device): the run
  /// stops and the next one carries on.
  final Future<bool> Function()? shouldPause;

  final Isar Function()? _isarOverride;
  Isar get _isar => _isarOverride?.call() ?? IsarService.instance;

  Future<void>? _running;
  bool _again = false;
  bool _filled = false;

  /// Starts a run, or asks the one under way to go again when it ends. Never
  /// throws.
  Future<void> run() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = () async {
      try {
        do {
          _again = false;
          if (!_filled) {
            await fill();
            _filled = true;
          }
          await drain();
        } while (_again);
      } catch (_) {
        // Search keeps the text it has; the next run tries again.
      } finally {
        _running = null;
      }
    }();
  }

  /// Gives every page a row: ready when it has no search text yet, done when
  /// it has (it was read before this queue existed; re-reading it with the
  /// light reader could lose a deeper read). Drops rows of deleted pages.
  Future<void> fill() async {
    final pageIds = (await _isar.notePages.where().idProperty().findAll()).toSet();
    final known = (await _isar.pageIndexTasks.where().pageIdProperty().findAll())
        .toSet();
    final missing = pageIds.difference(known);
    final gone = known.difference(pageIds);
    final rows = <PageIndexTask>[];
    final now = DateTime.now();
    for (final id in missing) {
      final hasText = (await texts.forPage(id)).isNotEmpty;
      rows.add(PageIndexTask()
        ..pageId = id
        ..modifiedAt = now
        ..state = hasText ? PageIndexState.done : PageIndexState.ready);
    }
    if (rows.isEmpty && gone.isEmpty) return;
    await _isar.writeTxn(() async {
      await _isar.pageIndexTasks.putAll(rows);
      if (gone.isNotEmpty) {
        await _isar.pageIndexTasks
            .filter()
            .anyOf(gone, (q, id) => q.pageIdEqualTo(id))
            .deleteAll();
      }
    });
  }

  /// Reads the pages ready when it starts, in no particular order. A page
  /// changed during the run waits for the next one, so the page being written
  /// on is not read over and over. Returns how many pages were brought up to
  /// date.
  Future<int> drain() async {
    final ready = await _isar.pageIndexTasks
        .filter()
        .stateEqualTo(PageIndexState.ready)
        .findAll();
    var done = 0;
    for (final task in ready) {
      if (await shouldPause?.call() ?? false) break;
      final page = await _isar.notePages.get(task.pageId);
      if (page == null) {
        await _isar.writeTxn(() => _isar.pageIndexTasks.delete(task.id));
        continue;
      }
      final ({String text, String indexText}) read;
      try {
        read = await readPage(task.pageId);
      } on PageReadDeferred {
        continue;
      } catch (_) {
        await _update(task, (row) {
          row.attempts++;
          if (row.attempts >= PageIndexTask.maxAttempts) {
            row.state = PageIndexState.failed;
          }
        });
        continue;
      }
      await texts.save(
        notebookId: page.notebookId,
        pageId: task.pageId,
        text: read.text,
        indexText: read.indexText,
      );
      await _update(task, (row) => row.state = PageIndexState.done);
      done++;
    }
    return done;
  }

  /// Applies [change] to [task]'s row, unless the page changed after [task]
  /// was read from the queue: that edit's ready mark stands.
  Future<void> _update(PageIndexTask task, void Function(PageIndexTask) change) =>
      _isar.writeTxn(() async {
        final row = await _isar.pageIndexTasks.get(task.id);
        if (row == null || row.modifiedAt != task.modifiedAt) return;
        change(row);
        await _isar.pageIndexTasks.put(row);
      });
}
