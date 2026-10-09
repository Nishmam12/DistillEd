import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/services/snap_engine.dart';

void main() {
  test('snaps an edge within the threshold and emits a guide', () {
    final r = SnapEngine.snap(
      const Rect.fromLTRB(0, 0, 10, 10),
      const [Rect.fromLTRB(12, 0, 22, 10)],
      8,
    );
    expect(r.adjust.dx, closeTo(2, 1e-9)); // right edge 10 → target left 12
    expect(r.guides, isNotEmpty);
  });

  test('does not snap beyond the threshold', () {
    final r = SnapEngine.snap(
      const Rect.fromLTRB(0, 0, 10, 10),
      const [Rect.fromLTRB(30, 30, 40, 40)], // far on both axes
      8,
    );
    expect(r.adjust, Offset.zero);
    expect(r.guides, isEmpty);
  });
}
