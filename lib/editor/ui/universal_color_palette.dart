// The single, universal colour control for the whole editor — floats at the
// top-right of the canvas. Pen strokes, shape outlines AND shape fills all
// read from the one shared `EditorToolState.color` (see
// [EditorToolController.setColor], which keeps `fillColor` in lock-step), so
// changing the colour here changes it everywhere at once rather than hunting
// for a picker inside each tool's own options panel.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../state/editor_tool_controller.dart';
import 'editor_controls.dart' show kFavoritePickerColors;

class UniversalColorPalette extends ConsumerStatefulWidget {
  const UniversalColorPalette({super.key});

  @override
  ConsumerState<UniversalColorPalette> createState() =>
      _UniversalColorPaletteState();
}

class _UniversalColorPaletteState extends ConsumerState<UniversalColorPalette> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(editorToolProvider.select((s) => s.color));
    final ctl = ref.read(editorToolProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Trigger(
          color: color,
          open: _open,
          onTap: () => setState(() => _open = !_open),
        ),
        IgnorePointer(
          key: const ValueKey('universalColorPaletteIgnorePointer'),
          ignoring: !_open,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: _open ? Curves.easeOutCubic : Curves.easeInCubic,
            offset: _open ? Offset.zero : const Offset(0, -1.1),
            child: AnimatedOpacity(
              duration: Duration(milliseconds: _open ? 180 : 140),
              opacity: _open ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  key: const ValueKey('universalColorPaletteSurface'),
                  constraints: const BoxConstraints(maxWidth: 176),
                  padding: const EdgeInsets.all(10),
                  decoration: ShapeDecoration(
                    color: AppColors.surface,
                    shadows: AppColors.shadowFloat,
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in kFavoritePickerColors)
                        _Swatch(
                          color: c,
                          selected: color == c,
                          onTap: () {
                            ctl.setColor(c);
                            setState(() => _open = false);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The always-visible trigger: a small pill showing the active colour, tap to
/// open/close the swatch grid below it.
class _Trigger extends StatelessWidget {
  final int color;
  final bool open;
  final VoidCallback onTap;

  const _Trigger({required this.color, required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Colour',
      child: Material(
        color: AppColors.surface,
        elevation: 2,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color(color),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular colour swatch in the palette grid.
class _Swatch extends StatelessWidget {
  final int color;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Color(color),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.black26,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
