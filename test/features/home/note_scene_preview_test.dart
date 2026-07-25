import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/features/home/presentation/widgets/note_scene_preview.dart';

FreehandElement _stroke({
  String id = 'a',
  int zOrder = 0,
  double x = 0,
  double y = 0,
  double length = 100,
}) {
  return FreehandElement(
    id: id,
    zOrder: zOrder,
    color: 0xFF111111,
    size: 4,
    points: [
      StrokePoint(x: x, y: y, pressure: 0.5),
      StrokePoint(x: x + length, y: y + length, pressure: 0.5),
    ],
  );
}

void main() {
  group('framing', () {
    test('fits the content to the preview width', () {
      final scale = NoteScenePreviewPainter.scaleFor(
        const Rect.fromLTWH(0, 0, 800, 1000),
        const Size(360, 160),
      );

      expect(scale, closeTo(360 / 800, 0.0001));
    });

    test('never magnifies content that already fits', () {
      final scale = NoteScenePreviewPainter.scaleFor(
        const Rect.fromLTWH(0, 0, 120, 60),
        const Size(360, 160),
      );

      expect(scale, 1.0);
    });

    test('offsetting bounds does not change the scale', () {
      final atOrigin = NoteScenePreviewPainter.scaleFor(
        const Rect.fromLTWH(0, 0, 800, 1000),
        const Size(360, 160),
      );
      final farAway = NoteScenePreviewPainter.scaleFor(
        const Rect.fromLTWH(4000, -900, 800, 1000),
        const Size(360, 160),
      );

      expect(farAway, atOrigin);
    });

    test('degenerate bounds fall back to 1:1 instead of dividing by zero', () {
      expect(
        NoteScenePreviewPainter.scaleFor(
          const Rect.fromLTWH(0, 0, 0, 0),
          const Size(360, 160),
        ),
        1.0,
      );
    });
  });

  group('painting', () {
    testWidgets('paints a page of ink without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 160,
                child: NoteScenePreview(
                  elements: [
                    _stroke(id: 'a'),
                    _stroke(id: 'b', zOrder: 1, x: 200, y: 300),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty page paints nothing and still lays out',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 160,
                child: NoteScenePreview(elements: []),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(NoteScenePreview)),
        const Size(360, 160),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('caps how much of a huge page it paints', (tester) async {
      final elements = [
        for (var i = 0; i < NoteScenePreview.maxElements + 50; i++)
          _stroke(id: '$i', zOrder: i, x: i * 2, y: i * 2),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 160,
                child: NoteScenePreview(elements: elements),
              ),
            ),
          ),
        ),
      );

      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<NoteScenePreviewPainter>()
          .single;

      expect(painter.elements, hasLength(NoteScenePreview.maxElements));
      expect(tester.takeException(), isNull);
    });
  });

  group('repaint', () {
    test('repaints when the page changes', () {
      final first = [_stroke()];
      final painter = NoteScenePreviewPainter(elements: first);

      expect(painter.shouldRepaint(NoteScenePreviewPainter(elements: first)),
          isFalse);
      expect(
        painter.shouldRepaint(NoteScenePreviewPainter(elements: [_stroke()])),
        isTrue,
      );
    });
  });
}
