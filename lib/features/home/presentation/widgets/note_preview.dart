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
    final tint = context.notes.tintFor(note.id);
    final image = _resolvedImage;

    return DecoratedBox(
      decoration: BoxDecoration(color: tint),
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
          // Readability wash under the glass overlay.
          const _ReadabilityGradient(),
        ],
      ),
    );
  }
}

/// White-to-transparent wash so the frosted overlay never sits on top of a
/// busy, dark thumbnail.
///
/// It clears shortly after the overlay's inner edge (~34%): washing further
/// would drain the colour out of the preview itself, which is the part the
/// glance is for.
class _ReadabilityGradient extends StatelessWidget {
  const _ReadabilityGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white,
            Colors.white.withValues(alpha: 0.80),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.26, 0.44],
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
                color: context.notes.textPrimary,
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
                          color: context.notes.textPrimary,
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
