// Which handwritten lines ML Kit can be trusted on, and which are worth loading
// the big vision model for.
//
// The page reader runs ML Kit Digital Ink first — milliseconds, no model load —
// and sends Gemma only the lines this says it should not trust. A wrong
// "trusted" costs a misread line in the page text; a wrong "needs vision" costs
// a 3.6–17 s model load. So the bar is set to catch what ML Kit reliably gets
// wrong (symbol soup, low-confidence reads, two-dimensional maths) and to leave
// ordinary prose, numbering and dates alone.
//
// Pure, so it is tested without ML Kit or a device.

import '../meaningfulness_gate.dart';

/// The bar one line's ML Kit reading must clear: mostly letters or digits (not
/// symbol soup like `:::::::`), and confident enough. Unlike the page-level gate
/// it asks for a single word, because a line can be one, and it counts digits as
/// content, so a bare page number or a "1." is not sent to the vision model.
///
/// ML Kit's score is "lower is more likely" and model-dependent, so the
/// threshold wants calibrating on a device; it starts at the same lenient 8.0
/// the page-level gate uses.
const MeaningfulnessGate kInkLineGate = MeaningfulnessGate(
  minWords: 1,
  minAlphaRatio: 0.5,
  countDigits: true,
);

/// A line this many times taller than the page's typical line is
/// two-dimensional — a stacked fraction, an integral with limits, a matrix —
/// and one-dimensional recognition flattens it. A heading written a bit larger
/// than the body stays well under it.
const double kTallLineRatio = 2.2;

/// True when ML Kit's reading of a line should NOT be taken as it is, and the
/// line is worth the vision model.
///
/// A line that read as no text at all is never refined: ink that yields nothing
/// is usually a doodle or a diagram, which the figure pass owns, rather than
/// handwriting for the OCR model to guess at. (A page where NOTHING reads is a
/// different matter — the caller sends that whole.)
bool inkLineNeedsVision({
  required String text,
  required double? score,
  required double lineHeight,
  required double medianLineHeight,
  MeaningfulnessGate gate = kInkLineGate,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;

  final verdict =
      gate.evaluate(trimmed, topScores: [if (score != null) score]);
  if (!verdict.passed) return true;

  if (looksLikeMath(trimmed)) return true;

  return medianLineHeight > 0 && lineHeight > medianLineHeight * kTallLineRatio;
}

/// Symbols that, anywhere in a line, mean mathematics rather than prose.
final Set<int> _mathSymbols = {
  for (final rune in '=^√∫∑∏∂∇∞±×÷≤≥≈≠≡∈∉⊂⊆∪∩∀∃→⇒'.runes) rune,
};

/// Operators that make a line of digits arithmetic. `/` and `-` are not here:
/// they are just as much a date ("12/03/2024"), a fraction written inline
/// ("3/4") or a hyphen, and ML Kit reads those perfectly well.
const String _strongOperators = '+*<>';

/// Everything that counts toward a line being "mostly numbers and operators".
const String _operators = '+-*/=^<>';

/// Whether [text] reads as mathematics: a mathematical symbol, a Greek letter
/// (which in a student's notes is almost always a variable or a constant), or a
/// line that is mostly digits and operators with at least one real arithmetic
/// operator among them.
///
/// A bare number is not maths — it is a page number — and neither are the
/// parentheses of a "(a)" list marker, which is why neither counts here.
bool looksLikeMath(String text) {
  var nonSpace = 0;
  var digitsAndOperators = 0;
  var hasStrongOperator = false;

  for (final rune in text.runes) {
    if (_mathSymbols.contains(rune)) return true;
    // The Greek and Coptic block.
    if (rune >= 0x0370 && rune <= 0x03FF) return true;

    final char = String.fromCharCode(rune);
    if (char.trim().isEmpty) continue;
    nonSpace++;
    final isDigit = rune >= 0x30 && rune <= 0x39;
    if (isDigit || _operators.contains(char)) digitsAndOperators++;
    if (_strongOperators.contains(char)) hasStrongOperator = true;
  }

  return hasStrongOperator &&
      nonSpace > 0 &&
      digitsAndOperators / nonSpace > 0.5;
}
