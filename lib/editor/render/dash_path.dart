// Converts a solid path into a dashed/dotted one via PathMetrics, for the
// dashed and dotted stroke styles.

import 'dart:math' as math;
import 'dart:ui';

class DashPath {
  DashPath._();

  /// Returns a new path made of [dash]-length segments separated by [gap].
  static Path dashed(Path source, {required double dash, required double gap}) {
    // A step that never advances would loop for ever; a solid path is the only
    // sensible answer to a pattern with no dashes in it.
    if (dash <= 0 || dash + gap <= 0) return source;
    final result = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = math.min(dash, metric.length - distance);
        result.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        distance += dash + gap;
      }
    }
    return result;
  }
}
