// Pill chip group — an exclusive choice between two or three short labels
// (PNG/PDF, English/বাংলা), sized to sit in a settings row's trailing slot.
//
// Lives in `lib/widgets/` because the home and note-editor passes consume it
// too. Every colour comes from `context.colors` (design/THEME_SPEC.md), none is
// hardcoded, and none is captured outside `build`.
//
// ── The asymmetry, which is the whole point of this widget ────────────────
// THEME_SPEC.md § "Deliberate light/dark asymmetries" gives the SELECTED chip
// two different treatments:
//
//   LIGHT  filled `accent`, `onAccent` text, no border
//   DARK   transparent fill, 1px `accent` border, `accent` text
//
// Do not unify these. A filled gold chip in dark mode is a solid block of the
// most saturated colour in the palette sitting inside a settings row — it
// outshouts the row title next to it and reads as a warning, not a selection.
// Outlining it keeps the gold as a signal while leaving the row's hierarchy
// intact. In light, navy is calm enough to fill without that problem, and a
// filled chip is the stronger, more obvious affordance.
//
// The UNSELECTED chip does NOT branch: transparent with a `border` outline and
// `textSecondary` text in both modes. The tokens behind those already differ by
// brightness, so branching here would double-apply the difference.

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class AppChipGroup<T> extends StatelessWidget {
  final T value;

  /// `(value, label)` pairs, rendered left to right.
  final List<(T, String)> options;

  final ValueChanged<T> onChanged;

  const AppChipGroup({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (option, label) in options)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _Chip(
              label: label,
              selected: option == value,
              onTap: () => onChanged(option),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Both selected branches are spelled out rather than folded into one
    // expression with two ternaries, so a future edit cannot silently change
    // one mode while leaving the other behind.
    final Color fill;
    final Color outline;
    final Color text;
    if (!selected) {
      // Same treatment in both modes.
      fill = c.accent.withValues(alpha: 0); // transparent, token-derived
      outline = c.border;
      text = c.textSecondary;
    } else if (isDark) {
      fill = c.accent.withValues(alpha: 0);
      outline = c.accent;
      text = c.accent;
    } else {
      fill = c.accent;
      // No border in light — the fill is the affordance. Matching the fill
      // colour keeps the geometry identical across the two selected branches,
      // so the chip does not change size when the theme flips.
      outline = c.accent;
      text = c.onAccent;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: outline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: text,
          ),
        ),
      ),
    );
  }
}
