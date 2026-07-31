// The frosted-glass panel that sits on top of the left edge of a note card.
//
// It is not a card of its own: only the outer (left) corners are rounded, the
// edge meeting the preview is perfectly straight, and it casts a soft shadow
// sideways onto the preview so the glass reads as a layer above it.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:inkflow/core/icons/phosphor_icons_regular.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/note_card_data.dart';
import '../notes_palette.dart';

class NoteOverlay extends StatelessWidget {
  const NoteOverlay({super.key, required this.note});

  final NoteCardData note;

  /// Rounded on the outer edge, square where it meets the preview.
  static const borderRadius = BorderRadius.horizontal(
    left: Radius.circular(NotesPalette.cardRadius),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        // Light only. The sideways shadow reads as the glass layer lifting off
        // the preview; in dark it would be a black smear on a near-black card,
        // and THEME_SPEC.md rules out carrying BoxShadow into dark regardless.
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(4, 0),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: NotesPalette.overlayBlurSigma,
            sigmaY: NotesPalette.overlayBlurSigma,
          ),
          child: Container(
            // Transparent, not a white wash. The readability gradient in
            // NotePreview already paints flat `surface` across this whole
            // width (HOME-17), so anything added here would only tint it — and
            // a fixed white wash was the one hardcoded colour on this card.
            color: c.surface.withValues(alpha: 0),
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (note.pinned) ...[
                  Icon(
                    PhosphorIconsRegular.pushPin,
                    size: 16,
                    color: c.accent,
                  ),
                  const SizedBox(height: 8),
                ],
                // HOME-08. `textPrimary`, NOT `accent`. The mockup shows a gold
                // title in dark; THEME_SPEC.md § "Color hierarchy" overrides it
                // — a list of thirty gold titles is a wall of accent colour in
                // which nothing reads as emphasized.
                Flexible(
                  child: Text(
                    note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // HOME-09.
                _MetaRow(
                  icon: PhosphorIconsRegular.calendarBlank,
                  label: note.dateLabel,
                ),
                const SizedBox(height: 6),
                _MetaRow(
                  icon: PhosphorIconsRegular.fileText,
                  label: note.pageLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // HOME-09. Icon accent, label secondary — the split is the point: the glyph
    // is single-instance chrome, the text is repeated meta.
    return Row(
      children: [
        Icon(icon, size: 15, color: c.accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: c.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
