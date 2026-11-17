// Which strokes a scribble wipes out. Written after the first device test:
// "strokes from the earlier pens are not erased by scribbling with the new
// ones". The pen type plays no part; how much of a stroke's INK the scribble
// covers does.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/tools/ink_gestures.dart';

FreehandElement _stroke(
  String id,
  List<Offset> at, {
  PenKind kind = PenKind.ballpoint,
}) => FreehandElement(
  id: id,
  zOrder: 0,
  points: [for (final p in at) StrokePoint(x: p.dx, y: p.dy)],
  color: 0xFF000000,
  size: 2,
  opacity: 1,
  penKind: kind,
);

List<Offset> _line(Offset a, Offset b, [int n = 20]) => [
  for (var i = 0; i <= n; i++) Offset.lerp(a, b, i / n)!,
];

void main() {
  test('every pen type is erased alike', () {
    final scene = [
      for (final (i, kind) in PenKind.values.indexed)
        _stroke(
          'k$i',
          _line(Offset(10, 10.0 + i * 10), Offset(60, 10.0 + i * 10)),
          kind: kind,
        ),
    ];
    final victims = scribbleVictims(
      scene,
      // Tall enough for one stroke per pen, however many pens there are.
      Rect.fromLTRB(0, 0, 80, 20.0 + PenKind.values.length * 10),
      excludeId: 'scribble',
    );
    expect(victims.map((e) => e.id), [
      for (var i = 0; i < PenKind.values.length; i++) 'k$i',
    ]);
  });

  test('a stroke whose ink is mostly under the scribble is erased', () {
    // An L: a tall bar (most of the ink) and a long, thin foot. The scribble
    // covers the bar. Its bounding box is mostly NOT covered, which is why the
    // old box-area rule left it on the page.
    // Bar 400 long, foot 100: ~78% of the ink is under the scribble, ~20% of
    // the 100 x 400 box.
    final l = _stroke('L', [
      ..._line(const Offset(0, 0), const Offset(0, 400), 40),
      ..._line(const Offset(0, 400), const Offset(100, 400), 10),
    ]);
    final victims = scribbleVictims(
      [l],
      const Rect.fromLTRB(-10, -10, 20, 390),
      excludeId: 'scribble',
    );
    expect(victims.map((e) => e.id), ['L']);
  });

  test('a stroke the scribble only grazes is kept', () {
    final word = _stroke(
      'w',
      _line(const Offset(0, 0), const Offset(300, 0), 60),
    );
    final victims = scribbleVictims(
      [word],
      const Rect.fromLTRB(-5, -5, 40, 5),
      excludeId: 'scribble',
    );
    expect(victims, isEmpty);
  });

  test('pictures and locked things are never erased', () {
    final locked = _stroke(
      'locked',
      _line(const Offset(10, 10), const Offset(20, 10)),
    ).copyWith(isLocked: true);
    final victims = scribbleVictims(
      [locked],
      const Rect.fromLTRB(0, 0, 40, 40),
      excludeId: 'scribble',
    );
    expect(victims, isEmpty);
  });
}
