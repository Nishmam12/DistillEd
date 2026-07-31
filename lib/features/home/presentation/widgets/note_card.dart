// One row of the Notes list: a single seamless card, not a list tile.
//
// Three layers, outer-most last:
//   1. the preview, spanning the full card width;
//   2. the frosted overlay covering the left third of it;
//   3. the knowledge-graph button, floating clear of the card's clip so its
//      shadow is not cut off at the rounded edge.
//
// Widths are fractions of whatever the list hands the card, so the same widget
// works on a phone, a tablet and a desktop window.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/note_card_data.dart';
import '../notes_palette.dart';
import 'knowledge_graph_button.dart';
import 'note_overlay.dart';
import 'note_preview.dart';

class NoteCard extends StatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onLongPress,
    this.onGraphTap,
    this.imageProvider,
    this.sceneImageResolver,
    this.sceneRepaint,
  });

  final NoteCardData note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onGraphTap;

  /// Test seam forwarded to [NotePreview].
  final ImageProvider? imageProvider;

  /// Bitmap supply + repaint signal for a live scene preview.
  final ui.Image? Function(String relativePath)? sceneImageResolver;
  final Listenable? sceneRepaint;

  static const borderRadius =
      BorderRadius.all(Radius.circular(NotesPalette.cardRadius));

  static const _motion = Duration(milliseconds: 180);

  /// Inset of the floating graph button from the card's right edge.
  static const graphButtonMargin = 18.0;

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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setRaised(true),
      onExit: (_) => _setRaised(false),
      child: AnimatedScale(
        scale: _raised ? 1.01 : 1.0,
        duration: NoteCard._motion,
        curve: Curves.easeOut,
        child: Stack(
          children: [
            Positioned.fill(child: _body()),
            if (widget.onGraphTap != null)
              Positioned(
                right: NoteCard.graphButtonMargin,
                top: 0,
                bottom: 0,
                child: Center(
                  child: KnowledgeGraphButton(onTap: widget.onGraphTap!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // HOME-05. Light lifts on a soft shadow and carries no outline; dark drops
    // the shadow entirely and draws a 1px hairline instead — a shadow on
    // near-black is invisible, so a dark card with only a shadow would have no
    // edge against the scaffold at all.
    //
    // THEME_SPEC.md defines no shadow token, so the tint is derived from
    // `accent` rather than invented. The raised (hover) state deepens the same
    // colour rather than switching to a different one.
    final shadowAlpha = _raised ? 0.13 : 0.08;

    return GestureDetector(
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
                    color: c.accent.withValues(alpha: shadowAlpha),
                    blurRadius: _raised ? 28 : 20,
                    offset: Offset(0, _raised ? 12 : 8),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: NoteCard.borderRadius,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final overlayWidth =
                  constraints.maxWidth * NotesPalette.overlayWidthFactor;
              return Stack(
                children: [
                  // The preview runs edge to edge and continues underneath the
                  // overlay — the two are one surface, not two panels.
                  Positioned.fill(
                    child: Hero(
                      tag: 'note-preview-${widget.note.id}',
                      child: NotePreview(
                        note: widget.note,
                        overlayInset: overlayWidth,
                        trailingInset: widget.onGraphTap == null
                            ? 0
                            : NotesPalette.graphButtonRadius * 2 +
                                NoteCard.graphButtonMargin,
                        imageProvider: widget.imageProvider,
                        sceneImageResolver: widget.sceneImageResolver,
                        sceneRepaint: widget.sceneRepaint,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: overlayWidth,
                    child: NoteOverlay(note: widget.note),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
