// Full-width segmented control — the theme picker's control, and the shared one
// for any short exclusive choice that needs labels wide enough to read.
//
// Lives in `lib/widgets/` rather than beside the settings screen because the
// home and note-editor passes consume it too. Changing a token here lands on
// every screen at once instead of in three near-identical copies.
//
// Every colour comes from `context.colors` (design/THEME_SPEC.md § Design
// tokens). There are no hardcoded values, and no colour is captured outside
// `build` — a theme switch has to repaint this live.
//
// ── The one asymmetry ─────────────────────────────────────────────────────
// The TRACK differs by brightness: `surface` in light, `surfaceSubtle` in dark.
// In light the control sits on a white card and needs to read as slightly
// raised; in dark a `surface` track would be invisible against the `surface`
// card behind it, so it steps down to the subtler fill instead. The SELECTED
// segment does not branch — `accentMuted` over `accent` in both modes.

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// One option in an [AppSegmentedControl].
@immutable
class AppSegment<T> {
  final T value;
  final String label;
  final IconData icon;

  const AppSegment({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class AppSegmentedControl<T> extends StatelessWidget {
  final T value;
  final List<AppSegment<T>> segments;
  final ValueChanged<T> onChanged;

  const AppSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        // THEME_SPEC.md § asymmetries — "Segmented control — track".
        color: isDark ? c.surfaceSubtle : c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0)
              // Hairline between cells. A VerticalDivider would need an
              // intrinsic height here; a 1px box is simpler and exact.
              SizedBox(
                width: 1,
                height: 40,
                child: ColoredBox(color: c.border),
              ),
            Expanded(
              child: _Segment<T>(
                segment: segments[i],
                selected: segments[i].value == value,
                onTap: () => onChanged(segments[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  final AppSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Selected and unselected are the same pair in both brightnesses — the
    // accent and the tokens behind it already differ by mode, so branching here
    // would double-apply the difference.
    final foreground = selected ? c.accent : c.textSecondary;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 40,
        // The unselected fill is the SAME token at zero alpha rather than a
        // Material transparent constant, for two reasons: it keeps this file
        // free of hardcoded colours, and it gives AnimatedContainer a straight
        // alpha fade between the two states instead of a colour-to-null jump.
        color: selected ? c.accentMuted : c.accentMuted.withValues(alpha: 0),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(segment.icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                segment.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
