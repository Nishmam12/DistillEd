// Result types for handwriting recognition (summarize feature).

import '../services/meaningfulness_gate.dart';

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
