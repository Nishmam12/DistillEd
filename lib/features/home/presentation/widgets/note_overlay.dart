// The frosted-glass panel that sits on top of the left edge of a note card.
//
// It is not a card of its own: only the outer (left) corners are rounded, the
// edge meeting the preview is perfectly straight, and it casts a soft shadow
// sideways onto the preview so the glass reads as a layer above it.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/ink_colors.dart';
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: context.notes.overlayShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: NotesPalette.overlayBlurSigma,
            sigmaY: NotesPalette.overlayBlurSigma,
          ),
          child: Container(
            color: Colors.white.withValues(alpha: 0.58),
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (note.pinned) ...[
                  Icon(
                    Icons.push_pin_rounded,
                    size: 16,
                    color: context.notes.textSecondary,
                  ),
                  const SizedBox(height: 8),
                ],
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
                      color: context.notes.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _MetaRow(icon: Icons.event_rounded, label: note.dateLabel),
                const SizedBox(height: 6),
                _MetaRow(
                  icon: Icons.description_outlined,
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
    return Row(
      children: [
        Icon(icon, size: 15, color: context.notes.textSecondary),
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
              color: context.notes.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
