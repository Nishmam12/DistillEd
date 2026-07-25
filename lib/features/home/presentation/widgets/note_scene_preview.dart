// A live miniature of a note's first page, painted straight from its persisted
// scene elements — no thumbnail files, so a card can never show a stale render.
//
// Framing follows a document browser rather than a photo viewer: the content is
// fitted to the preview's *width* and anchored to the top, so a full page shows
// the beginning of the writing at a readable scale instead of shrinking the
// whole page into a 160px strip. Content that already fits is centred and never
// upscaled.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../domain/model/scene_element.dart';
import '../../../../editor/render/scene_element_painter.dart';
import '../../../../editor/render/scene_exporter.dart';

class NoteScenePreview extends StatelessWidget {
  const NoteScenePreview({
    super.key,
    required this.elements,
    this.imageResolver,
    this.repaint,
  });

  final List<SceneElement> elements;

  /// Supplies decoded bitmaps for image elements; unresolved images fall back
  /// to the painter's placeholder.
  final ui.Image? Function(String relativePath)? imageResolver;

  /// Notifies the painter when late-loading images become available.
  final Listenable? repaint;

  /// A card is a glance, not a document view — painting an entire 5,000-stroke
  /// page per row would cost more than the whole list is worth.
  static const maxElements = 400;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: NoteScenePreviewPainter(
          elements: elements.length > maxElements
              ? elements.sublist(0, maxElements)
              : elements,
          imageResolver: imageResolver,
          repaint: repaint,
        ),
      ),
    );
  }
}

@visibleForTesting
class NoteScenePreviewPainter extends CustomPainter {
  NoteScenePreviewPainter({
    required this.elements,
    this.imageResolver,
    super.repaint,
  });

  final List<SceneElement> elements;
  final ui.Image? Function(String relativePath)? imageResolver;

  /// Scale used to draw [elements] into a preview of [size].
  ///
  /// Fits the content width, never magnifying beyond 1:1.
  @visibleForTesting
  static double scaleFor(Rect bounds, Size size) {
    if (bounds.width <= 0 || size.width <= 0) return 1;
    final fit = size.width / bounds.width;
    return fit > 1 ? 1 : fit;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (elements.isEmpty || size.isEmpty) return;
    final bounds = SceneExporter.contentBounds(elements, padding: 12);
    if (bounds == null) return;

    final scale = scaleFor(bounds, size);
    final scaledHeight = bounds.height * scale;
    // Centre what already fits; otherwise show the top of the page.
    final dy = scaledHeight < size.height ? (size.height - scaledHeight) / 2 : 0.0;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-bounds.left * scale, dy - bounds.top * scale);
    canvas.scale(scale);

    final byId = {for (final e in elements) e.id: e};
    for (final element in elements) {
      SceneElementPainter.paint(
        canvas,
        element,
        byId: byId,
        imageResolver: imageResolver,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(NoteScenePreviewPainter oldDelegate) =>
      !identical(oldDelegate.elements, elements) ||
      oldDelegate.imageResolver != imageResolver;
}
