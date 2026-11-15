// Clean highlighter marks over words on a page picture: one straight stroke per
// line, as tall as the line. What "Highlight" on a text selection lays down,
// and what a hand-drawn highlighter stroke over printed text snaps to.

import 'dart:ui';

import '../geometry/word_geometry.dart';
import '../model/page_words.dart';
import '../model/scene_element.dart';

/// How much taller than the words a clean highlight is drawn, so ascenders and
/// descenders sit inside it.
const double kHighlightHeightRatio = 1.15;

/// One highlighter stroke per line of [indexes] (words of [words] on
/// [image]), in [color] and [opacity]. Each runs along the middle of its line;
/// its ends are pulled in by half its width, since a stroke's round caps
/// reach that far past its end points.
List<FreehandElement> highlightStrokes({
  required ImageElement image,
  required PageWords words,
  required List<int> indexes,
  required int color,
  required double opacity,
  required String Function() newId,
  required int Function() nextZOrder,
}) {
  final r = image.boundsRect;
  if (r.width <= 0 || r.height <= 0) return const [];
  final out = <FreehandElement>[];
  for (final run in lineRuns(words, indexes)) {
    final size = run.height * r.height * kHighlightHeightRatio;
    if (size <= 0) continue;
    final inset = (size / 2) / r.width;
    final y = run.center.dy;
    final left = run.width > inset * 2 ? run.left + inset : run.center.dx;
    final right = run.width > inset * 2 ? run.right - inset : run.center.dx;
    final a = fromImageUnit(Offset(left, y), image);
    final b = fromImageUnit(Offset(right, y), image);
    out.add(FreehandElement(
      id: newId(),
      zOrder: nextZOrder(),
      points: [
        StrokePoint(x: a.dx, y: a.dy, pressure: 1),
        StrokePoint(
            x: (a.dx + b.dx) / 2, y: (a.dy + b.dy) / 2, pressure: 1),
        StrokePoint(x: b.dx, y: b.dy, pressure: 1),
      ],
      color: color,
      size: size,
      opacity: opacity,
      penKind: PenKind.highlighter,
    ));
  }
  return out;
}

/// The picture on top under [point] among [elements], if any: what a text
/// selection or a highlighter stroke at that point is about.
ImageElement? topImageAt(List<SceneElement> elements, Offset point) {
  ImageElement? best;
  for (final e in elements) {
    if (e is! ImageElement) continue;
    final u = toImageUnit(point, e);
    if (u.dx < 0 || u.dy < 0 || u.dx > 1 || u.dy > 1) continue;
    if (best == null || e.zOrder >= best.zOrder) best = e;
  }
  return best;
}
