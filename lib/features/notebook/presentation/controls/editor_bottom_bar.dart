// The full bottom bar: selection actions + tools + style + palette + size.
//
// The tool/style bar. Docked directly under the app bar in the real editor
// (with a divider below it) and used as the bottom bar in the dev playground;
// callers wrap it in a [SafeArea] when it sits at a screen edge.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:margo/core/icons/phosphor_icons_regular.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../editor/ui/editor_constants.dart';
import '../../../../domain/model/scene_element.dart';
import '../../../../editor/state/editor_tool_controller.dart';
import '../../../../editor/state/pen_presets.dart';
import '../../../../editor/state/scene_controller.dart';
import '../../../../editor/state/selection_controller.dart';
import 'selection_bar.dart';

/// Below this width the tool row packs its buttons closer and shows a
/// scrollbar, so no tool is left half off the edge without a sign that the row
/// scrolls (the AI panel narrows the editor to about this).
const double kToolRowCompactWidth = 640;

class EditorBottomBar extends ConsumerStatefulWidget {
  final ScenePageKey pageKey;

  /// Opens the import sheet (photo / camera / PDF). When null — as in the dev
  /// playground, which has no notebook to import into — the import button is
  /// omitted from the tool row.
  final VoidCallback? onImport;

  /// Follows an element's link (selection bar's "Open link").
  final void Function(String link)? onOpenLink;

  const EditorBottomBar({
    super.key,
    required this.pageKey,
    this.onImport,
    this.onOpenLink,
  });

  @override
  ConsumerState<EditorBottomBar> createState() => _EditorBottomBarState();
}

class _EditorBottomBarState extends ConsumerState<EditorBottomBar> {
  final ScrollController _scroll = ScrollController();

  ScenePageKey get pageKey => widget.pageKey;
  VoidCallback? get onImport => widget.onImport;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tool = ref.watch(editorToolProvider);
    final selectedIds = ref.watch(selectionProvider);
    final toolCtl = ref.read(editorToolProvider.notifier);
    final fingerDraws =
        ref.watch(settingsProvider.select((s) => s.fingerDraws));

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedIds.isNotEmpty)
            SelectionBar(pageKey: pageKey, onOpenLink: widget.onOpenLink),
          Row(
            children: [
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final compact = box.maxWidth < kToolRowCompactWidth;
                  return Theme(
                    data: Theme.of(context).copyWith(
                      iconButtonTheme: IconButtonThemeData(
                        style: IconButton.styleFrom(
                          visualDensity: compact
                              ? VisualDensity.compact
                              : VisualDensity.standard,
                        ),
                      ),
                    ),
                    child: Scrollbar(
                      key: const ValueKey('toolRowScrollbar'),
                      controller: _scroll,
                      thumbVisibility: compact,
                      child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (t, icon) in kEditorTools) ...[
                        if (t == EditorTool.pen)
                          _PenToolButton(
                            state: tool,
                            onTap: () => toolCtl.setTool(t),
                          )
                        else
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
                        // Saved pens ride beside the pen they set up.
                        if (t == EditorTool.pen) _PenPresetsRow(state: tool),
                      ],
                      // One clear switch for "does a finger draw?". The same
                      // setting as Settings > Pen, so the two always agree.
                      IconButton(
                        key: const ValueKey('fingerDrawToggle'),
                        tooltip: fingerDraws
                            ? 'Finger draws. Tap so only the pen draws'
                            : 'Only the pen draws. Tap to draw with a finger',
                        isSelected: fingerDraws,
                        icon: Icon(fingerDraws
                            ? Icons.touch_app
                            : Icons.touch_app_outlined),
                        style: IconButton.styleFrom(
                          backgroundColor: fingerDraws
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                        ),
                        onPressed: () => ref
                            .read(settingsProvider.notifier)
                            .setFingerDraws(!fingerDraws),
                      ),
                      // Image import is an action, not a selectable tool, so
                      // it sits at the very end of the row.
                      if (onImport != null)
                        IconButton(
                          tooltip: 'Import image / PDF',
                          icon: const Icon(PhosphorIconsRegular.image),
                          onPressed: onImport,
                        ),
                    ],
                  ),
                ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
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
          icon: const Icon(PhosphorIconsRegular.arrowRight),
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

/// A single tool button in the bottom bar. The eraser keeps one glyph whatever
/// its mode (stroke/element vs pixel); the tooltip names the current mode. That
/// mode is chosen in the eraser's options panel, not by tapping this button,
/// which always just selects the tool.
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

    final tooltip = isEraser
        ? (state.eraserPixel ? 'Pixel eraser' : 'Stroke eraser')
        : null;

    return IconButton(
      tooltip: tooltip,
      isSelected: isActive,
      onPressed: onTap,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor:
            isActive ? Theme.of(context).colorScheme.primaryContainer : null,
      ),
    );
  }
}

