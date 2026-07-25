// Overflow menu (background, summarize, paste, library, export) for the editor
// app bar. Drop into AppBar.actions after the primary feature icons.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/commands/scene_command.dart';
import '../../../domain/model/library_item.dart';
import '../../../domain/services/library_service.dart';
import '../../../domain/services/z_order_service.dart';
import '../../../features/export/scene_export_service.dart';
import '../../state/clipboard_service.dart';
import '../../state/history_controller.dart';
import '../../state/scene_controller.dart';
import '../../state/scene_image_cache_provider.dart';
import '../../state/selection_controller.dart';
import '../../state/viewport_controller.dart';
import 'editor_controls_shared.dart';
import 'editor_library_sheet.dart';

/// The secondary actions live here rather than as their own app-bar buttons so
/// the top bar stays down to the handful of primary destinations (AI, study
/// plan, graph, book) plus this "⋮". Both entry points are optional because the
/// dev playground has no notebook to restyle or summarize — only the real
/// notebook editor wires them up.
class EditorAppBarActions extends ConsumerWidget {
  final ScenePageKey pageKey;
  final VoidCallback? onChangeBackground;
  final VoidCallback? onSummarize;
  const EditorAppBarActions({
    super.key,
    required this.pageKey,
    this.onChangeBackground,
    this.onSummarize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert),
      onSelected: (v) {
        switch (v) {
          case 'background':
            onChangeBackground?.call();
          case 'summarize':
            onSummarize?.call();
          case 'paste':
            _paste(ref);
          case 'library':
            _openLibrary(context, ref);
          case 'png':
          case 'svg':
          case 'pdf':
            _export(context, ref, v);
        }
      },
      itemBuilder: (_) => [
        if (onChangeBackground != null)
          const PopupMenuItem(
            value: 'background',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.wallpaper_outlined),
              title: Text('Background & paper…'),
            ),
          ),
        if (onSummarize != null)
          const PopupMenuItem(
            value: 'summarize',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.auto_awesome_outlined),
              title: Text('Summarize'),
            ),
          ),
        if (onChangeBackground != null || onSummarize != null)
          const PopupMenuDivider(),
        const PopupMenuItem(value: 'paste', child: Text('Paste')),
        const PopupMenuItem(value: 'library', child: Text('Element library…')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'png', child: Text('Export / share PNG')),
        const PopupMenuItem(value: 'svg', child: Text('Export / share SVG')),
        const PopupMenuItem(value: 'pdf', child: Text('Export / share PDF')),
      ],
    );
  }

  Future<void> _paste(WidgetRef ref) async {
    final els = await ClipboardService.paste(nextId: editorNewId);
    if (els == null || els.isEmpty) return;
    final base =
        ref.read(sceneControllerProvider(pageKey).notifier).nextZOrder();
    final placed = [
      for (int i = 0; i < els.length; i++)
        ZOrderService.withZOrder(els[i], base + i)
    ];
    ref
        .read(historyProvider(pageKey).notifier)
        .push(AddElementsCommand(placed));
    ref.read(selectionProvider.notifier).selectMany(placed.map((e) => e.id));
  }

  Future<void> _openLibrary(BuildContext context, WidgetRef ref) async {
    final item = await showModalBottomSheet<LibraryItem>(
      context: context,
      showDragHandle: true,
      builder: (_) => const EditorLibrarySheet(),
    );
    if (item == null || !context.mounted) return;
    final size = MediaQuery.of(context).size;
    final at = ref
        .read(viewportProvider)
        .toScene(Offset(size.width / 2, size.height / 2));
    final base =
        ref.read(sceneControllerProvider(pageKey).notifier).nextZOrder();
    final els = LibraryService.instantiate(item,
        at: at, nextId: editorNewId, baseZOrder: base);
    if (els.isEmpty) return;
    ref.read(historyProvider(pageKey).notifier).push(AddElementsCommand(els));
    ref.read(selectionProvider.notifier).selectMany(els.map((e) => e.id));
  }

  Future<void> _export(BuildContext context, WidgetRef ref, String fmt) async {
    final sel = editorSelection(ref, pageKey);
    final els =
        sel.isNotEmpty ? sel : ref.read(sceneControllerProvider(pageKey));
    if (els.isEmpty) {
      _toast(context, 'Nothing to export');
      return;
    }
    final cache = ref.read(sceneImageCacheProvider);
    final ok = switch (fmt) {
      'png' => await SceneExportService.sharePng(els, imageCache: cache),
      'svg' => await SceneExportService.shareSvg(els),
      'pdf' => await SceneExportService.sharePdf(els, imageCache: cache),
      _ => false,
    };
    if (!ok && context.mounted) _toast(context, 'Nothing to export');
  }

  void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
