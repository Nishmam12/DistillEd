// The live preview that fills a note card edge to edge.
//
// The preview is NOT a panel beside the overlay — it spans the whole card and
// continues *underneath* the frosted overlay, with a left-to-right white
// gradient washing it out so the overlay's type stays readable. [overlayInset]
// is how much of the left edge the overlay covers, which is all this widget
// needs to know to keep its own content clear of it.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/note_card_data.dart';
import '../notes_palette.dart';
import 'note_scene_preview.dart';

class NotePreview extends StatelessWidget {
  const NotePreview({
    super.key,
    required this.note,
    this.overlayInset = 0,
    this.trailingInset = 0,
    this.imageProvider,
    this.sceneImageResolver,
    this.sceneRepaint,
  });

  final NoteCardData note;

  /// Width of the card's left edge hidden behind the frosted overlay.
  final double overlayInset;

  /// Width of the card's right edge covered by floating controls. Text keeps
  /// clear of it; a page or photo still runs underneath.
  final double trailingInset;

  /// Overrides the provider built from [NoteCardData.previewImage]. Only tests
  /// pass this; the app resolves the thumbnail from disk.
  final ImageProvider? imageProvider;

  /// Supplies decoded bitmaps to a live scene preview, and a repaint signal for
  /// when they arrive.
  final ui.Image? Function(String relativePath)? sceneImageResolver;
  final Listenable? sceneRepaint;

  ImageProvider? get _resolvedImage {
    if (imageProvider != null) return imageProvider;
    final path = note.previewImage;
    return path == null ? null : FileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final image = _resolvedImage;

    return DecoratedBox(
      // The ground behind a preview that does not fill its box. Was a rotating
      // set of seven pastel tints; the nine-token spec has no tint set, so this
      // is the neutral subtle surface in both modes.
      decoration: BoxDecoration(color: c.surfaceSubtle),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (note.previewScene.isNotEmpty)
            NoteScenePreview(
              elements: note.previewScene,
              imageResolver: sceneImageResolver,
              repaint: sceneRepaint,
            )
          else if (image != null)
            Image(
              image: image,
              fit: BoxFit.cover,
              // Pages are portrait and cards are wide, so cover crops hard —
              // anchor to the top, where the writing on a page starts.
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, _, __) => _TypographicPreview(
                note: note,
                overlayInset: overlayInset,
                trailingInset: trailingInset,
              ),
            )
          else
            _TypographicPreview(
              note: note,
              overlayInset: overlayInset,
              trailingInset: trailingInset,
            ),
          // HOME-07. In dark, the thumbnail is knocked back with a scrim so a
          // bright page photo does not glare out of a near-black card. Painted
          // rather than shipped as a second asset, so one image serves both
          // modes. Sits UNDER the readability gradient: the gradient must stay
          // fully opaque over the text column, and a scrim above it would tint
          // that flat surface.
          if (isDark)
            DecoratedBox(
              decoration:
                  BoxDecoration(color: c.bgPrimary.withValues(alpha: 0.45)),
            ),
          // HOME-06 / HOME-17. Readability wash under the overlay's text.
          const _ReadabilityGradient(),
        ],
      ),
    );
  }
}

/// Surface-to-transparent wash so the card's title and meta rows never sit on
/// top of the thumbnail.
///
/// HOME-06: the stops are built from `context.colors.surface`, so the wash is
/// white in light and near-black in dark and the card reads as ONE surface that
/// the image emerges from — not a white panel pasted over a photo.
///
/// HOME-17, and the reason the first stop is held rather than immediately
/// decaying: the wash stays at FULL opacity across the whole overlay width, so
/// every pixel of text sits on flat `surface`. A thumbnail with a bright patch
/// under the title would otherwise destroy the contrast guarantee no matter
/// what colour the text is.
///
///   text column  = [18px, overlayWidth - 12px]        (NoteOverlay's padding)
///   overlayWidth = overlayWidthFactor * cardWidth     (NoteCard's LayoutBuilder)
///   opaque to    = overlayWidthFactor * cardWidth     (the second stop below)
///
/// so the opaque region exceeds the text's right edge by the overlay's 12px
/// right padding, at every card width. The stop reads the SAME constant the
/// overlay's width is computed from, so the two cannot drift apart.
class _ReadabilityGradient extends StatelessWidget {
  const _ReadabilityGradient();

  /// How far past the overlay the wash takes to disappear. Wide enough that the
  /// hand-off reads as a fade rather than an edge; short enough that it does
  /// not drain the colour out of the preview, which is what the glance is for.
  static const _falloff = 0.18;

  @override
  Widget build(BuildContext context) {
    final surface = context.colors.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            surface,
            surface,
            surface.withValues(alpha: 0),
          ],
          stops: const [
            0.0,
            NotesPalette.overlayWidthFactor,
            NotesPalette.overlayWidthFactor + _falloff,
          ],
        ),
      ),
    );
  }
}

/// Fallback preview for notes with no rendered page: the title set large in
/// editorial caps, with any recognised text listed beside it.
class _TypographicPreview extends StatelessWidget {
  const _TypographicPreview({
    required this.note,
    required this.overlayInset,
    required this.trailingInset,
  });

  final NoteCardData note;
  final double overlayInset;
  final double trailingInset;

  @override
  Widget build(BuildContext context) {
    final lines = note.previewLines();
    final showBullets = note.type == NoteType.checklist;

    return Padding(
      padding: EdgeInsets.fromLTRB(overlayInset + 18, 20, trailingInset + 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: lines.isEmpty ? 1 : 3,
            child: Text(
              note.title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 26,
                height: 1.05,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        showBullets ? '•  $line' : line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          height: 1.3,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
