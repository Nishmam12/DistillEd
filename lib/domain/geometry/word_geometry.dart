// Geometry of the words on a page picture: from the page to the picture's own
// 0..1 space and back, which word is under a point, the run of words between
// two, and which words a highlighter stroke went over.
//
// Pure: no Flutter widgets, no files. Word boxes are normalised to the picture
// (see `PageWords`), and the picture is an [ImageElement] the user may have
// moved, resized or turned, so everything goes through [toImageUnit] and
// [fromImageUnit].

import 'dart:math' as math;
import 'dart:ui';

import '../model/page_words.dart';
import '../model/scene_element.dart';

/// [scenePoint] in [image]'s own 0..1 space (origin top-left of the picture,
/// before its rotation).
Offset toImageUnit(Offset scenePoint, ImageElement image) {
  final r = image.boundsRect;
  if (r.width <= 0 || r.height <= 0) return const Offset(-1, -1);
  var p = scenePoint;
  if (image.rotation != 0) p = _rotate(p, r.center, -image.rotation);
  return Offset((p.dx - r.left) / r.width, (p.dy - r.top) / r.height);
}

/// The scene point at [unit] (0..1) of [image], with its rotation.
Offset fromImageUnit(Offset unit, ImageElement image) {
  final r = image.boundsRect;
  final p = Offset(r.left + unit.dx * r.width, r.top + unit.dy * r.height);
  return image.rotation == 0 ? p : _rotate(p, r.center, image.rotation);
}

/// The corners of [unitRect] on the page, clockwise from top-left: a rotated
/// picture's words are not axis-aligned on the page.
List<Offset> cornersOnPage(Rect unitRect, ImageElement image) => [
      fromImageUnit(unitRect.topLeft, image),
      fromImageUnit(unitRect.topRight, image),
      fromImageUnit(unitRect.bottomRight, image),
      fromImageUnit(unitRect.bottomLeft, image),
    ];

Offset _rotate(Offset p, Offset c, double angle) {
  final cos = math.cos(angle), sin = math.sin(angle);
  final d = p - c;
  return Offset(c.dx + d.dx * cos - d.dy * sin, c.dy + d.dx * sin + d.dy * cos);
}

/// The index of the word at [unit], or of the nearest one within [tolerance]
/// scene units, or null. [size] is the picture's size on the page, so the
/// tolerance is the same across and down however the picture is stretched.
int? wordAt(
  PageWords words,
  Offset unit, {
  required Size size,
  double tolerance = 24,
}) {
  int? best;
  var bestDistance = double.infinity;
  for (var i = 0; i < words.words.length; i++) {
    final b = words.words[i].box;
    final dx = unit.dx < b.left
        ? b.left - unit.dx
        : unit.dx > b.right
            ? unit.dx - b.right
            : 0.0;
    final dy = unit.dy < b.top
        ? b.top - unit.dy
        : unit.dy > b.bottom
            ? unit.dy - b.bottom
            : 0.0;
    final d = math.sqrt(math.pow(dx * size.width, 2) + math.pow(dy * size.height, 2));
    if (d == 0) return i;
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return bestDistance <= tolerance ? best : null;
}

/// The indexes from [a] to [b] inclusive, in reading order, whichever way the
/// finger went.
List<int> wordsBetween(int a, int b) {
  final lo = math.min(a, b), hi = math.max(a, b);
  return [for (var i = lo; i <= hi; i++) i];
}

/// The words of [indexes], joined as they read: a space between words on a
/// line, a line break between lines.
String textOf(PageWords words, List<int> indexes) {
  final out = StringBuffer();
  int? line;
  for (final i in indexes) {
    final w = words.words[i];
    if (line != null) out.write(w.line == line ? ' ' : '\n');
    out.write(w.text);
    line = w.line;
  }
  return out.toString();
}

/// One box per line covering the words of [indexes] on it, in reading order:
/// what a selection or a clean highlight is drawn as.
List<Rect> lineRuns(PageWords words, List<int> indexes) {
  final runs = <Rect>[];
  int? line;
  for (final i in indexes) {
    final w = words.words[i];
    if (line == w.line && runs.isNotEmpty) {
      runs[runs.length - 1] = runs.last.expandToInclude(w.box);
    } else {
      runs.add(w.box);
    }
    line = w.line;
  }
  return runs;
}

/// Share of a word's width a highlighter stroke has to cover, inside the
/// word's middle band, for the word to count as highlighted.
const double kHighlightCoverage = 0.5;

/// The indexes of the words a stroke through [unitPoints] (in the picture's
/// 0..1 space) went over: the stroke runs through the middle half of the
/// word's height across at least [kHighlightCoverage] of its width. In
/// reading order.
List<int> wordsUnderStroke(PageWords words, List<Offset> unitPoints) {
  if (unitPoints.isEmpty) return const [];
  final samples = _resample(unitPoints, words);
  final out = <int>[];
  for (var i = 0; i < words.words.length; i++) {
    final b = words.words[i].box;
    if (b.width <= 0) continue;
    final bandTop = b.top + b.height * 0.25;
    final bandBottom = b.bottom - b.height * 0.25;
    double? lo, hi;
    for (final p in samples) {
      if (p.dy < bandTop || p.dy > bandBottom) continue;
      if (p.dx < b.left || p.dx > b.right) continue;
      lo = lo == null ? p.dx : math.min(lo, p.dx);
      hi = hi == null ? p.dx : math.max(hi, p.dx);
    }
    if (lo != null && (hi! - lo) / b.width >= kHighlightCoverage) out.add(i);
  }
  return out;
}

/// The stroke with extra points along each segment, spaced well under the
/// smallest word, so a fast or straightened stroke with few points still
/// reads as covering the words it crossed.
List<Offset> _resample(List<Offset> points, PageWords words) {
  var step = 0.005;
  for (final w in words.words) {
    if (w.box.width > 0) step = math.min(step, w.box.width / 8);
  }
  step = math.max(step, 0.0005);
  final out = <Offset>[points.first];
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1], b = points[i];
    final n = ((b - a).distance / step).ceil();
    for (var k = 1; k <= n; k++) {
      out.add(Offset.lerp(a, b, k / n)!);
    }
  }
  return out;
}

/// Words read off a picture by OCR, normalised to it: [lines] in reading
/// order, each with its words in source pixels, over a picture of
/// [imageSize] pixels.
PageWords pageWordsFromOcr(
  List<List<({String text, Rect bounds})>> lines,
  Size imageSize,
) {
  if (imageSize.width <= 0 || imageSize.height <= 0) return PageWords.empty;
  final out = <PageWord>[];
  var line = 0;
  for (final words in lines) {
    var any = false;
    for (final w in words) {
      final text = w.text.trim();
      if (text.isEmpty) continue;
      out.add(PageWord(
        text: text,
        box: Rect.fromLTRB(
          w.bounds.left / imageSize.width,
          w.bounds.top / imageSize.height,
          w.bounds.right / imageSize.width,
          w.bounds.bottom / imageSize.height,
        ),
        line: line,
      ));
      any = true;
    }
    if (any) line++;
  }
  return PageWords(source: PageWordsSource.ocr, words: out);
}
