// Picks where a selection links to: a page of any notebook, or a whole
// notebook. Pops with the link's stored form (`page:12`, `notebook:3`), '' to
// remove the link, or null when dismissed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/model/element_link.dart';
import '../../../../editor/state/page_notifier.dart';
import '../../../home/presentation/home_notifier.dart';

Future<String?> showLinkPicker(
  BuildContext context, {
  required int currentNotebookId,
  required int currentPageId,
  required bool hasLink,
}) =>
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _LinkPicker(
        currentNotebookId: currentNotebookId,
        currentPageId: currentPageId,
        hasLink: hasLink,
      ),
    );

class _LinkPicker extends ConsumerWidget {
  final int currentNotebookId;
  final int currentPageId;
  final bool hasLink;

  const _LinkPicker({
    required this.currentNotebookId,
    required this.currentPageId,
    required this.hasLink,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This notebook first: most links are to another page of the same notes.
    // Hidden notebooks are not offered, except this one when it is open.
    final notebooks = [
      for (final n in ref.watch(homeNotifierProvider))
        if (!n.hidden || n.id == currentNotebookId) n,
    ]
      ..sort((a, b) => (a.id == currentNotebookId ? 0 : 1)
          .compareTo(b.id == currentNotebookId ? 0 : 1));
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Link to')),
            if (hasLink)
              ListTile(
                leading: const Icon(Icons.link_off),
                title: const Text('Remove link'),
                onTap: () => Navigator.of(context).pop(''),
              ),
            for (final nb in notebooks)
              ExpansionTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(nb.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                initiallyExpanded: nb.id == currentNotebookId,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 72, right: 16),
                    title: const Text('Whole notebook'),
                    onTap: () => Navigator.of(context)
                        .pop(LinkToNotebook(nb.id).encoded),
                  ),
                  FutureBuilder(
                    future:
                        ref.read(pageRepositoryProvider).getPagesForNotebook(nb.id),
                    builder: (context, snapshot) {
                      final pages = snapshot.data;
                      if (pages == null) return const SizedBox(height: 8);
                      return Column(children: [
                        for (final (i, page) in pages.indexed)
                          if (page.id != currentPageId)
                            ListTile(
                              contentPadding:
                                  const EdgeInsets.only(left: 72, right: 16),
                              title: Text(page.title.isEmpty
                                  ? 'Page ${i + 1}'
                                  : 'Page ${i + 1} · ${page.title}'),
                              onTap: () => Navigator.of(context)
                                  .pop(LinkToPage(page.id).encoded),
                            ),
                      ]);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
