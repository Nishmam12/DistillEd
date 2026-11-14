import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/geometry/selection_bounds.dart';
import '../../../domain/model/page_size.dart';
import '../../../domain/model/scene_element.dart';
import '../../../editor/render/scene_image_cache.dart';
import '../../../editor/render/scene_static_layer.dart';

/// Width over height of a page of [kind]. Fit screen has no fixed shape, so it
/// reads as A4 portrait here.
double pageAspectOf(PageSizeKind kind) {
  final size = kind.size;
  return size == null ? 1 / 1.414 : size.width / size.height;
}

/// A page drawn small: its elements fitted into a sheet of [aspectRatio].
class PageThumbnail extends StatelessWidget {
  final List<SceneElement> elements;
  final Color paper;
  final SceneImageCache imageCache;
  final double aspectRatio;

  const PageThumbnail({
    super.key,
    required this.elements,
    required this.paper,
    required this.imageCache,
    this.aspectRatio = 1 / 1.414,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: paper,
          boxShadow: context.floatShadow,
        ),
        child: CustomPaint(
          painter: _PageThumbnailPainter(
            elements: elements,
            imageCache: imageCache,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Paints a page's elements fitted (scaled + centred) into the available size.
class _PageThumbnailPainter extends CustomPainter {
  final List<SceneElement> elements;
  final SceneImageCache imageCache;

  _PageThumbnailPainter({required this.elements, required this.imageCache});

  @override
  void paint(Canvas canvas, Size size) {
    if (elements.isEmpty) return;
    final bounds = SelectionBounds.union(elements);
    if (bounds == null || bounds.isEmpty) return;

    const pad = 12.0;
    final sx = (size.width - pad * 2) / bounds.width;
    final sy = (size.height - pad * 2) / bounds.height;
    final scale = sx < sy ? sx : sy;
    final dx = (size.width - bounds.width * scale) / 2 - bounds.left * scale;
    final dy = (size.height - bounds.height * scale) / 2 - bounds.top * scale;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    SceneStaticLayer(
      elements: elements,
      imageResolver: imageCache.get,
      imageEpoch: imageCache.version,
    ).paint(canvas, bounds.size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PageThumbnailPainter old) =>
      !identical(elements, old.elements) ||
      imageCache.version != old.imageCache.version;
}
