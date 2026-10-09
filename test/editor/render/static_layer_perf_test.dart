// Perf smoke test: a busy page (500 strokes) must rasterise through the real
// [SceneStaticLayer] in well under a frame budget's worth of slack. This guards
// against accidental per-paint blow-ups (e.g. losing the per-element path cache);
// it is a generous ceiling, not a benchmark. Pan/zoom never repaints this layer
// (it sits under a Transform), so this covers the worst case: a content change.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/model/scene_element.dart';
import 'package:distill_ed/editor/render/scene_static_layer.dart';

List<SceneElement> _strokes(int n) {
  final rnd = Random(7);
  return [
    for (int i = 0; i < n; i++)
      FreehandElement(
        id: 's$i',
        zOrder: i,
        color: 0xFF1F2933,
        size: 3,
        points: [
          for (int p = 0; p < 20; p++)
            StrokePoint(
                x: rnd.nextDouble() * 1000,
                y: rnd.nextDouble() * 1400,
                pressure: 0.5),
        ],
      ),
  ];
}

void main() {
  testWidgets('500 strokes rasterise within a generous budget', (tester) async {
    await tester.runAsync(() async {
      final elements = _strokes(500);
      final layer = SceneStaticLayer(elements: elements);

      final sw = Stopwatch()..start();
      final recorder = ui.PictureRecorder();
      layer.paint(Canvas(recorder), const Size(1000, 1400));
      final picture = recorder.endRecording();
      final image = await picture.toImage(1000, 1400);
      sw.stop();

      expect(image.width, 1000);
      // Very generous ceiling (~5 frames) to catch pathological regressions
      // without being flaky on slow CI.
      expect(sw.elapsedMilliseconds, lessThan(1500),
          reason: 'paint+raster took ${sw.elapsedMilliseconds}ms');

      image.dispose();
      picture.dispose();
    });
  });

  testWidgets('shouldRepaint ignores identical content but reacts to image epoch',
      (tester) async {
    final els = _strokes(3);
    const hidden = <String>{};
    final a = SceneStaticLayer(elements: els, hiddenIds: hidden, imageEpoch: 0);
    final sameContent =
        SceneStaticLayer(elements: els, hiddenIds: hidden, imageEpoch: 0);
    final newEpoch =
        SceneStaticLayer(elements: els, hiddenIds: hidden, imageEpoch: 1);

    expect(a.shouldRepaint(sameContent), isFalse);
    expect(a.shouldRepaint(newEpoch), isTrue);
  });
}
