// Shared editor chrome for the unified canvas — the bottom tool/style bar, the
// selection action bar, the app-bar actions (undo/redo + overflow menu), and the
// style / library bottom sheets. Parameterised by [ScenePageKey] so the dev
// playground and the real notebook editor drive the same controls over their own
// page (and their own provider scope / store).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/commands/scene_command.dart';
import '../../domain/geometry/element_bounds.dart';
import '../../domain/model/library_item.dart';
import '../../domain/model/scene_element.dart';
import '../../domain/services/alignment_service.dart';
import '../../domain/services/library_service.dart';
import '../../domain/services/selection_editing.dart';
import '../../domain/services/z_order_service.dart';
import '../../features/ai/data/ocr/image_text_recognition_service.dart';
import '../../features/ai/presentation/ai_providers.dart';
import '../../features/export/scene_export_service.dart';
import '../import/ocr_layout.dart';
import '../render/scene_element_painter.dart';
import '../render/scene_image_cache.dart';
import '../state/clipboard_service.dart';
import '../state/editor_tool_controller.dart';
import '../state/favorite_colors_controller.dart';
import '../state/history_controller.dart';
import '../state/library_controller.dart';
import '../state/scene_controller.dart';
import '../state/scene_image_cache_provider.dart';
import '../state/selection_controller.dart';
import '../state/viewport_controller.dart';
import 'text_input_dialog.dart';

const List<int> kEditorPalette = [
  0xFF1F2933,
  0xFFE03131,
  0xFF1971C2,
  0xFF2F9E44,
  0xFFF08C00,
];

// The primary drawing tools, in the order they sit in the toolbar. Frame and
// hand stay in [EditorTool] (the canvas still handles them, and two-finger pan
// covers hand) but are kept off this row to match the pared-back design; image
// import rides at the end as an action, not a tool (see [EditorBottomBar]).
const List<(EditorTool, IconData)> kEditorTools = [
  (EditorTool.select, Icons.near_me_outlined),
  (EditorTool.pen, Icons.edit),
  (EditorTool.shape, Icons.category),
  (EditorTool.text, Icons.title),
  (EditorTool.eraser, Icons.cleaning_services_outlined),
  (EditorTool.laser, Icons.flashlight_on_outlined),
];

const List<(ShapeType, IconData)> kEditorShapes = [
  (ShapeType.rectangle, Icons.crop_square),
  (ShapeType.circle, Icons.circle_outlined),
  (ShapeType.diamond, Icons.diamond_outlined),
  (ShapeType.triangle, Icons.change_history),
  (ShapeType.line, Icons.remove),
  (ShapeType.arrow, Icons.arrow_right_alt),
];

String editorNewId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 30)}';

List<SceneElement> editorSelection(WidgetRef ref, ScenePageKey key) {
  final ids = ref.read(selectionProvider);
  return ref
      .read(sceneControllerProvider(key))
      .where((e) => ids.contains(e.id))
      .toList();
}

/// Overflow menu (background, summarize, paste, library, export) for the editor
/// app bar. Drop into AppBar.actions after the primary feature icons.
///
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

/// The full bottom bar: selection actions + tools + style + palette + size.
///
/// When [floating] is true the bar paints its own translucent background and
/// rounded bottom edge so it can be overlaid at the top of the canvas instead
/// of sitting in the Scaffold's bottom slot.
/// The tool/style bar. Docked directly under the app bar in the real editor
/// (with a divider below it) and used as the bottom bar in the dev playground;
/// callers wrap it in a [SafeArea] when it sits at a screen edge.
class EditorBottomBar extends ConsumerWidget {
  final ScenePageKey pageKey;

  /// Opens the import sheet (photo / camera / PDF). When null — as in the dev
  /// playground, which has no notebook to import into — the import button is
  /// omitted from the tool row.
  final VoidCallback? onImport;

