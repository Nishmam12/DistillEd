import 'package:flutter_test/flutter_test.dart';

import 'package:margo/domain/model/stroke_point.dart';
import 'package:margo/editor/render/scene_active_stroke_layer.dart';

void main() {
  const a = StrokePoint(x: 0, y: 0);
  const b = StrokePoint(x: 5, y: 0);
  const c = StrokePoint(x: 9, y: 3);

  test('begin and add grow the same stroke, notifying each time', () {
    final stroke = ActiveStroke();
    var notified = 0;
    stroke.addListener(() => notified++);

    stroke.begin(a, color: 0xFF112233, size: 6, opacity: 0.5);
    stroke.add(b);
    stroke.add(c);

    expect(stroke.points, [a, b, c]);
    expect(stroke.color, 0xFF112233);
    expect(stroke.size, 6);
    expect(stroke.opacity, 0.5);
    expect(notified, 3);
  });

  test('a point with no stroke in progress is ignored', () {
    final stroke = ActiveStroke();
    var notified = 0;
    stroke.addListener(() => notified++);

    stroke.add(b);

    expect(stroke.isEmpty, isTrue);
    expect(notified, 0);
  });

  test('take hands the points over and a later stroke cannot alter them', () {
    final stroke = ActiveStroke()..begin(a, color: 0, size: 4);
    stroke.add(b);

    final taken = stroke.take();
    stroke.begin(c, color: 0, size: 4);
    stroke.add(a);

    expect(taken, [a, b]);
    expect(stroke.points, [c, a]);
  });

  test('take and clear on an empty stroke do not notify', () {
    final stroke = ActiveStroke();
    var notified = 0;
    stroke.addListener(() => notified++);

    expect(stroke.take(), isEmpty);
    stroke.clear();

    expect(notified, 0);
  });

  test('the layer repaints from the stroke, not from being rebuilt', () {
    final stroke = ActiveStroke();
    final layer = SceneActiveStrokeLayer(stroke);

    expect(layer.shouldRepaint(SceneActiveStrokeLayer(stroke)), isFalse);
    expect(layer.shouldRepaint(SceneActiveStrokeLayer(ActiveStroke())), isTrue);
  });
}
