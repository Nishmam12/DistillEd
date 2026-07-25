// Shared editor chrome for the unified canvas — the bottom tool/style bar (with
// its per-tool sliding options panels), the selection action bar, the app-bar
// actions (undo/redo + overflow menu), and the library bottom sheet.
// Parameterised by [ScenePageKey] so the dev playground and the real notebook
// editor drive the same controls over their own page (and their own provider
// scope / store).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
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
import '../state/history_controller.dart';
import '../state/library_controller.dart';
import '../state/scene_controller.dart';
import '../state/scene_image_cache_provider.dart';
import '../state/selection_controller.dart';
import '../state/viewport_controller.dart';
import 'text_input_dialog.dart';

// The primary drawing tools, in the order they sit in the toolbar. Frame and
// hand stay in [EditorTool] (the canvas still handles them, and two-finger pan
// covers hand) but are kept off this row to match the pared-back design; image
// import rides at the end as an action, not a tool (see [EditorBottomBar]).
const List<(EditorTool, IconData)> kEditorTools = [
  (EditorTool.select, Icons.near_me_outlined),
  (EditorTool.pen, Icons.edit),
  (EditorTool.shape, Icons.category),
  (EditorTool.eraser, Icons.cleaning_services_outlined),
  (EditorTool.text, Icons.title),
  (EditorTool.laser, Icons.flashlight_on_outlined),
];

// Line and arrow are deliberately not chips here — they're reachable as their
// own Arrow tool in the main tool row instead (see [_ArrowToolButton]), right
// next to the general shape tool rather than buried in this picker.
const List<(ShapeType, IconData)> kEditorShapes = [
  (ShapeType.rectangle, Icons.crop_square),
  (ShapeType.circle, Icons.circle_outlined),
  (ShapeType.diamond, Icons.diamond_outlined),
  (ShapeType.triangle, Icons.change_history),
];

// No font assets are bundled with the app, so these are generic family names
// resolved by each platform's own font matching rather than guaranteed custom
// typefaces — real visual variety depends on what's installed on the device.
const List<String> kFontFamilies = ['Roboto', 'Serif', 'Monospace', 'Cursive'];

const Map<Arrowhead, IconData> kArrowheadIcons = {
  Arrowhead.none: Icons.remove,
  Arrowhead.triangle: Icons.arrow_right_alt,
  Arrowhead.dot: Icons.fiber_manual_record,
  Arrowhead.bar: Icons.border_vertical,
};

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
                      for (final (t, icon) in kEditorTools) ...[
                        _ToolIconButton(
                          tool: t,
                          icon: icon,
                          state: tool,
                          onTap: () => toolCtl.setTool(t),
                        ),
                        // The arrow tool rides right beside the general shape
                        // tool it's a variant of, rather than off at the end
                        // near Import.
                        if (t == EditorTool.shape) _ArrowToolButton(state: tool),
                      ],
                      // Image import is an action, not a selectable tool, so
                      // it sits at the very end of the row.
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
              _UndoRedoButtons(pageKey: pageKey),
            ],
          ),
        ],
      ),
    );
  }
}

/// Floating, temporary options panel for whichever tool is active
/// (pen/eraser/shape/text) — a squircle card that slides down and fades in
/// the moment its tool is (re-)selected, then slides back up out of the way
/// the instant the user starts actually using it on the page (see
/// [EditorToolController.closePanel], called from the canvas on the first
/// touch of a stroke/shape/erase gesture). Tools with no options of their own
/// (select/laser/hand/frame) render nothing.
///
/// Deliberately *not* part of [EditorBottomBar]'s own layout: callers place it
/// as an overlay in a [Stack] above the canvas instead, so opening or closing
/// it never resizes — and so never visibly shifts — the canvas underneath a
/// page the user may be mid-stroke on.
class EditorToolOptionsOverlay extends ConsumerWidget {
  /// Which edge of the [Stack] the panel is anchored to, so it slides away
  /// *towards* its trigger rather than through the middle of the canvas: the
  /// real editor docks its toolbar above the canvas (anchor the panel to the
  /// top, slide up to hide — the default); the dev playground docks it below
  /// (anchor to the bottom, slide down to hide instead).
  final bool anchorBottom;

  const EditorToolOptionsOverlay({super.key, this.anchorBottom = false});