  const EditorBottomBar({
    super.key,
    required this.pageKey,
    this.onImport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(editorToolProvider);
    final selectedIds = ref.watch(selectionProvider);
    final toolCtl = ref.read(editorToolProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedIds.isNotEmpty) _SelectionBar(pageKey: pageKey),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (t, icon) in kEditorTools)
                        _ToolIconButton(
                          tool: t,
                          icon: icon,
                          state: tool,
                          onTap: () {
                            // Re-tapping the active eraser flips its mode
                            // (stroke/element ↔ pixel) without opening a menu.
                            if (t == EditorTool.eraser &&
                                tool.tool == EditorTool.eraser) {
                              toolCtl.setEraserPixel(!tool.eraserPixel);
                            } else {
                              toolCtl.setTool(t);
                            }
                          },
                        ),
                      // Image import sits at the end of the tools as an action
                      // (it opens the import sheet rather than selecting a tool).
                      if (onImport != null)
                        IconButton(
                          tooltip: 'Import image / PDF',
                          icon: const Icon(Icons.image_outlined),
                          onPressed: onImport,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Three persisted favourite colours: tap to use, long-press to
              // reassign. They stand in for the old always-on palette; the full
              // colour grid and stroke size now live in the Style sheet.
              const _FavoriteSwatches(),
              const SizedBox(width: 4),
              _UndoRedoButtons(pageKey: pageKey),
              IconButton.filledTonal(
                tooltip: 'Style',
                icon: const Icon(Icons.tune),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => const EditorStyleSheet(),
                ),
              ),
            ],
          ),
          if (tool.tool == EditorTool.shape) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: [
                for (final (type, icon) in kEditorShapes)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Icon(icon, size: 18),
                    selected: tool.shapeType == type,
                    onSelected: (_) => toolCtl.setShapeType(type),
                  ),
              ],
            ),
          ],
          // Pen and eraser are the two tools driven by stroke thickness, so
          // their size slider stays docked below the tool row the whole time
          // either is selected (rather than being tucked into the Style sheet).
          if (tool.tool == EditorTool.pen ||
              tool.tool == EditorTool.eraser)
            _ThicknessSlider(value: tool.size, onChanged: toolCtl.setSize),
        ],
      ),
    );
  }
}

