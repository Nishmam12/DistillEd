// Which page of a notebook a PDF link lands on.
//
// A link keeps the PDF page number it points at. The picture of that PDF page
// is named for it (`siblingPdfPagePath`), and the notebook page showing that
// picture is looked for now: pages can have been reordered, copied or deleted
// since the import, and only some of the PDF may have been imported.

import '../../domain/model/page_links.dart';
import '../../domain/model/scene_element.dart';
import '../home/domain/models/note_page.dart';

/// The index in [pages] of the page showing the picture of PDF page [destPage]
/// beside [fromImagePath], or null when there is none. When more than one page
/// shows it (a copied page), the one nearest [currentIndex] wins, the earlier
/// on a tie.
///
/// Searches outwards from the current page and stops at the first hit, so the
/// usual link (to a page close by) reads only a few pages. Every page is a
/// candidate: a copy of a page does not carry its import mark.
Future<int?> findLinkTargetPage({
  required List<NotePage> pages,
  required Future<List<SceneElement>> Function(int pageId) load,
  required String fromImagePath,
  required int destPage,
  required int currentIndex,
}) async {
  final target = siblingPdfPagePath(fromImagePath, destPage);
  if (target == null || pages.isEmpty) return null;
  Future<bool> shows(int i) async => (await load(pages[i].id)).any(
      (e) => e is ImageElement && e.relativeImagePath == target);

  final from = currentIndex.clamp(0, pages.length - 1);
  for (var d = 0; d < pages.length; d++) {
    // The earlier page first, so a tie goes to it.
    final before = from - d, after = from + d;
    if (before >= 0 && await shows(before)) return before;
    if (d > 0 && after < pages.length && await shows(after)) return after;
  }
  return null;
}
