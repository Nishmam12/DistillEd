// The full bottom bar: selection actions + tools + style + palette + size.
//
// The tool/style bar. Docked directly under the app bar in the real editor
// (with a divider below it) and used as the bottom bar in the dev playground;
// callers wrap it in a [SafeArea] when it sits at a screen edge.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkflow/core/icons/phosphor_icons_regular.dart';

import '../../../core/constants/editor_constants.dart';
import '../../../domain/model/scene_element.dart';
import '../../state/editor_tool_controller.dart';
import '../../state/scene_controller.dart';
import '../../state/selection_controller.dart';
import 'selection_bar.dart';
import 'undo_redo_buttons.dart';

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
          if (selectedIds.isNotEmpty) SelectionBar(pageKey: pageKey),
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
                          icon: const Icon(PhosphorIconsRegular.image),
                          onPressed: onImport,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              UndoRedoButtons(pageKey: pageKey),
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
