// Undo / redo, beside the note title in the editor's top bar. Its own widget
// so only it — not the whole bar — rebuilds as the history depth changes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icon.dart';
import '../../../core/theme/app_colors.dart';
import '../../state/history_controller.dart';
import '../../state/scene_controller.dart';

class UndoRedoButtons extends ConsumerWidget {
  final ScenePageKey pageKey;
  const UndoRedoButtons({super.key, required this.pageKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider(pageKey));
    final ctl = ref.read(historyProvider(pageKey).notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HistoryButton(
          icon: AppIcons.undo,
          tooltip: 'Undo',
          onPressed: history.canUndo ? ctl.undo : null,
        ),
        const SizedBox(width: 6),
        _HistoryButton(
          icon: AppIcons.redo,
          tooltip: 'Redo',
          onPressed: history.canRedo ? ctl.redo : null,
        ),
      ],
    );
  }
}

/// One outlined, rounded history button. Colours per the Margo toolbar spec
/// (assets/Margo_Note_Toolbar/Redo_undo_color_scheme.txt): #292D32 when
/// available, #838484 when greyed out. Dark mode swaps the near-black for the
/// theme's text colour so it stays visible.
class _HistoryButton extends StatelessWidget {
  const _HistoryButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final String icon;
  final String tooltip;
  final VoidCallback? onPressed;

  static const _enabled = Color(0xFF292D32);
  static const _disabled = Color(0xFF838484);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = onPressed == null
        ? _disabled
        : (dark ? colors.textPrimary : _enabled);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 34),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: AppIcon(icon, size: 30, color: ink),
      ),
    );
  }
}
