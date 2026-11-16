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
Future<int?> findLinkTargetPage({
  required List<NotePage> pages,
  required Future<List<SceneElement>> Function(int pageId) load,
  required String fromImagePath,
  required int destPage,
  required int currentIndex,
}) async {
  final target = siblingPdfPagePath(fromImagePath, destPage);
  if (target == null) return null;
  int? best;
  for (var i = 0; i < pages.length; i++) {
    // Only pages that came from an import can show a PDF page.
    if (pages[i].importGroupId == null) continue;
    final shows = (await load(pages[i].id)).any(
        (e) => e is ImageElement && e.relativeImagePath == target);
    if (!shows) continue;
    if (best == null ||
        (i - currentIndex).abs() < (best - currentIndex).abs()) {
      best = i;
    }
  }
  return best;
}
