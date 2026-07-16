// Loads a notebook's ink for summarization from the unified scene store
// (editor 2.0). This is the Inkdot-2.0 replacement for main's legacy
// InkFileStorage-based page collection: pages come from [PageRepository]
// (pageIndex order) and each page's elements from [SceneElementStore] — the
// store is written through on every editor mutation, so it is always current.
//
// The recognition pipeline (`HandwritingRecognitionService`) speaks the
// legacy [Stroke] shape; [FreehandElement] carries the identical per-point
// data (same [StrokePoint], including the capture timestamp `t`), so the
// adaptation is a field-for-field copy. Phase U replaces this seam with the
// SceneElement-native PageContentExtractor.

import '../../../data/persistence/scene_element_store.dart';
import '../../../domain/model/scene_element.dart';
import '../../editor/domain/models/stroke.dart';
import '../../home/domain/models/note_page.dart';

class SceneNotebookInkLoader {
  final SceneElementStore _store;
  final Future<List<NotePage>> Function(int notebookId) _pagesOf;

  SceneNotebookInkLoader({
    required SceneElementStore store,
    required Future<List<NotePage>> Function(int notebookId) pagesOf,
  })  : _store = store,
        _pagesOf = pagesOf;

  /// All freehand ink in [notebookId], one stroke list per page, in page
  /// order. Non-ink elements (shapes, text, images, frames) are skipped —
  /// typed text enters the AI pipeline separately in Phase U.
  Future<List<List<Stroke>>> loadPagesStrokes(int notebookId) async {
    final pages = await _pagesOf(notebookId);
    return [
      for (final page in pages)
        [
          for (final element in await _store.loadForPage(page.id))
            if (element is FreehandElement)
              Stroke(
                id: element.id,
                color: element.color,
                size: element.size,
                opacity: element.opacity,
                isEraser: element.isEraser,
                points: element.points,
              ),
        ],
    ];
  }
}
