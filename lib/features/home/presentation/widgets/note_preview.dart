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
import '../../../../core/theme/ink_colors.dart';
import '../models/note_card_data.dart';
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
      // The ground behind a preview that does not fill its box. Seven tints
      // rotate by note id, so a list reads as a shelf of distinct documents
      // rather than a stack of identical rows — a note keeps the same tint
      // across rebuilds because the index is derived from its id.
      //
      // These come from `context.notes`, NOT the nine-token `context.colors`
      // set, because THEME_SPEC.md has no tint scale. `NotesInk` carries a
      // light and a dark set, so they still follow the brightness.
      decoration: BoxDecoration(color: context.notes.tintFor(note.id)),
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
          // modes.
          //
          // Ordering matters: this sits UNDER the wash, so it dims the PAGE
          // only. Above the wash it would tint the details column too, and the
          // blend is meant to look identical in both brightnesses.
          if (isDark)
            DecoratedBox(
              decoration:
                  BoxDecoration(color: c.bgPrimary.withValues(alpha: 0.45)),
            ),
          // The wash that blends the details column into the page.
          const _ReadabilityGradient(),
        ],
      ),
    );
  }
}

/// Surface-to-transparent wash that blends the details panel into the preview.
///
/// The stops are built from `context.colors.surface`, so the wash is white in
/// light and near-black in dark and the card reads as ONE surface the page
/// emerges from — not a white panel pasted over a photo.
///
/// ── Why this is a long ramp and not a hard step ───────────────────────────
/// An earlier revision held FULL opacity across the entire overlay width and
/// then dropped away, which guaranteed every glyph sat on flat colour but drew
/// a visible seam down the card: a solid block, then a picture. The two halves
/// are meant to read as one surface that fades between them, so the wash now
/// stays solid only across the left of the details column and then ramps down
/// gradually, well past the overlay's own edge.
///
///   0.00 → 0.20   solid `surface`   — the title and meta labels start here
///   0.20 → 0.44   1.0 → 0.5         — the page begins showing through
///   0.44 → 0.72   0.5 → 0.0         — clears completely
///
/// The alpha profile is IDENTICAL in both brightnesses — only the colour tracks
/// the theme. Do not branch it on `isDark`; the blend is meant to look the same
/// in both, and only the thumbnail's own scrim differs.
///
/// Text bounds, for reference when tuning: the details column occupies
/// `[18px, overlayWidth - 12px]` where `overlayWidth = overlayWidthFactor *
/// cardWidth` (0.34), so its right edge lands at ~0.34 — where the wash is
/// still around 70%. That is deliberate. If a thumbnail ever proves too busy
/// under the meta rows, lengthen `_solidTo` rather than restoring the step.
class _ReadabilityGradient extends StatelessWidget {
  const _ReadabilityGradient();

  /// Fraction of the card width held at full `surface` before the blend starts.
  static const _solidTo = 0.20;

  /// Where the wash is half gone, and where it has cleared entirely.
  static const _midpoint = 0.44;
  static const _clearedBy = 0.72;

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
            surface.withValues(alpha: 0.5),
            surface.withValues(alpha: 0),
          ],
          stops: const [0.0, _solidTo, _midpoint, _clearedBy],
        ),
      ),
    );
  }
}

/// Fallback preview for notes with no rendered page: whatever text has been
/// recognised on the first page, set small.
///
/// The note's own title used to be set large in editorial caps here, filling
/// the left of the preview area. It was removed deliberately — the title
/// already appears in the details column immediately to the left, so the card
/// showed the same string twice, competing at two different sizes. This area is
/// now only ever the first page's content.
///
/// A note with no recognised text renders nothing at all, leaving the tinted
/// ground. That is intended: an empty page should look empty.
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
    if (lines.isEmpty) return const SizedBox.shrink();

    final showBullets = note.type == NoteType.checklist;

    return Padding(
      padding: EdgeInsets.fromLTRB(overlayInset + 18, 20, trailingInset + 20, 20),
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
    );
  }
}
