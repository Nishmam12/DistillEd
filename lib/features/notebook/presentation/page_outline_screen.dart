// The outline: the contents of imported PDFs, then the pages the user
// bookmarked or named, in page order. Tap one to open it in the editor.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../editor/state/page_notifier.dart';
import 'pdf_contents_provider.dart';

class PageOutlineScreen extends ConsumerStatefulWidget {
  final int notebookId;
  const PageOutlineScreen({super.key, required this.notebookId});

  @override
  ConsumerState<PageOutlineScreen> createState() => _PageOutlineScreenState();
}

class _PageOutlineScreenState extends ConsumerState<PageOutlineScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(pageProvider(widget.notebookId).notifier).initialize());
  }

  void _open(int index) {
    ref.read(pageProvider(widget.notebookId).notifier).switchPage(index);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final pages = ref.watch(pageProvider(widget.notebookId)).pages;
    final contents = ref.watch(pdfContentsProvider(widget.notebookId)).value ??
        const <PdfContentsItem>[];
    final entries = [
      for (var i = 0; i < pages.length; i++)
        if (pages[i].bookmarked || pages[i].title.isNotEmpty) i,
    ];
    final theme = Theme.of(context);
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(text, style: theme.textTheme.titleSmall),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Outline')),
      body: entries.isEmpty && contents.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bookmark or name a page and it shows up here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                if (contents.isNotEmpty) ...[
                  heading('PDF contents'),
                  for (var n = 0; n < contents.length; n++)
                    ListTile(
                      key: Key('contentsEntry_$n'),
                      dense: true,
                      contentPadding: EdgeInsets.only(
                          left: 16.0 + 16 * contents[n].depth.clamp(0, 5),
                          right: 16),
                      title: Text(contents[n].title,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text('${contents[n].pageIndex + 1}'),
                      onTap: () => _open(contents[n].pageIndex),
                    ),
                ],
                if (entries.isNotEmpty) ...[
                  if (contents.isNotEmpty) heading('Your pages'),
                  for (final i in entries)
                    ListTile(
                      key: Key('outlineEntry_$i'),
                      leading: Icon(pages[i].bookmarked
                          ? Icons.bookmark
                          : Icons.description_outlined),
                      title: Text(pages[i].title.isEmpty
                          ? 'Page ${i + 1}'
                          : pages[i].title),
                      subtitle:
                          pages[i].title.isEmpty ? null : Text('Page ${i + 1}'),
                      onTap: () => _open(i),
                    ),
                ],
              ],
            ),
    );
  }
}
