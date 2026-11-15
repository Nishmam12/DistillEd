// The bar shown over the page while words of a page picture are selected
// (select tool, Text mode): Copy, Highlight, Ask the AI, Search.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/persistence/page_text_store.dart';
import '../../../../domain/commands/scene_command.dart';
import '../../../../domain/model/element_id.dart';
import '../../../../domain/model/scene_element.dart';
import '../../../../domain/services/text_highlight.dart';
import '../../../../editor/state/editor_tool_controller.dart';
import '../../../../editor/state/history_controller.dart';
import '../../../../editor/state/page_notifier.dart';
import '../../../../editor/state/page_text_selection.dart';
import '../../../../editor/state/pen_presets.dart';
import '../../../../editor/state/scene_controller.dart';
import '../../domain/page_text_search.dart';

class TextSelectionBar extends ConsumerWidget {
  final ScenePageKey pageKey;

  /// Ask the AI about the selected text (the editor opens the panel).
  final ValueChanged<String> onAsk;

  /// Go to a page of this notebook, by id.
  final ValueChanged<int> onJump;

  const TextSelectionBar({
    super.key,
    required this.pageKey,
    required this.onAsk,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(pageTextSelectionProvider);
    final tool = ref.watch(editorToolProvider);
    if (sel == null ||
        sel.key != pageKey ||
        sel.indexes.isEmpty ||
        tool.tool != EditorTool.select ||
        !tool.selectText) {
      return const SizedBox.shrink();
    }
    return Material(
      key: const Key('textSelectionBar'),
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('textCopy'),
              tooltip: 'Copy',
              icon: const Icon(Icons.copy),
              onPressed: () => _copy(context, sel.text),
            ),
            IconButton(
              key: const Key('textHighlight'),
              tooltip: 'Highlight',
              icon: const Icon(Icons.border_color_outlined),
              onPressed: () => _highlight(ref, sel),
            ),
            IconButton(
              key: const Key('textAsk'),
              tooltip: 'Ask the AI',
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: () {
                _clear(ref);
                onAsk(sel.text);
              },
            ),
            IconButton(
              key: const Key('textSearch'),
              tooltip: 'Search this notebook',
              icon: const Icon(Icons.search),
              onPressed: () => _search(context, ref, sel.text),
            ),
            IconButton(
              key: const Key('textClose'),
              tooltip: 'Clear selection',
              icon: const Icon(Icons.close),
              onPressed: () => _clear(ref),
            ),
          ],
        ),
      ),
    );
  }

  void _clear(WidgetRef ref) =>
      ref.read(pageTextSelectionProvider.notifier).state = null;

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Copied')));
  }

  /// Lays clean highlighter marks over the selected words, in the highlighter
  /// pen's colour, as one undo step.
  void _highlight(WidgetRef ref, PageTextSelection sel) {
    final scene = ref.read(sceneControllerProvider(pageKey).notifier);
    ImageElement? image;
    for (final e in ref.read(sceneControllerProvider(pageKey))) {
      if (e is ImageElement && e.id == sel.imageId) image = e;
    }
    if (image == null) return;
    final pen = ref.read(editorToolProvider).penMemory[PenKind.highlighter] ??
        defaultPenFor(PenKind.highlighter);
    final strokes = highlightStrokes(
      image: image,
      words: sel.words,
      indexes: sel.indexes,
      color: pen.color,
      opacity: pen.opacity,
      newId: newElementId,
      nextZOrder: scene.nextZOrder,
    );
    if (strokes.isEmpty) return;
    ref.read(historyProvider(pageKey).notifier).push(AddElementsCommand(strokes));
    _clear(ref);
  }

  Future<void> _search(BuildContext context, WidgetRef ref, String text) async {
    final texts =
        await ref.read(pageTextStoreProvider).forNotebook(pageKey.notebookId);
    if (!context.mounted) return;
    final pages = ref.read(pageProvider(pageKey.notebookId)).pages;
    final order = {for (var i = 0; i < pages.length; i++) pages[i].id: i};
    final sorted = [...texts.where((t) => order.containsKey(t.pageId))]
      ..sort((a, b) => order[a.pageId]!.compareTo(order[b.pageId]!));
    final hits = searchPageTexts(sorted, text);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => _SearchResults(
        query: text,
        hits: hits,
        pageNumber: (id) => (order[id] ?? 0) + 1,
        onOpen: (id) {
          Navigator.pop(sheet);
          onJump(id);
        },
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final String query;
  final List<PageTextHit> hits;
  final int Function(int pageId) pageNumber;
  final ValueChanged<int> onOpen;

  const _SearchResults({
    required this.query,
    required this.hits,
    required this.pageNumber,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final short = query.length > 40 ? '${query.substring(0, 40)}…' : query;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                hits.isEmpty
                    ? 'No page in this notebook mentions "$short"'
                    : '${hits.length} ${hits.length == 1 ? 'page' : 'pages'} '
                        'mention "$short"',
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (hits.isNotEmpty)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final h in hits)
                      ListTile(
                        key: Key('searchHit_${h.pageId}'),
                        leading: CircleAvatar(
                            child: Text('${pageNumber(h.pageId)}')),
                        title: Text(h.snippet,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => onOpen(h.pageId),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
