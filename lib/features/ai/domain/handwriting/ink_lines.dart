// Turns a page of loose ink strokes into something ML Kit can actually read.
//
// Two rules live here, both pure so they're testable without ML Kit or a
// device:
//
//  * GROUPING — ML Kit's digital-ink recogniser expects the contents of one
//    writing area (a line, or a short block), not a whole infinite canvas.
//    Handing it every stroke on a page at once is why recognition came back as
//    `:::::::::` with a hopeless score on device: it sees one enormous smear of
//    marks. Strokes are clustered into handwritten lines instead, and each line
//    is recognised on its own.
//
//  * NORMALISATION — stroke coordinates are raw scene units on an infinite
//    canvas, so their scale depends entirely on the zoom the user happened to
//    write at (a 20px-tall letter written at 14% zoom is ~143 scene units).
//    ML Kit has no way to know that, and `WritingArea` is documented as being
//    "in the same units as used in StrokePoint" — so each line is translated to
//    the origin and scaled to a consistent height before recognition, and the
//    writing area is reported to match.

import 'dart:math' as math;
import 'dart:ui';

import '../../../editor/domain/models/stroke_point.dart';

/// A handwritten line: the strokes sitting on it, ordered left-to-right.
class InkLine {
  /// Each entry is one stroke's points, in drawing order.
  final List<List<StrokePoint>> strokes;

  /// Union of every stroke's bounds.
  final Rect bounds;

  const InkLine({required this.strokes, required this.bounds});
}

/// One line, translated and scaled for recognition.
class NormalizedInk {
  final List<List<StrokePoint>> strokes;

  /// Writing-area extent, in the same units as the returned points.
  final double width;
  final double height;

  const NormalizedInk({
    required this.strokes,
    required this.width,
    required this.height,
  });
}

/// Height every line is scaled to before recognition. The absolute value
/// doesn't matter to ML Kit — only that ink arrives at a consistent, natural
/// writing scale instead of whatever the canvas zoom produced.
const double kInkTargetLineHeight = 100.0;

