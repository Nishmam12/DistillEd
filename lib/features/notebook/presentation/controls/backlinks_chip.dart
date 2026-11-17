// "Linked from": the pages that link to this one (or to its whole notebook),
// Evernote's Backlinks. A quiet chip that is only there when something links
// here; tapping it lists them.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../editor/state/page_notifier.dart';
import '../../../../editor/state/scene_controller.dart';
import '../../../home/presentation/home_notifier.dart' show noteRepositoryProvider;

typedef Backlink = ({
  int pageId,
  int pageIndex,
  int notebookId,
  String notebookTitle,
});

/// Read when a page opens. A link made elsewhere meanwhile shows on the next
/// visit to this page.
final backlinksProvider = FutureProvider.autoDispose
    .family<List<Backlink>, ScenePageKey>((ref, key) async {
  final ids = await ref
      .read(sceneElementStoreProvider)
      .pagesLinkingTo(pageId: key.pageId, notebookId: key.notebookId);
  final pages = ref.read(pageRepositoryProvider);
  final notes = ref.read(noteRepositoryProvider);
  final out = <Backlink>[];
  for (final id in ids) {
    final page = await pages.getPage(id);
    if (page == null) continue;
    final notebook = await notes.getNotebook(page.notebookId);
    // A page in the trash is not somewhere to go.
    if (notebook == null || notebook.isInTrash) continue;
    out.add((
      pageId: page.id,
      pageIndex: page.pageIndex,
      notebookId: notebook.id,
      notebookTitle: notebook.title,
    ));
  }
  out.sort((a, b) {
    final byNotebook = a.notebookTitle.compareTo(b.notebookTitle);
    return byNotebook != 0 ? byNotebook : a.pageIndex.compareTo(b.pageIndex);
  });
  return out;
});

class BacklinksChip extends ConsumerWidget {
  final ScenePageKey pageKey;
  final void Function(Backlink) onOpen;

  const BacklinksChip({super.key, required this.pageKey, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(backlinksProvider(pageKey)).value ?? const [];
    if (links.isEmpty) return const SizedBox.shrink();
    return ActionChip(
      avatar: const Icon(Icons.link, size: 18),
      label: Text('Linked from ${links.length}'),
      onPressed: () async {
        final picked = await showModalBottomSheet<Backlink>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('Linked from')),
                for (final link in links)
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(link.notebookTitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Page ${link.pageIndex + 1}'),
                    onTap: () => Navigator.of(context).pop(link),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) onOpen(picked);
      },
    );
  }
}
