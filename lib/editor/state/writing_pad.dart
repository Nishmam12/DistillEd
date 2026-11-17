// The easy writing pad (Samsung Notes' "easy writing pad"), for writing on a
// phone: a large lined pad under the page, and a target box on the page.
// Ink written in the pad is scaled down into the box; the box moves on as the
// pad fills. Pure state and maths here; the pad and the box are drawn by
// `writing_pad_panel.dart`.

import 'dart:ui';

import 'package:flutter_riverpod/legacy.dart';

import '../../domain/model/stroke_point.dart';

class WritingPad {
  /// Where the next ink goes: the top-left of the box, in page units.
  final Offset target;

  /// Where a new line starts, in page units (the box's left edge when the pad
  /// was opened or the box last placed).
  final double lineStartX;

  /// The height of one line of writing on the page.
  final double lineHeight;

  const WritingPad({
    required this.target,
    required this.lineStartX,
    this.lineHeight = 36,
  });

  /// [p], written in a pad [padHeight] pixels tall, on the page.
  Offset toPage(Offset p, double padHeight) =>
      target + p * (lineHeight / padHeight);

  /// [points] from the pad, on the page.
  List<StrokePoint> strokeToPage(List<StrokePoint> points, double padHeight) => [
        for (final p in points)
          () {
            final at = toPage(Offset(p.x, p.y), padHeight);
            return StrokePoint(
                x: at.dx,
                y: at.dy,
                pressure: p.pressure,
                simulatePressure: p.simulatePressure,
                t: p.t);
          }(),
      ];

  /// The box moved past ink reaching [inkRight] pixels into the pad, plus a
  /// gap of a third of a line: what Space and a full pad do.
  WritingPad advancedPast(double inkRight, double padHeight) => WritingPad(
        target: Offset(
            target.dx + inkRight * (lineHeight / padHeight) + lineHeight / 3,
            target.dy),
        lineStartX: lineStartX,
        lineHeight: lineHeight,
      );

  /// The box at the start of the next line.
  WritingPad newLine() => WritingPad(
        target: Offset(lineStartX, target.dy + lineHeight * 1.25),
        lineStartX: lineStartX,
        lineHeight: lineHeight,
      );

  /// The box put at [at] by a tap on the page; new lines start under it.
  WritingPad placedAt(Offset at) =>
      WritingPad(target: at, lineStartX: at.dx, lineHeight: lineHeight);
}

/// The open writing pad, or null when it is closed.
final writingPadProvider = StateProvider<WritingPad?>((ref) => null);
