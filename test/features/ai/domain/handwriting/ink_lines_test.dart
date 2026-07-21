import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/handwriting/ink_lines.dart';
import 'package:inkflow/features/editor/domain/models/stroke_point.dart';

void main() {
  /// A stroke spanning the given box — enough geometry for grouping, which
  /// only ever looks at bounds.
  List<StrokePoint> at(double l, double t, double r, double b, {int? t0}) => [
        StrokePoint(x: l, y: t, t: t0),
        StrokePoint(x: r, y: b, t: t0 == null ? null : t0 + 16),
      ];

  group('groupStrokesIntoLines', () {
    test('no strokes, or only empty ones, produce no lines', () {
      expect(groupStrokesIntoLines([]), isEmpty);
      expect(groupStrokesIntoLines([[], []]), isEmpty);
    });

    test('strokes sharing a vertical band form one line', () {
      final lines = groupStrokesIntoLines([
        at(0, 0, 10, 20),
        at(20, 2, 30, 22),
        at(40, 1, 50, 19),
      ]);
      expect(lines, hasLength(1));
      expect(lines.single.strokes, hasLength(3));
    });

    test('a stroke well below the band starts a new line', () {
      final lines = groupStrokesIntoLines([
        at(0, 0, 10, 20),
        at(0, 100, 10, 120),
      ]);
      expect(lines, hasLength(2));
      expect(lines[0].bounds.top, 0);
      expect(lines[1].bounds.top, 100);
    });

    test('lines come out top-to-bottom and strokes left-to-right', () {
      // Deliberately supplied out of order.
      final lines = groupStrokesIntoLines([
        at(50, 100, 60, 120), // line 2, right
        at(30, 0, 40, 20), // line 1, right
        at(0, 100, 10, 120), // line 2, left
        at(0, 0, 10, 20), // line 1, left
      ]);

      expect(lines, hasLength(2));
      expect(lines[0].bounds.top, 0);
      expect(lines[1].bounds.top, 100);
      expect(lines[0].strokes.map((s) => s.first.x), [0, 30]);
      expect(lines[1].strokes.map((s) => s.first.x), [0, 50]);
    });

    test('a small mark (dot / comma) stays on the line it sits in', () {
      final lines = groupStrokesIntoLines([
        at(0, 0, 10, 20),
        at(12, 8, 13, 9), // a dot — far shorter than the line
      ]);
      expect(lines, hasLength(1),
          reason: 'punctuation must not become a line of its own');
      expect(lines.single.strokes, hasLength(2));
    });

    test('a stray full stop just below a line is folded into it', () {
      // The device bug: punctuation clear of the band became its own "line"
      // and came back from ML Kit as a lone "." — 11 of 23 results were these.
      final lines = groupStrokesIntoLines([
        at(0, 0, 100, 20), // a line of writing
        at(0, 40, 100, 60), // a second line of writing
        at(104, 57, 106, 59), // full stop, sitting just under line 2
      ]);

      expect(lines, hasLength(2),
          reason: 'the stop belongs to a line, not on one of its own');
      expect(lines[1].strokes, hasLength(2));
    });

    test('a stray mark joins the nearest line, not merely the first', () {
      final lines = groupStrokesIntoLines([
        at(0, 0, 100, 20),
        at(0, 200, 100, 220),
        at(104, 217, 106, 219), // nearest the SECOND line
      ]);

      expect(lines, hasLength(2));
      expect(lines[0].strokes, hasLength(1));
      expect(lines[1].strokes, hasLength(2));
    });

    test('an isolated mark far from any line stays on its own', () {
      final lines = groupStrokesIntoLines([
        at(0, 0, 100, 20),
        at(0, 40, 100, 60),
        at(0, 5000, 2, 5002), // nowhere near the writing
      ]);

      expect(lines, hasLength(3),
          reason: 'a distant mark must not be dragged into unrelated text');
    });

    test("a line's bounds are the union of its strokes", () {
      final lines = groupStrokesIntoLines([
        at(0, 0, 10, 20),
        at(20, 5, 35, 25),
      ]);
      expect(lines.single.bounds, const Rect.fromLTRB(0, 0, 35, 25));
    });

    test('an underline is dropped rather than read as a letter', () {
      // The device bug: the underlined heading "Regression Tree vs
      // Classification Tree" came back as "Repso tree is classification Tree".
      final lines = groupStrokesIntoLines([
        at(0, 0, 20, 20),
        at(25, 0, 45, 20),
        at(0, 24, 200, 25), // the underline beneath both
      ]);

      expect(lines.single.strokes, hasLength(2),
          reason: 'the rule carries no text and must not reach the recogniser');
      expect(lines.single.bounds.bottom, 20);
    });

    test('a line of nothing but an underline disappears entirely', () {
      final lines = groupStrokesIntoLines([
        at(0, 0, 20, 20),
        at(25, 0, 45, 20),
        at(0, 200, 300, 201), // a rule ruled well clear of the writing
      ]);
      expect(lines, hasLength(1));
    });

    test('a page of only rules is left alone rather than emptied', () {
      final lines = groupStrokesIntoLines([
        at(0, 0, 300, 1),
        at(0, 40, 300, 41),
      ]);
      expect(lines, hasLength(2),
          reason: 'with no letters to compare against, nothing is a rule');
    });

    test('a long dash between words survives', () {
      final lines = groupStrokesIntoLines([
        at(0, 0, 20, 20),
        at(25, 9, 55, 11), // an em-dash: flat, but nowhere near rule length
        at(60, 0, 80, 20),
      ]);
      expect(lines.single.strokes, hasLength(3));
    });
  });

  group('splitLineAtColumnGaps', () {
    /// One line built straight from stroke boxes.
    InkLine lineOf(List<List<StrokePoint>> strokes) =>
        groupStrokesIntoLines(strokes).single;

    test('a table row splits into one segment per column', () {
      // The device bug: "Topic  Classification  Regression" reached the
      // recogniser as a single line and came back as "ape assiiions".
      final segments = splitLineAtColumnGaps(lineOf([
        at(0, 0, 50, 20), // "Topic"
        at(300, 0, 450, 20), // "Classification"
        at(700, 0, 800, 20), // "Regression"
      ]));

      expect(segments, hasLength(3));
      expect(segments.map((s) => s.bounds.left), [0, 300, 700]);
    });

    test('ordinary word spacing does not split a sentence', () {
      final segments = splitLineAtColumnGaps(lineOf([
        at(0, 0, 40, 20),
        at(48, 0, 90, 20), // an 8-unit gap against a 20-unit line height
        at(98, 0, 140, 20),
      ]));
      expect(segments, hasLength(1));
      expect(segments.single.strokes, hasLength(3));
    });

    test('a segment keeps only its own strokes and bounds', () {
      final segments = splitLineAtColumnGaps(lineOf([
        at(0, 0, 50, 20),
        at(10, 22, 40, 24), // sits under the first column, same line
        at(400, 0, 450, 20),
      ]));

      expect(segments, hasLength(2));
      expect(segments.first.strokes, hasLength(2));
      expect(segments.first.bounds, const Rect.fromLTRB(0, 0, 50, 24));
      expect(segments.last.strokes, hasLength(1));
    });

    test('a single-stroke line is returned unchanged', () {
      final line = lineOf([at(0, 0, 50, 20)]);
      expect(splitLineAtColumnGaps(line), [same(line)]);
    });

    test('a wider gapRatio tolerates wider columns', () {
      final strokes = [at(0, 0, 50, 20), at(100, 0, 150, 20)];
      expect(
          splitLineAtColumnGaps(lineOf(strokes), gapRatio: 2.0), hasLength(2));
      expect(
          splitLineAtColumnGaps(lineOf(strokes), gapRatio: 5.0), hasLength(1));
    });
  });

  group('normalizeInkLine', () {
    test('translates to the origin and scales height to the target', () {
      final line = groupStrokesIntoLines([at(100, 200, 110, 220)]).single;
      final norm = normalizeInkLine(line, targetHeight: 100);

      // Height 20 -> 100 means a 5x scale.
      expect(norm.height, closeTo(100, 1e-9));
      expect(norm.width, closeTo(50, 1e-9));

      final pts = norm.strokes.single;
      expect(pts.first.x, closeTo(0, 1e-9));
      expect(pts.first.y, closeTo(0, 1e-9));
      expect(pts.last.x, closeTo(50, 1e-9));
      expect(pts.last.y, closeTo(100, 1e-9));
    });

    test('aspect ratio is preserved', () {
      final line = groupStrokesIntoLines([at(0, 0, 40, 10)]).single;
      final norm = normalizeInkLine(line, targetHeight: 100);
      expect(norm.width / norm.height, closeTo(40 / 10, 1e-9));
    });

    test('ink written at a huge zoomed-out scale normalizes to the same shape',
        () {
      // The device bug: the same letters written while zoomed out span far
      // larger scene coordinates. After normalisation they must be identical.
      final small =
          normalizeInkLine(groupStrokesIntoLines([at(0, 0, 10, 20)]).single);
      final huge = normalizeInkLine(
          groupStrokesIntoLines([at(5000, 9000, 5100, 9200)]).single);

      expect(huge.width, closeTo(small.width, 1e-9));
      expect(huge.height, closeTo(small.height, 1e-9));
      expect(huge.strokes.single.last.x,
          closeTo(small.strokes.single.last.x, 1e-9));
    });

    test('point timing is carried through untouched', () {
      final line = groupStrokesIntoLines([at(0, 0, 10, 20, t0: 5000)]).single;
      final norm = normalizeInkLine(line);
      expect(norm.strokes.single.map((p) => p.t), [5000, 5016]);
    });

    test('a flat line has no height to scale by and is left alone', () {
      final line = groupStrokesIntoLines([at(0, 5, 10, 5)]).single;
      final norm = normalizeInkLine(line);

      expect(norm.height, 0);
      expect(norm.width, 10, reason: 'scale falls back to 1.0, not infinity');
      expect(norm.strokes.single.first.y, 0);
    });
  });
}
