// Guards the LLM from gibberish: recognized text must look like real writing
// before it is ever sent to summarization.

/// Why the gate rejected the text (null on pass).
enum GateFailure {
  /// Fewer than [MeaningfulnessGate.minWords] words.
  tooShort,

  /// Too few tokens contain letters — likely scribbles recognized as symbols.
  lowAlphaRatio,

  /// Recognition candidate scores indicate low confidence. ML Kit digital-ink
  /// scores are "lower is more likely" and are designed to be thresholded.
  lowConfidence,
}

class GateResult {
  final bool passed;
  final GateFailure? failure;

  const GateResult.pass()
      : passed = true,
        failure = null;

  const GateResult.fail(GateFailure this.failure) : passed = false;
}

/// Heuristic plausibility check on recognized handwriting.
///
/// Thresholds are constructor-injectable: [maxAvgScore] in particular is
/// model-dependent (ML Kit: "a particular threshold value for a given
/// application will stay valid after a model update") and should be calibrated
/// on-device; the default is deliberately lenient.
class MeaningfulnessGate {
  /// Minimum word count for a summarizable note (~10 per spec).
  final int minWords;

  /// Minimum fraction of whitespace-separated tokens containing at least one
  /// letter (any script — matched with Unicode letter classes so Bengali
  /// counts the same as Latin).
  final double minAlphaRatio;

  /// Maximum acceptable average top-candidate score across pages. ML Kit
  /// scores: lower = more likely, so an average ABOVE this fails. Pages
  /// without scores are skipped; if no page has a score the rule is skipped.
  final double maxAvgScore;

  const MeaningfulnessGate({
    this.minWords = 10,
    this.minAlphaRatio = 0.5,
    this.maxAvgScore = 8.0,
  });

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  GateResult evaluate(String text, {List<double> topScores = const []}) {
    final tokens =
        text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    if (tokens.length < minWords) {
      return const GateResult.fail(GateFailure.tooShort);
    }

    final alphaTokens = tokens.where((t) => _letter.hasMatch(t)).length;
    if (alphaTokens / tokens.length < minAlphaRatio) {
      return const GateResult.fail(GateFailure.lowAlphaRatio);
    }

    if (topScores.isNotEmpty) {
      final avg = topScores.reduce((a, b) => a + b) / topScores.length;
      if (avg > maxAvgScore) {
        return const GateResult.fail(GateFailure.lowConfidence);
      }
    }

    return const GateResult.pass();
  }
}
