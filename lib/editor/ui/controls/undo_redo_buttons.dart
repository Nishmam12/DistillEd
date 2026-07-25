// Undo / redo, relocated out of the app bar into the toolbar. Its own widget
// so only it — not the whole bar — rebuilds as the history depth changes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
