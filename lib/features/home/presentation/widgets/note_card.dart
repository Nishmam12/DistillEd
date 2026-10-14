// One note in the Notes grid: a thumbnail over a white footer, both inside a
// single 20px-radius card (the margo design's 252×296 tile).
//
//   thumbnail  — NotePreview, fills the top
//   footer     — title, favourite toggle, "N Pages" and the creation date
//   graph      — the knowledge-graph button floats over the thumbnail corner
//
// Sized by whatever the grid hands it; the footer is a fixed 98px so the
// thumbnail takes the rest, matching the design's 198/98 split at 252 wide.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/icons/app_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/note_card_data.dart';
import '../notes_palette.dart';
import 'knowledge_graph_button.dart';
import 'note_preview.dart';

class NoteCard extends StatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onLongPress,
    this.onGraphTap,
    this.onToggleFavorite,
    this.imageProvider,
    this.sceneImageResolver,
    this.sceneRepaint,
  });

  final NoteCardData note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onGraphTap;

  /// Toggles the note's favourite (pinned) flag.
  final VoidCallback? onToggleFavorite;

  /// Test seam forwarded to [NotePreview].
  final ImageProvider? imageProvider;

  /// Bitmap supply + repaint signal for a live scene preview.
  final ui.Image? Function(String relativePath)? sceneImageResolver;
  final Listenable? sceneRepaint;

  static const borderRadius = BorderRadius.all(
    Radius.circular(NotesPalette.cardRadius),
  );

  static const _motion = Duration(milliseconds: 180);

  /// Inset of the floating graph button from the thumbnail's edges.
  static const graphButtonMargin = 10.0;

  /// Height of the footer under [scaler].
  ///
  /// The design's 98px holds at normal text size. A larger system font makes
  /// the title and the two meta lines taller, so the footer grows with them
  /// rather than clipping: vertical padding, one title line (20 × 1.3) and the
  /// taller of the favourite icon and the two meta lines (12 × 1.5 each).
  static double footerHeightFor(TextScaler scaler) {
    final k = scaler.scale(22) / 22;
    final content = 35 + 26.4 * k + math.max(32.0, 36 * k);
    return math.max(_Footer.baseHeight, content.ceilToDouble());
  }

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _raised = false;

  void _setRaised(bool value) {
    if (_raised == value) return;
    setState(() => _raised = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final note = widget.note;

    // Light lifts on the design's soft black shadow (25%, 0/4, blur 40) and
    // carries no outline; dark drops the shadow and draws a 1px hairline
    // instead — a shadow on near-black is invisible, so the card would have no
    // edge.
    final shadowAlpha = _raised ? 0.32 : 0.25;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setRaised(true),
      onExit: (_) => _setRaised(false),
      child: AnimatedScale(
        scale: _raised ? 1.01 : 1.0,
        duration: NoteCard._motion,
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedContainer(
            duration: NoteCard._motion,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: NoteCard.borderRadius,
              border: isDark ? Border.all(color: c.border) : null,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: shadowAlpha),
                        blurRadius: 40,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: NoteCard.borderRadius,
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'note-preview-${note.id}',
                          child: NotePreview(
                            note: note,
                            imageProvider: widget.imageProvider,
                            sceneImageResolver: widget.sceneImageResolver,
                            sceneRepaint: widget.sceneRepaint,
                          ),
                        ),
                        if (widget.onGraphTap != null)
                          Positioned(
                            right: NoteCard.graphButtonMargin,
                            top: NoteCard.graphButtonMargin,
                            child: KnowledgeGraphButton(
                              onTap: widget.onGraphTap!,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _Footer(
                    note: note,
                    height: NoteCard.footerHeightFor(
                      MediaQuery.textScalerOf(context),
                    ),
                    onToggleFavorite: widget.onToggleFavorite,
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

class _Footer extends StatelessWidget {
  const _Footer({
    required this.note,
    required this.height,
    this.onToggleFavorite,
  });

  final NoteCardData note;
  final double height;
  final VoidCallback? onToggleFavorite;

  /// The design's footer height at normal text size.
  static const baseHeight = 98.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Design: everything in ink — title 22 Medium at 15/13, the favourite
    // glyph 15 in and 25 up from the bottom, "N Pages" over the date (12)
    // right-aligned 18 in. The glyph's 4px tap padding is netted out of the
    // left/bottom insets.
    final meta = TextStyle(
      fontFamily: 'ModulusPro',
      fontSize: 12,
      height: 1.5,
      color: c.textPrimary,
    );

    return Container(
      height: height,
      color: c.surface,
      padding: const EdgeInsets.fromLTRB(11, 13, 18, 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ModulusPro',
                fontSize: 22,
                height: 1.17,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Semantics(
                button: true,
                label: note.pinned
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleFavorite,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: AppIcon(
                      note.pinned ? AppIcons.saved : AppIcons.save,
                      color: note.pinned ? c.accent : c.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      note.pageCountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta,
                    ),
                    Text(
                      note.longDateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
