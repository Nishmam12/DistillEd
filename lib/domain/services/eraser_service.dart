// Element/stroke eraser hit-testing: which elements does an eraser stroke
// segment (a → b, with [radius]) touch? Samples along the segment against each
// element's inflated world bounds so fast swipes don't skip elements.

import 'dart:ui';

import '../geometry/scene_geometry.dart';
import '../geometry/scene_hit_test.dart';
import '../model/element_style.dart' show PenKind;
import '../model/scene_element.dart';

// Elements are immutable, so a world box is computed once per element, not per
// pointer event (ElementBounds walks every freehand point).
final Expando<Rect> _worldBox = Expando<Rect>();

/// The eraser panel's one-tap actions for a whole page.
enum PageErase {
  /// Every handwritten stroke (pen, pencil, highlighter...).
  handwriting,

  /// Everything on the page.
  everything,
}

class EraserService {
  EraserService._();

  /// What the eraser may touch: everything, or only highlighter strokes.
  static List<SceneElement> erasable(
    List<SceneElement> elements, {
    required bool highlighterOnly,
  }) =>
      highlighterOnly
          ? [
              for (final e in elements)
                if (e is FreehandElement &&
                    !e.isEraser &&
                    e.penKind == PenKind.highlighter)
                  e,
            ]
          : elements;

  /// What [what] removes from a page. A locked element (an imported PDF page,
  /// say) is never removed: it has to be unlocked first, as for the eraser.
  static List<SceneElement> pageEraseTargets(
    List<SceneElement> elements,
    PageErase what,
  ) =>
      [
        for (final e in elements)
          if (!e.isLocked &&
              (what == PageErase.everything ||
                  (e is FreehandElement && !e.isEraser)))
            e,
      ];

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
      final box = (_worldBox[e] ??= SceneGeometry.worldAabb(e)).inflate(radius);
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
