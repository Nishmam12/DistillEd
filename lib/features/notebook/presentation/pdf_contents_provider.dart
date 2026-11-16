// A notebook's PDF contents: the table-of-contents entries of the PDFs imported
// into it, each with the notebook page it lands on, in page order.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/model/scene_element.dart';
import '../../../editor/state/page_notifier.dart';
import '../../../editor/state/scene_controller.dart';
import '../../import/page_links_service.dart';

class PdfContentsItem {
  final String title;
  final int depth;

  /// Position of the page in the notebook.
  final int pageIndex;

  const PdfContentsItem(
      {required this.title, required this.depth, required this.pageIndex});
}

/// Only pages that came from an import are looked at, and only their sidecar
/// files are read: nothing is recognised.
final pdfContentsProvider = FutureProvider.autoDispose
    .family<List<PdfContentsItem>, int>((ref, notebookId) async {
  final pages = ref.watch(pageProvider(notebookId)).pages;
  final store = ref.read(sceneElementStoreProvider);
  final links = ref.read(pageLinksServiceProvider);
  final found = <({int pageIndex, int order, PdfContentsItem item})>[];
  final seen = <String>{};
  for (var i = 0; i < pages.length; i++) {
    if (pages[i].importGroupId == null) continue;
    for (final e in await store.loadForPage(pages[i].id)) {
      if (e is! ImageElement) continue;
      for (final o in (await links.linksFor(e.relativeImagePath)).outline) {
        if (!seen.add('$i|${o.order}')) continue;
        found.add((
          pageIndex: i,
          order: o.order,
          item: PdfContentsItem(title: o.title, depth: o.depth, pageIndex: i),
        ));
      }
    }
  }
  found.sort((a, b) {
    final byPage = a.pageIndex.compareTo(b.pageIndex);
    return byPage != 0 ? byPage : a.order.compareTo(b.order);
  });
  return [for (final f in found) f.item];
});
