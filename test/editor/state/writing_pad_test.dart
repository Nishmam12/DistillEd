import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/stroke_point.dart';
import 'package:margo/editor/state/writing_pad.dart';

void main() {
  const pad = WritingPad(
      target: Offset(100, 200), lineStartX: 100, lineHeight: 36);

  test('pad ink lands in the box, scaled to one line', () {
    // A 180 px pad holds one 36-unit line: 5 pad px per page unit.
    expect(pad.toPage(const Offset(0, 0), 180), const Offset(100, 200));
    expect(pad.toPage(const Offset(90, 180), 180), const Offset(118, 236));
    final stroke = pad.strokeToPage(
        const [StrokePoint(x: 50, y: 90, pressure: 0.7)], 180);
    expect((stroke.single.x, stroke.single.y, stroke.single.pressure),
        (110.0, 218.0, 0.7));
  });

  test('space moves past the ink and a gap; new line goes back under', () {
    final next = pad.advancedPast(300, 180); // 60 units of ink
    expect(next.target, const Offset(100 + 60 + 12, 200));
    final below = next.newLine();
    expect(below.target, const Offset(100, 245));
    expect(pad.placedAt(const Offset(7, 9)).lineStartX, 7);
  });
}
