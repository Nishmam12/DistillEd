// The live thumbnail on top of a note card.
//
// Fills whatever box it is given: the note's own first page painted from its
// scene, else a rendered page thumbnail, else a typographic fallback (title
// plus recognised text) on the subtle sage surface.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/note_card_data.dart';
import 'note_scene_preview.dart';

class NotePreview extends StatelessWidget {
  const NotePreview({
    super.key,
    required this.note,
    this.imageProvider,
    this.sceneImageResolver,
    this.sceneRepaint,
  });

  final NoteCardData note;

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
      // The ground behind a preview that does not fill its box — the sage
      // placeholder the design shows before a page exists.
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
              // Pages are portrait and thumbnails are near-square, so cover
              // crops hard — anchor to the top, where the writing starts.
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, _, _) => _TypographicPreview(note: note),
            )
          else
            _TypographicPreview(note: note),
          // In dark, a bright page photo is knocked back with a scrim so it does
          // not glare out of a near-black grid. Painted rather than shipped as
          // a second asset, so one image serves both modes.
          if (isDark)
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.bgPrimary.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fallback for notes with no rendered page: any recognised text, listed on the
/// sage ground. The title is not repeated — the card's footer already has it —
/// so a note with nothing yet is simply a quiet placeholder.
class _TypographicPreview extends StatelessWidget {
  const _TypographicPreview({required this.note});

  final NoteCardData note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = note.previewLines();
    if (lines.isEmpty) return const SizedBox.expand();
    final showBullets = note.type == NoteType.checklist;
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Show only the lines that fit: with a large system font the thumbnail
        // holds fewer, and an unbounded column would overflow.
        const padding = 16.0;
        final lineHeight = scaler.scale(14) * 1.3 + 4;
        final fit = ((constraints.maxHeight - padding * 2) / lineHeight)
            .floor()
            .clamp(1, lines.length);

        return Padding(
          padding: const EdgeInsets.all(padding),
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines.take(fit))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      showBullets ? '•  $line' : line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ModulusPro',
                        fontSize: 14,
                        height: 1.3,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