  /// Fixed rather than filling available width — a compact floating card
  /// (matching the platform's own dropdown menus), not an edge-to-edge bar.
  static const double _panelWidth = 340.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorToolProvider);
    final ctl = ref.read(editorToolProvider.notifier);

    final Widget? content = switch (state.tool) {
      EditorTool.pen => _PenPanel(state: state, ctl: ctl),
      EditorTool.eraser => _EraserPanel(state: state, ctl: ctl),
      EditorTool.shape => _ShapePanel(state: state, ctl: ctl),
      EditorTool.text => _TextPanel(state: state, ctl: ctl),
      _ => null,
    };
    if (content == null) return const SizedBox.shrink();

    final open = state.panelOpen;
    final closedOffset = Offset(0, anchorBottom ? 1.2 : -1.2);
    return IgnorePointer(
      key: const ValueKey('editorToolOptionsIgnorePointer'),
      // Hidden means visually gone *and* untouchable — otherwise a closed
      // panel would still steal the first tap meant for the canvas beneath it.
      ignoring: !open,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: open ? Curves.easeOutCubic : Curves.easeInCubic,
        offset: open ? Offset.zero : closedOffset,
        child: AnimatedOpacity(
          duration: Duration(milliseconds: open ? 200 : 150),
          opacity: open ? 1 : 0,
          child: Container(
            key: const ValueKey('editorToolOptionsPanelSurface'),
            width: _panelWidth,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: ShapeDecoration(
              color: AppColors.surface,
              shadows: AppColors.shadowFloat,
              // A "squircle" (Apple's continuous-corner rectangle) rather
              // than an ordinary rounded rect, matching the platform's own
              // floating dropdown menus.
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// A labelled slider row shared by every tool panel — an icon, the slider
/// itself, and a compact readout of the current value.
class _PanelSlider extends StatelessWidget {
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double) label;

  const _PanelSlider({
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon, size: 18),
        ),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 36, child: Text(label(value), textAlign: TextAlign.end)),
      ],
    );
  }
}

/// A leading-icon row whose control scrolls horizontally if it doesn't fit —
/// shared by the panel rows built from a [SegmentedButton].
Widget _panelRow(IconData icon, Widget control) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon, size: 18),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: control,
          ),
        ),
      ],
    ),
  );
}

String _percentLabel(double v) => '${(v * 100).round()}%';
String _roundedLabel(double v) => v.round().toString();

/// Pen options: a reserved slot for future brush types (only "Pen" exists
/// today), thickness and opacity.
class _PenPanel extends StatelessWidget {
  final EditorToolState state;
  final EditorToolController ctl;
  const _PenPanel({required this.state, required this.ctl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: ChoiceChip(
            showCheckmark: false,
            label: const Icon(Icons.brush, size: 18),
            tooltip: 'Pen',
            selected: true,
            onSelected: (_) {},
          ),
        ),
        _PanelSlider(
          icon: Icons.line_weight,
          value: state.size,
          min: 1,
          max: 24,
          onChanged: ctl.setSize,
          label: _roundedLabel,
        ),
        _PanelSlider(
          icon: Icons.opacity,
          value: state.opacity,
          min: 0.1,
          max: 1,
          onChanged: ctl.setOpacity,
          label: _percentLabel,
        ),
      ],
    );
  }
}

/// Eraser options: explicit pixel/stroke mode chips and thickness. Mode used
/// to also be toggled by re-tapping the active eraser icon; that shortcut is
/// gone now that this panel gives it an explicit control.
class _EraserPanel extends StatelessWidget {
  final EditorToolState state;
  final EditorToolController ctl;
  const _EraserPanel({required this.state, required this.ctl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        // Wraps rather than a fixed Row: the panel is now a compact
        // fixed-width floating card, narrower than the old full-width inline
        // bar these chips were sized for, so a two-line wrap on narrow
        // widths beats either overflowing or hiding a chip off-screen.
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              showCheckmark: false,
              label: const Text('Pixel eraser'),
              selected: state.eraserPixel,
              onSelected: (_) => ctl.setEraserPixel(true),
            ),
            ChoiceChip(
              showCheckmark: false,
              label: const Text('Stroke eraser'),
              selected: !state.eraserPixel,
              onSelected: (_) => ctl.setEraserPixel(false),
            ),
          ],
        ),
        _PanelSlider(
          icon: Icons.line_weight,
          value: state.size,
          min: 1,
          max: 24,
          onChanged: ctl.setSize,
          label: _roundedLabel,
        ),
      ],
    );
  }
}

