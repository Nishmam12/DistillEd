import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/geometry/word_geometry.dart';
import 'package:margo/domain/model/page_words.dart';
import 'package:margo/domain/model/scene_element.dart';

/// Two lines: "The quick fox" on line 0, "jumps over" on line 1.
const _words = PageWords(source: PageWordsSource.pdf, words: [
  PageWord(text: 'The', box: Rect.fromLTRB(0.10, 0.10, 0.18, 0.14), line: 0),
  PageWord(text: 'quick', box: Rect.fromLTRB(0.20, 0.10, 0.32, 0.14), line: 0),
  PageWord(text: 'fox', box: Rect.fromLTRB(0.34, 0.10, 0.42, 0.14), line: 0),
  PageWord(text: 'jumps', box: Rect.fromLTRB(0.10, 0.18, 0.24, 0.22), line: 1),
  PageWord(text: 'over', box: Rect.fromLTRB(0.26, 0.18, 0.36, 0.22), line: 1),
]);

ImageElement _image({double rotation = 0}) => ImageElement(
      id: 'pdf',
      zOrder: 0,
      geometryData: const [100, 200, 900, 1300], // 800 x 1100
      relativeImagePath: 'notes/1/imports/p.png',
      rotation: rotation,
    );

void main() {
  group('mapping between the page and the picture', () {
    test('a point round-trips, and lands where the picture is', () {
      final img = _image();
      expect(fromImageUnit(const Offset(0, 0), img), const Offset(100, 200));
      expect(fromImageUnit(const Offset(1, 1), img), const Offset(900, 1300));
      final u = toImageUnit(const Offset(500, 750), img);
      expect(u.dx, closeTo(0.5, 1e-9));
      expect(u.dy, closeTo(0.5, 1e-9));
    });

    test('a turned picture: the round trip still holds', () {
      final img = _image(rotation: math.pi / 2);
      const unit = Offset(0.2, 0.7);
      final back = toImageUnit(fromImageUnit(unit, img), img);
      expect(back.dx, closeTo(unit.dx, 1e-9));
      expect(back.dy, closeTo(unit.dy, 1e-9));
      // A quarter turn about the centre moves the top-left corner.
      expect(fromImageUnit(Offset.zero, img), isNot(const Offset(100, 200)));
    });
  });

  test('wordAt finds the word under the point, or the nearest one close by',
      () {
    const size = Size(800, 1100);
    expect(wordAt(_words, const Offset(0.25, 0.12), size: size), 1);
    // Just past the end of "fox": within tolerance.
    expect(wordAt(_words, const Offset(0.44, 0.12), size: size), 2);
    // Far from any word.
    expect(wordAt(_words, const Offset(0.9, 0.9), size: size), isNull);
  });

  test('wordsBetween goes in reading order either way', () {
    expect(wordsBetween(3, 1), [1, 2, 3]);
    expect(wordsBetween(0, 0), [0]);
  });

  test('textOf joins words with spaces and lines with breaks', () {
    expect(textOf(_words, [1, 2, 3]), 'quick fox\njumps');
  });

  test('lineRuns gives one box per line', () {
    final runs = lineRuns(_words, [1, 2, 3, 4]);
    expect(runs, hasLength(2));
    expect(runs[0], const Rect.fromLTRB(0.20, 0.10, 0.42, 0.14));
    expect(runs[1], const Rect.fromLTRB(0.10, 0.18, 0.36, 0.22));
  });

  group('wordsUnderStroke', () {
    test('a stroke along the middle of a line covers those words', () {
      final hit = wordsUnderStroke(
          _words, const [Offset(0.19, 0.12), Offset(0.43, 0.121)]);
      expect(hit, [1, 2]);
    });

    test('a stroke that only clips the top of the words covers none', () {
      final hit = wordsUnderStroke(
          _words, const [Offset(0.1, 0.101), Offset(0.42, 0.101)]);
      expect(hit, isEmpty);
    });

    test('a short stroke over part of a word does not count it', () {
      final hit = wordsUnderStroke(
          _words, const [Offset(0.20, 0.12), Offset(0.23, 0.12)]);
      expect(hit, isEmpty);
    });

    test('a stroke away from any text covers nothing', () {
      expect(
          wordsUnderStroke(
              _words, const [Offset(0.5, 0.6), Offset(0.8, 0.6)]),
          isEmpty);
    });
  });

  test('pageWordsFromOcr normalises and numbers the lines', () {
    final words = pageWordsFromOcr([
      [
        (text: 'Hello', bounds: const Rect.fromLTRB(10, 20, 60, 40)),
        (text: ' ', bounds: Rect.zero),
      ],
      [],
      [(text: 'world', bounds: const Rect.fromLTRB(10, 50, 70, 70))],
    ], const Size(100, 200));
    expect(words.source, PageWordsSource.ocr);
    expect(words.words.map((w) => w.text), ['Hello', 'world']);
    expect(words.words[0].box, const Rect.fromLTRB(0.1, 0.1, 0.6, 0.2));
    expect(words.words.map((w) => w.line), [0, 1]);
  });
}
