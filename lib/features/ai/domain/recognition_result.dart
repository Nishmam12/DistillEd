// Result types for handwriting recognition (summarize feature).

import 'dart:ui';

import '../../../domain/model/stroke_point.dart';
import 'meaningfulness_gate.dart';

/// Recognition output for a single page.
class PageRecognition {
  /// Recognized text ('' when the page has no recognizable ink).
  final String text;

  /// Top candidate score. ML Kit semantics: LOWER is more likely; null when
  /// the model returned no score or the page had no ink.
  final double? topScore;

  /// Whether the page contained any ink strokes worth recognizing.
  final bool hasInk;

  const PageRecognition({
    required this.text,
    required this.topScore,
    required this.hasInk,
  });

  const PageRecognition.empty()
      : text = '',
        topScore = null,
        hasInk = false;
}

/// One handwritten line as ML Kit read it.
///
/// The unit the page reader decides on: a line ML Kit read confidently is kept
/// as it is, and one it did not goes to the vision model — by itself, cropped to
/// just that line, rather than re-reading the whole page.
class RecognizedInkLine {
  /// What was recognised, with the segments of a column-split line joined by two
  /// spaces. '' when ML Kit returned nothing for the strokes.
  final String text;

  /// ML Kit's score for each segment recognised on this line (LOWER is more
  /// likely). One per column of a table row, otherwise one. Kept apart rather
  /// than averaged so the page-level score can stay a mean over segments.
  final List<double> segmentScores;

  /// Where the line sits, in scene units.
  final Rect bounds;

  /// The line's strokes — the very point lists the editor holds, not copies, so
  /// a caller can map a line back to its elements by identity.
  final List<List<StrokePoint>> strokes;

  const RecognizedInkLine({
    required this.text,
    required this.segmentScores,
    required this.bounds,
    required this.strokes,
  });

  /// Mean of [segmentScores]; null when ML Kit gave none.
  double? get score => segmentScores.isEmpty
      ? null
      : segmentScores.reduce((a, b) => a + b) / segmentScores.length;
}

/// Recognition output for a whole notebook: page texts concatenated in page
/// order plus the meaningfulness-gate verdict.
class RecognitionOutcome {
  /// Page-order concatenation of non-empty page texts ('\n\n'-joined).
  final String text;

  final List<PageRecognition> pages;

  final GateResult gate;

  const RecognitionOutcome({
    required this.text,
    required this.pages,
    required this.gate,
  });
}
