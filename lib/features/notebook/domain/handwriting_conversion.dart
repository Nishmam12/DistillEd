// Turning selected handwriting into typed text where it was written, and
// levelling handwriting written on a slant. Pure: the selection bar does the
// recognising (ML Kit, on the device) and the undo; this decides what goes
// where.

import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/model/scene_element.dart';
import '../../../editor/render/scene_element_painter.dart';
import '../../ai/domain/handwriting/ink_lines.dart';
import '../../ai/domain/handwriting/ink_trust.dart';
import '../../ai/domain/recognition_result.dart';

/// One handwritten line of the selection, as read.
class ConversionLine {
  /// What ML Kit read. '' when it read nothing: that line stays as ink.
  final String text;

  /// Where the line was written, in scene units.
  final Rect bounds;

  /// The strokes it was read from.
  final List<FreehandElement> strokes;

  /// ML Kit was not sure of it (a poor score, symbol soup, or mathematics it
  /// flattens), so the preview asks for it to be checked.
  final bool unsure;

  const ConversionLine({
    required this.text,
    required this.bounds,
    required this.strokes,
    this.unsure = false,
  });
}

/// The recognised [lines] matched back to the [ink] they came from. The lines
/// carry the very point lists the strokes hold, so the match is by identity,
/// not by position.
List<ConversionLine> conversionLines(
    List<RecognizedInkLine> lines, List<FreehandElement> ink) {
  final byPoints = <List<StrokePoint>, FreehandElement>{
    for (final e in ink) e.points: e,
  };
  // Map keys compare lists by identity, which is exactly what is wanted.
  final heights = [for (final l in lines) l.bounds.height]..sort();
  final median = heights.isEmpty ? 0.0 : heights[heights.length ~/ 2];
  return [
    for (final l in lines)
      ConversionLine(
        text: l.text.trim(),
        bounds: l.bounds,
        strokes: [for (final s in l.strokes) ?byPoints[s]],
        unsure: inkLineNeedsVision(
          text: l.text,
          score: l.score,
          lineHeight: l.bounds.height,
          medianLineHeight: median,
        ),
      ),
  ];
}

/// Font size for typed text standing in for a handwritten line [lineHeight]
/// tall: handwriting's box runs from ascenders to descenders, a little taller
/// than the type that replaces it.
double fontSizeForLine(double lineHeight) =>
    (lineHeight * 0.75).clamp(10.0, 72.0).toDouble();

/// What converting does to the page: the text boxes [added], and the strokes
/// [removed] (none when the handwriting is kept underneath).
typedef Conversion = ({List<SceneElement> removed, List<TextElement> added});

/// One text box per line whose [texts] entry (the preview's, possibly edited)
/// is not blank, at the line's place, in the colour of its ink. A line left
/// blank keeps its ink.
Conversion convertLines(
  List<ConversionLine> lines,
  List<String> texts, {
  required bool keepInk,
  required String Function() newId,
  required int firstZOrder,
  String fontFamily = 'Roboto',
}) {
  assert(texts.length == lines.length);
  final removed = <SceneElement>[];
  final added = <TextElement>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final body = texts[i].trim();
    if (body.isEmpty || line.strokes.isEmpty) continue;
    final b = line.bounds;
    final probe = TextElement(
      id: newId(),
      zOrder: firstZOrder + added.length,
      geometryData: [b.left, b.top, b.right, b.bottom],
      text: body,
      color: line.strokes.first.color,
      fontSize: fontSizeForLine(b.height),
      fontFamily: fontFamily,
    );
    // As wide as the writing, or as the typed line if that is wider, so a
    // short word in a bigger font does not wrap letter by letter.
    final oneLine = SceneElementPainter.layOutText(probe, double.infinity);
    final width = math.max(b.width, oneLine.maxIntrinsicWidth + 4);
    final height = SceneElementPainter.layOutText(probe, width).height;
    added.add(probe.copyWith(
        geometryData: [b.left, b.top, b.left + width, b.top + height]));
    if (!keepInk) removed.addAll(line.strokes);
  }
  return (removed: removed, added: added);
}

/// Smallest slant worth levelling: below it the writing is level enough, and
/// turning it would only jitter.
const double kMinLevelAngle = 1.5 * math.pi / 180;

/// Largest slant taken as a tilted line rather than writing meant to run at
/// an angle (a label up the side of a diagram).
const double kMaxLevelAngle = 30 * math.pi / 180;

/// The handwriting in [ink] with each written line turned level about its own
/// centre. Only strokes that change are returned, in the same order as
/// [ink]; an empty list means everything was already level.
///
/// A line's slant is the least-squares slope through all its points: the ups
/// and downs of the letters cancel out, the drift of the baseline does not. A
/// line much less wide than tall is not a line of writing and is left alone,
/// as are strokes that are themselves rotated.
List<FreehandElement> levelHandwriting(List<FreehandElement> ink) {
  final usable = [
    for (final e in ink)
      if (!e.isEraser && e.rotation == 0 && e.points.length > 1) e
  ];
  final byPoints = <List<StrokePoint>, FreehandElement>{
    for (final e in usable) e.points: e,
  };
  final changed = <String, FreehandElement>{};

  for (final line in groupStrokesIntoLines([for (final e in usable) e.points])) {
    final b = line.bounds;
    if (b.width < b.height * 2) continue;
    final angle = _slant(line.strokes);
    if (angle == null ||
        angle.abs() < kMinLevelAngle ||
        angle.abs() > kMaxLevelAngle) {
      continue;
    }
    final c = b.center;
    final cos = math.cos(-angle), sin = math.sin(-angle);
    for (final s in line.strokes) {
      final e = byPoints[s];
      if (e == null) continue;
      changed[e.id] = e.copyWith(points: [
        for (final p in e.points)
          p.copyWith(
            x: c.dx + (p.x - c.dx) * cos - (p.y - c.dy) * sin,
            y: c.dy + (p.x - c.dx) * sin + (p.y - c.dy) * cos,
          ),
      ]);
    }
  }
  return [for (final e in ink) ?changed[e.id]];
}

/// The angle of the least-squares line through every point, or null when the
/// points have no horizontal spread.
double? _slant(List<List<StrokePoint>> strokes) {
  var n = 0;
  var sx = 0.0, sy = 0.0;
  for (final s in strokes) {
    for (final p in s) {
      n++;
      sx += p.x;
      sy += p.y;
    }
  }
  if (n < 2) return null;
  final mx = sx / n, my = sy / n;
  var sxx = 0.0, sxy = 0.0;
  for (final s in strokes) {
    for (final p in s) {
      sxx += (p.x - mx) * (p.x - mx);
      sxy += (p.x - mx) * (p.y - my);
    }
  }
  if (sxx == 0) return null;
  return math.atan(sxy / sxx);
}
