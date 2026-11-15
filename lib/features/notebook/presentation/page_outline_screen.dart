// The outline: the pages the user bookmarked or named, in page order. Tap one to
// open it in the editor.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../editor/state/page_notifier.dart';

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

  @override
  Widget build(BuildContext context) {
    final pages = ref.watch(pageProvider(widget.notebookId)).pages;
    final entries = [
      for (var i = 0; i < pages.length; i++)
        if (pages[i].bookmarked || pages[i].title.isNotEmpty) i,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Outline')),
      body: entries.isEmpty
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
                    onTap: () {
                      ref
                          .read(pageProvider(widget.notebookId).notifier)
                          .switchPage(i);
                      Navigator.of(context).maybePop();
                    },
                  ),
              ],
            ),
    );
  }
}
