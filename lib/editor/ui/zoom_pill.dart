// The zoom-level pill that floats at the bottom-right of the canvas. Shows the
// current zoom as a percentage and, on tap, resets the view (100% / recentre)
// via the viewport controller. Its own widget so only it rebuilds as the zoom
// changes, and so the behaviour is testable without the whole editor.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/viewport_controller.dart';

class ZoomPill extends ConsumerWidget {
  const ZoomPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(viewportProvider.select((v) => v.zoom));
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Reset view',
      child: Material(
        color: scheme.surface.withValues(alpha: 0.92),
        elevation: 2,
        shape: StadiumBorder(
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => ref.read(viewportProvider.notifier).reset(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              '${(zoom * 100).round()}%',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