/// Bounding box of [points], or null when there aren't any.
Rect? inkStrokeBounds(List<StrokePoint> points) {
  if (points.isEmpty) return null;
  var left = points.first.x;
  var right = left;
  var top = points.first.y;
  var bottom = top;
  for (final p in points) {
    if (p.x < left) left = p.x;
    if (p.x > right) right = p.x;
    if (p.y < top) top = p.y;
    if (p.y > bottom) bottom = p.y;
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

/// Groups [strokes] into handwritten lines, top-to-bottom, each line's strokes
/// ordered left-to-right.
///
/// A stroke joins the line being built when its centre sits inside that line's
/// band, or when their vertical spans overlap by at least half the shorter of
/// the two. Between them those two rules keep dots, commas and other small
/// marks attached to the line they belong to instead of each becoming a line of
/// its own, while a genuinely new line of writing — which neither sits in the
/// previous band nor meaningfully overlaps it — starts a new group. Empty
/// strokes are dropped, as are rules and underlines.
List<InkLine> groupStrokesIntoLines(List<List<StrokePoint>> strokes) {
  var measured = <_Measured>[];
  for (final s in strokes) {
    final b = inkStrokeBounds(s);
    if (b != null) measured.add((points: s, bounds: b));
  }
  if (measured.isEmpty) return const [];

  // Before grouping, not after: an underline spans a whole heading, so leaving
  // it in would drag the band across everything it underlines.
  measured = _withoutRules(measured);

  // Centre-first, not top-first: ascender height varies wildly in handwriting,
  // so the top edge is a poor proxy for which line a stroke is on. A stroke's
  // centre tracks its baseline far more closely.
  measured.sort((a, b) => a.bounds.center.dy.compareTo(b.bounds.center.dy));

  final groups = <List<_Measured>>[];
  var current = [measured.first];
  var band = measured.first.bounds;

  for (final stroke in measured.skip(1)) {
    final overlap = math.min(band.bottom, stroke.bounds.bottom) -
        math.max(band.top, stroke.bounds.top);
    final shorter = math.min(band.height, stroke.bounds.height);
    // A zero-height mark (a dot, or a perfectly flat dash) counts as on-line
    // whenever it falls inside the band at all.
    final needed = shorter <= 0 ? 0.0 : shorter * 0.5;
    // Sitting inside the band is enough on its own: a dot or comma overlaps
    // almost nothing vertically, but its centre is squarely on its line.
    final centred = stroke.bounds.center.dy >= band.top &&
        stroke.bounds.center.dy <= band.bottom;

    if (centred || (overlap >= needed && overlap > 0)) {
      current.add(stroke);
      band = band.expandToInclude(stroke.bounds);
    } else {
      groups.add(current);
      current = [stroke];
      band = stroke.bounds;
    }
  }
  groups.add(current);

  return [for (final g in _foldStrayMarks(groups)) _toInkLine(g)];
}

/// Splits one line wherever a horizontal gap is far too wide to be a word
/// space — the columns of a hand-drawn table.
///
/// Grouping puts everything sharing a vertical band on one line, which is right
/// for prose but wrong for a table row: on device `Topic  Classification
/// Regression` reached the recogniser as a single line and came back as `ape
/// assiiions`. Each column is its own writing area, so each is recognised
/// separately. [gapRatio] is measured against the line's own height, well above
/// the ~0.3x a word space takes.
List<InkLine> splitLineAtColumnGaps(InkLine line, {double gapRatio = 2.0}) {
  if (line.strokes.length < 2 || line.bounds.height <= 0) return [line];
  final threshold = line.bounds.height * gapRatio;

  // Strokes arrive left-to-right (see [_toInkLine]), so one pass suffices.
  final segments = <List<_Measured>>[];
  var current = <_Measured>[];
  var reach = double.negativeInfinity;

  for (final points in line.strokes) {
    final bounds = inkStrokeBounds(points);
    if (bounds == null) continue;
    if (current.isNotEmpty && bounds.left - reach > threshold) {
      segments.add(current);
      current = [];
      reach = double.negativeInfinity;
    }
    current.add((points: points, bounds: bounds));
    if (bounds.right > reach) reach = bounds.right;
  }
  if (current.isNotEmpty) segments.add(current);

  return [for (final s in segments) _toInkLine(s)];
}

/// Drops underlines, rules and strike-throughs: strokes far wider than the
/// page's letters are tall, and far too flat to hold letters themselves.
///
/// They carry no text, but the recogniser still tries to read them — on device
/// the underlined heading "Regression Tree vs Classification Tree" came back as
/// "Repso tree is classification Tree". The yardstick is the median stroke
/// height, i.e. roughly one letter; a rule runs across many. A page that is
/// nothing but rules is left alone rather than emptied.
List<_Measured> _withoutRules(List<_Measured> strokes) {
  final heights = [for (final s in strokes) s.bounds.height]..sort();
  final letter = heights[heights.length ~/ 2];
  if (letter <= 0) return strokes;

  final kept = [
    for (final s in strokes)
      if (!(s.bounds.width > letter * 2.5 && s.bounds.height < letter * 0.15))
        s,
  ];
  return kept.isEmpty ? strokes : kept;
}

/// Median group height — the page's typical line height, and the yardstick for
/// "unusually short" (a stray mark). Zero when there is no vertical extent.
double _medianHeight(List<List<_Measured>> groups) {
  if (groups.isEmpty) return 0;
  final heights = [for (final g in groups) _groupBounds(g).height]..sort();
  return heights[heights.length ~/ 2];
}

/// Folds stray marks — a full stop, comma or dash sitting just clear of a
/// line's band — into the nearest real line.
///
/// Without this each one is recognised on its own and comes back as a
/// standalone `.` or `-`, which is confidently correct and completely useless:
/// on device these accounted for 11 of 23 recognised "lines" and dumped pure
/// punctuation into the text the AI reads. A group is considered stray when
/// it's far shorter than a typical line, and it only merges when a real line
/// is close enough to plausibly own it.
List<List<_Measured>> _foldStrayMarks(List<List<_Measured>> groups) {
  if (groups.length < 2) return groups;

  final median = _medianHeight(groups);
  if (median <= 0) return groups;

  final real = <List<_Measured>>[];
  final strays = <List<_Measured>>[];
  for (final g in groups) {
    (_groupBounds(g).height < median * 0.4 ? strays : real).add(g);
  }
  if (strays.isEmpty || real.isEmpty) return groups;

  // Mutable copies so a stray can be absorbed into whichever line owns it.
  final merged = [
    for (final g in real) [...g]
  ];
  final bounds = [for (final g in real) _groupBounds(g)];

  for (final stray in strays) {
    final strayBounds = _groupBounds(stray);
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < merged.length; i++) {
      final d = (strayBounds.center.dy - bounds[i].center.dy).abs();
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }

    // Too far from any line to belong to one — keep it as its own group rather
    // than dragging an unrelated mark into someone else's text.
    if (bestDistance > median * 1.5) {
      merged.add([...stray]);
      bounds.add(strayBounds);
      continue;
    }

    merged[best].addAll(stray);
    bounds[best] = bounds[best].expandToInclude(strayBounds);
  }

  // Re-sort: absorbing strays can reorder lines vertically.
  final order = [for (var i = 0; i < merged.length; i++) i]
    ..sort((a, b) => bounds[a].top.compareTo(bounds[b].top));
  return [for (final i in order) merged[i]];
}

/// Union bounds of a group's strokes.
Rect _groupBounds(List<_Measured> group) =>
    group.map((s) => s.bounds).reduce((a, b) => a.expandToInclude(b));

InkLine _toInkLine(List<_Measured> group) {
  final ordered = [...group]
    ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
  return InkLine(
    strokes: [for (final s in ordered) s.points],
    bounds: _groupBounds(ordered),
  );
}

typedef _Measured = ({List<StrokePoint> points, Rect bounds});

/// Translates [line] to the origin and scales it so its height becomes
/// [targetHeight], preserving aspect ratio and each point's timing.
///
/// Timing is carried through untouched: ML Kit uses pen dynamics, and rescaling
/// space says nothing about when the strokes happened.
NormalizedInk normalizeInkLine(
  InkLine line, {
  double targetHeight = kInkTargetLineHeight,
}) {
  final b = line.bounds;
  // A line with no vertical extent (a lone underline) has no meaningful height
  // to scale by; leaving it at 1.0 is better than dividing by ~0.
  final scale = b.height > 1e-6 ? targetHeight / b.height : 1.0;

  return NormalizedInk(
    strokes: [
      for (final stroke in line.strokes)
        [
          for (final p in stroke)
            p.copyWith(
              x: (p.x - b.left) * scale,
              y: (p.y - b.top) * scale,
            ),
        ],
    ],
    width: b.width * scale,
    height: b.height * scale,
  );
}
