// Element/stroke eraser hit-testing: which elements does an eraser stroke
// segment (a → b, with [radius]) touch? Samples along the segment against each
// element's inflated world bounds so fast swipes don't skip elements.

import 'dart:ui';

import '../geometry/scene_geometry.dart';
import '../geometry/scene_hit_test.dart';
import '../model/scene_element.dart';

class EraserService {
  EraserService._();

  static Set<String> hitAlongSegment({
    required Offset a,
    required Offset b,
    required double radius,
    required List<SceneElement> elements,
    Set<String> skip = const {},
  }) {
    final hits = <String>{};
    for (final e in elements) {
      if (skip.contains(e.id) || e.isLocked) continue;
      final box = SceneGeometry.worldAabb(e).inflate(radius);
      if (_segmentTouches(a, b, box, e, radius)) hits.add(e.id);
    }
    return hits;
  }

  /// Samples a → b; a sample only counts if it is inside the element's
  /// inflated world bounds AND actually touches its body (stroke / outline).
  static bool _segmentTouches(
      Offset a, Offset b, Rect box, SceneElement e, double radius) {
    final length = (b - a).distance;
    final steps = (length / 4).ceil().clamp(1, 512);
    for (int i = 0; i <= steps; i++) {
      final pt = Offset.lerp(a, b, i / steps)!;
      if (box.contains(pt) && SceneHitTest.touches(e, pt, radius)) return true;
    }
    return false;
  }
}
