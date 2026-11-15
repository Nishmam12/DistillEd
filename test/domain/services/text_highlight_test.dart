import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/page_words.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/domain/services/text_highlight.dart';

const _words = PageWords(source: PageWordsSource.pdf, words: [
  PageWord(text: 'one', box: Rect.fromLTRB(0.1, 0.1, 0.3, 0.2), line: 0),
  PageWord(text: 'two', box: Rect.fromLTRB(0.1, 0.3, 0.3, 0.4), line: 1),
]);

ImageElement _image({double rotation = 0, int z = 0, String id = 'a'}) =>
    ImageElement(
      id: id,
      zOrder: z,
      geometryData: const [0, 0, 1000, 100],
      relativeImagePath: 'p.png',
      rotation: rotation,
    );

void main() {
  test('one straight highlighter stroke per line, as tall as the line', () {
    var n = 0;
    final strokes = highlightStrokes(
      image: _image(),
      words: _words,
      indexes: const [0, 1],
      color: 0xFFFFD43B,
      opacity: 1,
      newId: () => 'h${n++}',
      nextZOrder: () => 5,
    );
    expect(strokes, hasLength(2));
    final first = strokes.first;
    expect(first.penKind, PenKind.highlighter);
    expect(first.size, closeTo(10 * kHighlightHeightRatio, 1e-9));
    expect(first.points.every((p) => (p.y - 15).abs() < 1e-9), isTrue);
    // Ends pulled in by half the stroke's width, so the round caps stay on
    // the words (100..300).
    expect(first.points.first.x, closeTo(100 + first.size / 2, 1e-9));
    expect(first.points.last.x, closeTo(300 - first.size / 2, 1e-9));
  });

  test('a turned picture turns the marks with it', () {
    final strokes = highlightStrokes(
      image: _image(rotation: math.pi / 2),
      words: _words,
      indexes: const [0],
      color: 0,
      opacity: 1,
      newId: () => 'h',
      nextZOrder: () => 0,
    );
    final s = strokes.single;
    // Turned a quarter: the mark now runs up and down the page.
    expect((s.points.first.x - s.points.last.x).abs(), lessThan(1e-6));
  });

  test('topImageAt picks the picture on top under the point', () {
    final low = _image(id: 'low', z: 1);
    final high = _image(id: 'high', z: 2);
    expect(topImageAt([low, high], const Offset(500, 50))?.id, 'high');
    expect(topImageAt([low, high], const Offset(500, 500)), isNull);
  });
}
