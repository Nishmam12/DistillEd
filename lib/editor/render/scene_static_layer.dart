// Static content layer — paints committed [SceneElement]s in scene coordinates,
// delegating per-element rendering to [SceneElementPainter].
//
// Elements paint in zOrder so eraser ink clears earlier content. When eraser
// freehand elements are present, all content is composited into one offscreen
// layer so their BlendMode.clear punches transparent holes (the pixel eraser).
// [hiddenIds] are skipped entirely — used for live pending-erase feedback.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/model/scene_element.dart';
import '../../domain/services/frame_service.dart';
import 'freehand_path.dart';
import 'scene_element_painter.dart';

/// Eraser outlines, built once per stroke. Pen strokes were already cached
/// (see `SceneElementPainter`); eraser strokes were rebuilt — a full
/// perfect_freehand pass each — on EVERY repaint of the page, which is every
/// stroke added to it.
final Expando<Path> _eraserCache = Expando<Path>();

class SceneStaticLayer extends CustomPainter {
  final List<SceneElement> elements;
  final Set<String> hiddenIds;
  final ui.Image? Function(String relativePath)? imageResolver;

  /// Bumped by the image cache when a bitmap finishes loading, so the layer
  /// repaints even though [elements] is unchanged.
  final int imageEpoch;

  const SceneStaticLayer({
    required this.elements,
    this.hiddenIds = const {},
    this.imageResolver,
    this.imageEpoch = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ordered = [...elements]..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    final byId = {for (final e in ordered) e.id: e};

    final hasEraser = ordered.any((e) =>
        e is FreehandElement && e.isEraser && !hiddenIds.contains(e.id));
    if (hasEraser) canvas.saveLayer(canvas.getLocalClipBounds(), Paint());

    // Members of a frame are clipped to that frame's bounds when painted.
    final clipById =
        ordered.any((e) => e is FrameElement) ? FrameService.clipBoundsByElement(ordered) : const <String, Rect>{};

    for (final e in ordered) {
      if (hiddenIds.contains(e.id)) continue;
      if (e is FreehandElement && e.isEraser) {
        _erase(canvas, e);
        continue;
      }
      final clip = clipById[e.id];
      if (clip != null) {
        canvas.save();
        canvas.clipRect(clip);
        SceneElementPainter.paint(canvas, e,
            byId: byId, imageResolver: imageResolver);
        canvas.restore();
      } else {
        SceneElementPainter.paint(canvas, e,
            byId: byId, imageResolver: imageResolver);
      }
    }

    if (hasEraser) canvas.restore();
  }

  void _erase(Canvas canvas, FreehandElement e) {
    var path = _eraserCache[e];
    if (path == null) {
      path = FreehandPath.build(e.points, e.size, isComplete: true);
      if (path == null) return;
      _eraserCache[e] = path;
    }
    canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(SceneStaticLayer oldDelegate) =>
      !identical(elements, oldDelegate.elements) ||
      !identical(hiddenIds, oldDelegate.hiddenIds) ||
      imageEpoch != oldDelegate.imageEpoch;
}