/// Shape options: the shape-type picker (moved in from its old standalone
/// row), thickness, opacity, and the stroke/edge/fill styling (moved in from
/// the pen panel — dashed/dotted strokes and rounded corners are a shapes
/// concept, not something a freehand pen stroke renders). Colour lives in the
/// one universal palette (top-right of the canvas) rather than a swatch row
/// of its own.
class _ShapePanel extends StatelessWidget {
  final EditorToolState state;
  final EditorToolController ctl;
  const _ShapePanel({required this.state, required this.ctl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          children: [
            for (final (type, icon) in kEditorShapes)
              ChoiceChip(
                showCheckmark: false,
                label: Icon(icon, size: 18),
                selected: state.shapeType == type,
                onSelected: (_) => ctl.setShapeType(type),
              ),
          ],
        ),
        _PanelSlider(
          icon: Icons.line_weight,
          value: state.size,
          min: 1,
          max: 24,
          onChanged: ctl.setSize,
          label: _roundedLabel,
        ),
        _PanelSlider(
          icon: Icons.opacity,
          value: state.opacity,
          min: 0.1,
          max: 1,
          onChanged: ctl.setOpacity,
          label: _percentLabel,
        ),
        _panelRow(
          Icons.line_style,
          SegmentedButton<StrokeStyle>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: StrokeStyle.solid, label: Text('Solid')),
              ButtonSegment(value: StrokeStyle.dashed, label: Text('Dashed')),
              ButtonSegment(value: StrokeStyle.dotted, label: Text('Dotted')),
            ],
            selected: {state.strokeStyle},
            onSelectionChanged: (s) => ctl.setStrokeStyle(s.first),
          ),
        ),
        _panelRow(
          Icons.rounded_corner,
          SegmentedButton<EdgeStyle>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: EdgeStyle.sharp, label: Text('Sharp')),
              ButtonSegment(value: EdgeStyle.round, label: Text('Round')),
            ],
            selected: {state.edges},
            onSelectionChanged: (s) => ctl.setEdges(s.first),
          ),
        ),
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.format_color_fill, size: 18),
            ),
            const Spacer(),
            Switch(value: state.hasFill, onChanged: ctl.setHasFill),
          ],
        ),
        if (state.hasFill)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            // Compact style (shrunk padding/font/tap target) rather than the
            // default segmented-button size — at default size "Hachure" /
            // "Cross" / "Solid" together ran past the edge of this (now
            // fixed-width) floating panel; shrinking the pill itself, not
            // just giving it its own row, is what actually keeps it inside
            // the panel's own rounded boundary instead of overflowing or
            // relying on a hidden horizontal scroll. The scroll view is a
            // safety net only — under normal text scaling it never needs to
            // scroll.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<FillStyle>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  textStyle: const TextStyle(fontSize: 11),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(
                      value: FillStyle.hachure, label: Text('Hachure')),
                  ButtonSegment(
                      value: FillStyle.crossHatch, label: Text('Cross')),
                  ButtonSegment(value: FillStyle.solid, label: Text('Solid')),
                ],
                selected: {state.fillStyle},
                onSelectionChanged: (s) => ctl.setFillStyle(s.first),
              ),
            ),
          ),
      ],
    );
  }
}

/// Text options: font family and font size, replacing the old sheet's single
/// shared font-size slider with a panel of its own.
class _TextPanel extends StatelessWidget {
  final EditorToolState state;
  final EditorToolController ctl;
  const _TextPanel({required this.state, required this.ctl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.font_download_outlined, size: 18),
            ),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: state.fontFamily,
                items: [
                  for (final f in kFontFamilies)
                    DropdownMenuItem(
                      value: f,
                      child: Text(f, style: TextStyle(fontFamily: f)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) ctl.setFontFamily(v);
                },
              ),
            ),
          ],
        ),
        _PanelSlider(
          icon: Icons.format_size,
          value: state.fontSize,
          min: 10,
          max: 72,
          onChanged: ctl.setFontSize,
          label: _roundedLabel,
        ),
      ],
    );
  }
}

/// The arrow/line tool — a first-class tool of its own, sitting right beside
/// the general Shape tool it's a variant of. Tapping it draws with
/// [ShapeType.arrow] straight away (set the arrowhead style to "none" for a
/// plain line); long-press opens a small popup to set the arrowhead marker
/// style and elbow (right-angle) routing, which apply to *any* arrow drawn
/// after that, not just the next one.
class _ArrowToolButton extends ConsumerWidget {
  final EditorToolState state;
  const _ArrowToolButton({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.read(editorToolProvider.notifier);
    final isActive =
        state.tool == EditorTool.shape && state.shapeType == ShapeType.arrow;

    return Tooltip(
      message: 'Arrow · long-press for arrowhead style',
      child: GestureDetector(
        onLongPressStart: (details) =>
            _openStyleMenu(context, ref, details.globalPosition),
        child: IconButton(
          isSelected: isActive,
          onPressed: ctl.selectArrowTool,
          icon:
              Icon(kArrowheadIcons[state.endArrowhead] ?? Icons.arrow_right_alt),
          style: IconButton.styleFrom(
            backgroundColor:
                isActive ? Theme.of(context).colorScheme.primaryContainer : null,
          ),
        ),
      ),
    );
  }

  Future<void> _openStyleMenu(
      BuildContext context, WidgetRef ref, Offset position) async {
    final ctl = ref.read(editorToolProvider.notifier);
    await showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem<void>(
          child: StatefulBuilder(
            builder: (context, setMenuState) {
              final live = ref.read(editorToolProvider);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final a in Arrowhead.values)
                        ChoiceChip(
                          showCheckmark: false,
                          label: Icon(kArrowheadIcons[a] ?? Icons.arrow_right_alt,
                              size: 18),
                          selected: live.endArrowhead == a,
                          onSelected: (_) {
                            ctl.setEndArrowhead(a);
                            setMenuState(() {});
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Elbow arrow'),
                      Switch(
                        value: live.elbowed,
                        onChanged: (v) {
                          ctl.setElbowed(v);
                          setMenuState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single tool button in the bottom bar. For the eraser it shows a distinct
/// icon per mode (stroke/element vs pixel) so the current mode is visible —
/// that mode is chosen in the eraser's options panel, not by tapping this
/// button, which always just selects the tool.
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
        ? (state.eraserPixel ? 'Pixel eraser' : 'Stroke eraser')
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

