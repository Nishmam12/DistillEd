// Aligns and distributes selected elements using their world bounds. Returns
// only the elements that actually moved (translated copies); the caller merges
// them back by id. Locked elements are never moved or used as a reference.

import 'dart:ui';

import '../geometry/element_transformer.dart';
import '../geometry/scene_geometry.dart';
import '../model/scene_element.dart';

enum AlignEdge { left, centerH, right, top, middleV, bottom }

/// Axis for distribution (domain-local; avoids a Flutter dependency).
enum SceneAxis { horizontal, vertical }

class AlignmentService {
  AlignmentService._();

  static List<SceneElement> align(List<SceneElement> all, AlignEdge edge) {
    final selected = [for (final e in all) if (!e.isLocked) e];
    if (selected.length < 2) return const [];
    final bounds = {for (final e in selected) e.id: SceneGeometry.worldAabb(e)};
    final union = bounds.values.reduce((a, b) => a.expandToInclude(b));

    return [
      for (final e in selected)
        if (_delta(edge, bounds[e.id]!, union) case final d when d != Offset.zero)
          SceneTransformer.translate(e, d),
    ];
  }

  static Offset _delta(AlignEdge edge, Rect b, Rect union) {
    switch (edge) {
      case AlignEdge.left:
        return Offset(union.left - b.left, 0);
      case AlignEdge.centerH:
        return Offset(union.center.dx - b.center.dx, 0);
      case AlignEdge.right:
        return Offset(union.right - b.right, 0);
      case AlignEdge.top:
        return Offset(0, union.top - b.top);
      case AlignEdge.middleV:
        return Offset(0, union.center.dy - b.center.dy);
      case AlignEdge.bottom:
        return Offset(0, union.bottom - b.bottom);
    }
  }

  /// Distributes elements so their centres are evenly spaced along [axis].
  static List<SceneElement> distribute(
      List<SceneElement> all, SceneAxis axis) {
    final selected = [for (final e in all) if (!e.isLocked) e];
    if (selected.length < 3) return const [];
    final bounds = {for (final e in selected) e.id: SceneGeometry.worldAabb(e)};

    double centre(Rect r) =>
        axis == SceneAxis.horizontal ? r.center.dx : r.center.dy;
    final sorted = [...selected]
      ..sort((a, b) => centre(bounds[a.id]!).compareTo(centre(bounds[b.id]!)));

    final first = centre(bounds[sorted.first.id]!);
    final last = centre(bounds[sorted.last.id]!);
    final step = (last - first) / (sorted.length - 1);

    final result = <SceneElement>[];
    for (int i = 0; i < sorted.length; i++) {
      final e = sorted[i];
      if (i == 0 || i == sorted.length - 1) continue; // endpoints stay put
      final target = first + step * i;
      final delta = target - centre(bounds[e.id]!);
      if (delta == 0) continue;
      result.add(SceneTransformer.translate(e,
          axis == SceneAxis.horizontal ? Offset(delta, 0) : Offset(0, delta)));
    }
    return result;
  }
}