/// The pen/eraser stroke-thickness slider shown below the tool row. Its own
/// stateless widget so the toolbar's build stays readable.
class _ThicknessSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _ThicknessSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.line_weight, size: 18),
        ),
        Expanded(
          child: Slider(
            min: 1,
            max: 24,
            value: value.clamp(1, 24),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 24,
          child: Text('${value.round()}', textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

/// A single tool button in the bottom bar. For the eraser it shows a distinct
/// icon per mode (stroke/element vs pixel) so the current mode is visible, and
/// its tap behaviour (select vs toggle mode) is decided by the parent.
class _ToolIconButton extends StatelessWidget {
  final EditorTool tool;
  final IconData icon;
  final EditorToolState state;
  final VoidCallback onTap;

  const _ToolIconButton({
    required this.tool,
    required this.icon,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = state.tool == tool;
    final isEraser = tool == EditorTool.eraser;

    final displayIcon = isEraser
        ? (state.eraserPixel ? Icons.auto_fix_high : Icons.layers_clear)
        : icon;
    final tooltip = isEraser
        ? (state.eraserPixel
            ? 'Pixel eraser — tap to switch to stroke'
            : 'Stroke eraser — tap to switch to pixel')
        : null;

    return IconButton(
      tooltip: tooltip,
      isSelected: isActive,
      onPressed: onTap,
      icon: Icon(displayIcon),
      style: IconButton.styleFrom(
        backgroundColor:
            isActive ? Theme.of(context).colorScheme.primaryContainer : null,
      ),
    );
  }
}

/// The palette offered when reassigning a favourite swatch (long-press). A
/// compact, purposeful spread — greys through the warm/cool spectrum — rather
/// than a full colour wheel, which is overkill for three quick-pick slots.
const List<int> kFavoritePickerColors = [
  0xFF1F2933, // charcoal
  0xFF000000, // black
  0xFF868E96, // grey
  0xFFE03131, // red
  0xFFF2802E, // orange
  0xFFE3A53D, // honey
  0xFF2F9E44, // green
  0xFF1971C2, // blue
  0xFF6741D9, // violet
  0xFF8B8BD8, // periwinkle
  0xFFC2255C, // magenta
  0xFFFFFFFF, // white
];

/// A circular colour swatch with an optional selection ring — the shared
/// building block for the favourite swatches, the favourite picker and the
/// style sheet's colour grid.
class _ColorDot extends StatelessWidget {
  final int color;
  final double size;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _ColorDot({
    required this.color,
    required this.size,
    required this.selected,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color(color),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.black26,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

/// The three persisted favourite colours. Tapping a swatch sets it as the
/// active drawing colour; long-pressing opens a picker to reassign that slot
/// (and applies the new colour too). The active swatch wears a ring.
class _FavoriteSwatches extends ConsumerWidget {
  const _FavoriteSwatches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteColorsProvider);
    final activeColor = ref.watch(editorToolProvider.select((s) => s.color));
    final toolCtl = ref.read(editorToolProvider.notifier);
    final favCtl = ref.read(favoriteColorsProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < favorites.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Tooltip(
              message: 'Tap to use · long-press to change',
              child: _ColorDot(
                color: favorites[i],
                size: 26,
                selected: activeColor == favorites[i],
                onTap: () => toolCtl.setColor(favorites[i]),
                onLongPress: () async {
                  final picked =
                      await _pickFavoriteColor(context, favorites[i]);
                  if (picked == null) return;
                  favCtl.setColor(i, picked);
                  toolCtl.setColor(picked);
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Picks a colour from [kFavoritePickerColors] for a favourite slot, or null on
/// cancel. Shared by the toolbar (reassigning a favourite) and could serve any
/// "pick a preset colour" need.
Future<int?> _pickFavoriteColor(BuildContext context, int current) {
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Favourite colour'),
      content: SizedBox(
        width: 300,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in kFavoritePickerColors)
              _ColorDot(
                color: c,
                size: 40,
                selected: c == current,
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

/// Undo / redo, relocated out of the app bar into the toolbar. Its own widget
/// so only it — not the whole bar — rebuilds as the history depth changes.
class _UndoRedoButtons extends ConsumerWidget {
  final ScenePageKey pageKey;
  const _UndoRedoButtons({required this.pageKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider(pageKey));
    final ctl = ref.read(historyProvider(pageKey).notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Undo',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.undo),
          onPressed: history.canUndo ? ctl.undo : null,
        ),
        IconButton(
          tooltip: 'Redo',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.redo),
          onPressed: history.canRedo ? ctl.redo : null,
        ),
      ],
    );
  }
}

class _SelectionBar extends ConsumerWidget {
  final ScenePageKey pageKey;
  const _SelectionBar({required this.pageKey});

  List<SceneElement> _sel(WidgetRef ref) => editorSelection(ref, pageKey);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.read(historyProvider(pageKey).notifier);
    final sel = ref.read(selectionProvider.notifier);
    final ids = ref.read(selectionProvider);
    final all = ref.read(sceneControllerProvider(pageKey));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              history.push(RemoveElementsCommand(_sel(ref)));
              sel.clear();
            },
          ),
          IconButton(
            tooltip: 'Duplicate',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () {
              final copies = SelectionEditing.duplicate(_sel(ref),
                  offset: const Offset(16, 16), nextId: editorNewId);
              history.push(AddElementsCommand(copies));
              sel.selectMany(copies.map((e) => e.id));
            },
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.content_copy),
            onPressed: () => ClipboardService.copy(_sel(ref)),
          ),
          // Only offered for a single text element: editing is inherently about
          // one element's words, and a locked one is not up for changing.
          if (_editableText(ids, all) case final TextElement t)
            IconButton(
              tooltip: 'Edit text',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editText(context, ref, t),
            ),
          // Turns an imported page or photo into editable text sitting over it.
          if (_singleImage(ids, all) case final ImageElement im)
            IconButton(
              tooltip: 'Extract text',
              icon: const Icon(Icons.document_scanner_outlined),
              onPressed: () => _extractText(context, ref, im),
            ),
          IconButton(
            tooltip: 'Save to library',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () => _saveToLibrary(context, ref),
          ),
          IconButton(
            tooltip: 'Group',
            icon: const Icon(Icons.join_full),
            onPressed: () {
              final before = _sel(ref);
              final gid = editorNewId();
              history.push(UpdateElementsCommand(
                before: before,
                after: [
                  for (final e in before) SelectionEditing.withGroup(e, gid)
                ],
              ));
            },
          ),
          IconButton(
            tooltip: 'Ungroup',
            icon: const Icon(Icons.join_inner),
            onPressed: () {
              final before = _sel(ref);
              history.push(UpdateElementsCommand(
                before: before,
                after: [
                  for (final e in before) SelectionEditing.withGroup(e, '')
                ],
              ));
            },
          ),
          Builder(builder: (context) {
            final before = _sel(ref);
            // If everything selected is already locked, this un-locks; any
            // unlocked element in the mix locks the whole selection. Selection
            // is kept (not cleared) either way — clearing it after locking is
            // what made a locked import unreachable in the first place, since
            // nothing else can re-select a locked element except tapping it.
            final allLocked = before.isNotEmpty && before.every((e) => e.isLocked);
            return IconButton(
              tooltip: allLocked ? 'Unlock' : 'Lock',
              icon: Icon(allLocked ? Icons.lock_open_outlined : Icons.lock_outline),
              onPressed: () {
                history.push(UpdateElementsCommand(
                  before: before,
                  after: [
                    for (final e in before)
                      SelectionEditing.withLocked(e, !allLocked)
                  ],
                ));
              },
            );
          }),
          const VerticalDivider(width: 12),
          IconButton(
            tooltip: 'Bring to front',
            icon: const Icon(Icons.flip_to_front),
            onPressed: () => history.push(ReplaceAllCommand(
                before: all, after: ZOrderService.bringToFront(all, ids))),
          ),
          IconButton(
            tooltip: 'Send to back',
            icon: const Icon(Icons.flip_to_back),
            onPressed: () => history.push(ReplaceAllCommand(
                before: all, after: ZOrderService.sendToBack(all, ids))),
          ),
          const VerticalDivider(width: 12),
          IconButton(
            tooltip: 'Align left',
            icon: const Icon(Icons.align_horizontal_left),
            onPressed: () => _align(ref, history, AlignEdge.left),
          ),
          IconButton(
            tooltip: 'Align centre',
            icon: const Icon(Icons.align_horizontal_center),
            onPressed: () => _align(ref, history, AlignEdge.centerH),
          ),
          IconButton(
            tooltip: 'Align top',
            icon: const Icon(Icons.align_vertical_top),
            onPressed: () => _align(ref, history, AlignEdge.top),
          ),
          IconButton(
            tooltip: 'Distribute horizontally',
            icon: const Icon(Icons.horizontal_distribute),
            onPressed: () {
              final before = _sel(ref);
              history.push(UpdateElementsCommand(
                before: before,
                after:
                    AlignmentService.distribute(before, SceneAxis.horizontal),
              ));
            },
          ),
        ],
      ),
    );
  }

  void _align(WidgetRef ref, HistoryController history, AlignEdge edge) {
    final before = _sel(ref);
    history.push(UpdateElementsCommand(
      before: before,
      after: AlignmentService.align(before, edge),
    ));
  }

  /// The single unlocked [TextElement] in the selection, or null when the
  /// selection is anything else.
  static TextElement? _editableText(
      Set<String> ids, List<SceneElement> all) {
    if (ids.length != 1) return null;
    final e = all.where((e) => e.id == ids.first).firstOrNull;
    return e is TextElement && !e.isLocked ? e : null;
  }

  /// Width of one extracted line drawn at [fontSize], in the same font a
  /// [TextElement] defaults to — so the size chosen for a line is the size it
  /// actually renders at, not an average-character guess.
  static double _measureExtractedLine(String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontFamily: 'Roboto'),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  /// The single [ImageElement] in the selection that has a file behind it, or
  /// null when the selection is anything else. Locked is fine — a page-sized
  /// import is locked by default, and reading it changes nothing about it.
  static ImageElement? _singleImage(Set<String> ids, List<SceneElement> all) {
    if (ids.length != 1) return null;
    final e = all.where((e) => e.id == ids.first).firstOrNull;
    return e is ImageElement && e.relativeImagePath.isNotEmpty ? e : null;
  }

  /// Reads the text out of [im] and lays it over the picture as ordinary,
  /// editable text elements.
  ///
  /// Everything lands in one [AddElementsCommand], so a single undo takes the
  /// whole extraction back. The picture is deliberately left in place — OCR
  /// misreads are only checkable against the original, and a page's diagrams
  /// aren't text — with removing it offered as a follow-up for anyone who wants
  /// text alone.
  Future<void> _extractText(
      BuildContext context, WidgetRef ref, ImageElement im) async {
    final messenger = ScaffoldMessenger.of(context);
    final absolute = SceneImageCache.resolvePath(
        ref.read(sceneImageCacheProvider).baseDir, im.relativeImagePath);

    // The same app-wide recogniser the AI pipeline reads pages with, so an
    // image OCR'd for one is already cached for the other.
    final List<RecognizedLine> boxes;
    try {
      boxes =
          await ref.read(imageTextRecognitionServiceProvider).lines(absolute);
    } on TextExtractionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    // OCR is slow enough that the user can leave the page mid-run; `ref` must
    // not be touched once this widget is gone.
    if (!context.mounted) return;

    // The recogniser reports boxes in the source image's pixel space, so the
    // picture's own pixel size is what they map from — read from the decoded
    // bitmap, which the cache already holds to draw it.
    final bitmap = ref.read(sceneImageCacheProvider).get(im.relativeImagePath);
    if (bitmap == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('That picture is still loading — try again.')));
      return;
    }

    final placed = layOutOcrBoxes(
      boxes: boxes,
      sourcePixels:
          Size(bitmap.width.toDouble(), bitmap.height.toDouble()),
      target: ElementBounds.of(im),
      measureWidth: _measureExtractedLine,
    );
    if (placed.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No text found in that picture.')));
      return;
    }

    final scene = ref.read(sceneControllerProvider(pageKey).notifier);
    var z = scene.nextZOrder();
    final added = [
      for (final p in placed)
        TextElement(
          id: editorNewId(),
          zOrder: z++,
          geometryData: [
            p.bounds.left,
            p.bounds.top,
            p.bounds.right,
            p.bounds.bottom
          ],
          text: p.text,
          color: 0xFF1A1A1A,
          fontSize: p.fontSize,
        ),
    ];
    ref.read(historyProvider(pageKey).notifier).push(AddElementsCommand(added));

    messenger.showSnackBar(SnackBar(
      content: Text('Extracted ${added.length} line'
          '${added.length == 1 ? '' : 's'} of text'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Remove picture',
        onPressed: () => ref
            .read(historyProvider(pageKey).notifier)
            .push(RemoveElementsCommand([im])),
      ),
    ));
  }

  /// Rewrites [t]'s words in place, keeping everything else about it — position,
  /// width, colour, font — exactly as the user left it.
  ///
  /// Only the height is recomputed, from the paragraph the painter will actually
  /// draw: text is wrapped to the element's width but never clipped vertically,
  /// so replacing a line with a paragraph would otherwise leave the bounds
  /// reporting a box far smaller than the visible text — which is what
  /// selection, hit-testing and AI note placement all read.
  Future<void> _editText(
      BuildContext context, WidgetRef ref, TextElement t) async {
    final text = await showSceneTextDialog(
      context,
      initial: t.text,
      title: 'Edit text',
      confirmLabel: 'Save',
    );
    // Null is cancel. Empty is a deliberate clear, but an empty text element is
    // invisible and unselectable — a trap — so treat it as "delete the text"
    // being unavailable here and leave the element alone.
    if (text == null || text.trim().isEmpty || text == t.text) return;

    final rect = ElementBounds.of(t);
    final updated = t.copyWith(text: text.trim());
    final height = SceneElementPainter.layOutText(updated, rect.width).height;
    if (!context.mounted) return;

    ref.read(historyProvider(pageKey).notifier).push(UpdateElementsCommand(
          before: [t],
          after: [
            updated.copyWith(geometryData: [
              rect.left,
              rect.top,
              rect.right,
              rect.top + math.max(height, t.fontSize),
            ]),
          ],
        ));
  }

  Future<void> _saveToLibrary(BuildContext context, WidgetRef ref) async {
    final selected = _sel(ref);
    if (selected.isEmpty) return;
    final name = await _promptName(context);
    if (name == null) return;
    await ref
        .read(libraryProvider.notifier)
        .addFromElements(name, selected, id: editorNewId());
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved "$name" to library')));
    }
  }

  Future<String?> _promptName(BuildContext context) {
    final controller = TextEditingController();
    String? clean(String v) => v.trim().isEmpty ? null : v.trim();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save to library'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Item name'),
          onSubmitted: (v) => Navigator.of(context).pop(clean(v)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(clean(controller.text)),
              child: const Text('Save')),
        ],
      ),
    );
  }
}