/// The pen tool. Its glyph is the pen being drawn with (ballpoint, fountain,
/// pencil, highlighter), with a dot of its colour, so the button says what the
/// next stroke will look like. It used to be a fixed pencil, which read as the
/// Pencil type and made the saved pens beside it look like more tools.
class _PenToolButton extends StatelessWidget {
  final EditorToolState state;
  final VoidCallback onTap;

  const _PenToolButton({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = state.tool == EditorTool.pen;
    final (_, icon, name) = kPenKinds.firstWhere((k) => k.$1 == state.penKind);
    return IconButton(
      key: const ValueKey('penTool'),
      tooltip: '$name · tap again for options',
      isSelected: isActive,
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Color(state.color),
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
            ),
          ),
        ],
      ),
      style: IconButton.styleFrom(
        backgroundColor: isActive ? scheme.primaryContainer : null,
      ),
    );
  }
}

/// The saved pens, beside the pen tool: tap one to draw with it, long-press to
/// replace it with the pen in use or remove it, + to save the pen in use.
///
/// Grouped in their own rounded strip, as plain colour dots, so they read as
/// favourites of the pen tool and not as more tools.
class _PenPresetsRow extends ConsumerWidget {
  final EditorToolState state;
  const _PenPresetsRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(penPresetsProvider);
    final notifier = ref.read(penPresetsProvider.notifier);
    final current = PenStyle.of(state);
    final active = state.tool == EditorTool.pen;

    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('penPresets'),
      margin: const EdgeInsets.only(left: 2, right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < presets.length; i++)
          _PenPresetSwatch(
            key: ValueKey('penPreset-$i'),
            pen: presets[i],
            selected: active && presets[i] == current,
            onTap: () =>
                ref.read(editorToolProvider.notifier).usePen(presets[i]),
            onLongPress: (position) =>
                _openMenu(context, ref, i, position),
          ),
        if (notifier.canAdd && !presets.contains(current))
          IconButton(
            tooltip: 'Save this pen',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => notifier.add(current),
          ),
      ],
      ),
    );
  }

  Future<void> _openMenu(
      BuildContext context, WidgetRef ref, int index, Offset position) async {
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: const [
        PopupMenuItem(value: 'replace', child: Text('Replace with this pen')),
        PopupMenuItem(value: 'remove', child: Text('Remove')),
      ],
    );
    final notifier = ref.read(penPresetsProvider.notifier);
    switch (choice) {
      case 'replace':
        notifier.replace(index, PenStyle.of(ref.read(editorToolProvider)));
      case 'remove':
        notifier.removeAt(index);
    }
  }
}

/// One saved pen: a dot of its colour with a small badge of its type, ringed
/// when it is the pen in use.
class _PenPresetSwatch extends StatelessWidget {
  final PenStyle pen;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<Offset> onLongPress;

  const _PenPresetSwatch({
    super.key,
    required this.pen,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final (_, icon, name) = kPenKinds.firstWhere((k) => k.$1 == pen.kind);
    final scheme = Theme.of(context).colorScheme;
    final size = pen.size < 10
        ? pen.size.toStringAsFixed(1)
        : pen.size.round().toString();
    return Tooltip(
      message: '$name, size $size · long-press for options',
      child: GestureDetector(
        onLongPressStart: (d) => onLongPress(d.globalPosition),
        child: InkResponse(
          onTap: onTap,
          radius: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
            child: Container(
              // The ring sits outside the dot with a gap, so a dark pen's
              // selection still shows in dark mode.
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Color(pen.color),
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 9, color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