/// Lists saved library items; returns the chosen one to the caller (which
/// performs the insert in its own provider scope).
class EditorLibrarySheet extends ConsumerWidget {
  const EditorLibrarySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No saved items yet.\nSelect elements, then "Save to library".',
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              shrinkWrap: true,
              children: [
                for (final item in items)
                  ListTile(
                    leading: const Icon(Icons.dashboard_customize_outlined),
                    title: Text(item.name),
                    subtitle: Text('${item.elements.length} element(s)'),
                    onTap: () => Navigator.of(context).pop(item),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          ref.read(libraryProvider.notifier).remove(item.id),
                    ),
                  ),
              ],
            ),
    );
  }
}

class EditorStyleSheet extends ConsumerWidget {
  const EditorStyleSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(editorToolProvider);
    final c = ref.read(editorToolProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: ListView(
        shrinkWrap: true,
        children: [
          // Colour + stroke size moved here when the toolbar switched to three
          // favourite swatches, so the full spread and the size control stay a
          // tap away without cluttering the bar.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Colour', style: Theme.of(context).textTheme.titleSmall),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final col in kEditorPalette)
                _ColorDot(
                  color: col,
                  size: 32,
                  selected: tool.color == col,
                  onTap: () => c.setColor(col),
                ),
            ],
          ),
          _slider('Size', tool.size.clamp(1, 24), 1, 24, c.setSize),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pixel eraser (vs element eraser)'),
            value: tool.eraserPixel,
            onChanged: c.setEraserPixel,
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fill'),
            value: tool.hasFill,
            onChanged: c.setHasFill,
          ),
          _row(
              'Fill style',
              SegmentedButton<FillStyle>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: FillStyle.hachure, label: Text('Hachure')),
                  ButtonSegment(
                      value: FillStyle.crossHatch, label: Text('Cross')),
                  ButtonSegment(value: FillStyle.solid, label: Text('Solid')),
                ],
                selected: {tool.fillStyle},
                onSelectionChanged: (s) => c.setFillStyle(s.first),
              )),
          _row(
              'Stroke style',
              SegmentedButton<StrokeStyle>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: StrokeStyle.solid, label: Text('Solid')),
                  ButtonSegment(
                      value: StrokeStyle.dashed, label: Text('Dashed')),
                  ButtonSegment(
                      value: StrokeStyle.dotted, label: Text('Dotted')),
                ],
                selected: {tool.strokeStyle},
                onSelectionChanged: (s) => c.setStrokeStyle(s.first),
              )),
          _row(
              'Edges',
              SegmentedButton<EdgeStyle>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: EdgeStyle.sharp, label: Text('Sharp')),
                  ButtonSegment(value: EdgeStyle.round, label: Text('Round')),
                ],
                selected: {tool.edges},
                onSelectionChanged: (s) => c.setEdges(s.first),
              )),
          _row(
              'Arrowhead',
              SegmentedButton<Arrowhead>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: Arrowhead.none, label: Text('None')),
                  ButtonSegment(value: Arrowhead.triangle, label: Text('Tri')),
                  ButtonSegment(value: Arrowhead.dot, label: Text('Dot')),
                  ButtonSegment(value: Arrowhead.bar, label: Text('Bar')),
                ],
                selected: {tool.endArrowhead},
                onSelectionChanged: (s) => c.setEndArrowhead(s.first),
              )),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Elbow arrow'),
            value: tool.elbowed,
            onChanged: c.setElbowed,
          ),
          _slider('Roughness', tool.roughness, 0, 3, c.setRoughness),
          _slider('Opacity', tool.opacity, 0.1, 1, c.setOpacity),
        ],
      ),
    );
  }

  Widget _row(String label, Widget child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Flexible(
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal, child: child)),
          ],
        ),
      );

  Widget _slider(String label, double value, double min, double max,
          ValueChanged<double> onChanged) =>
      Row(
        children: [
          SizedBox(width: 80, child: Text(label)),
          Expanded(
            child: Slider(
              min: min,
              max: max,
              value: value.clamp(min, max),
              onChanged: onChanged,
            ),
          ),
        ],
      );
}
