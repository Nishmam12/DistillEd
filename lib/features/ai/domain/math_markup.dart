// Splitting model output into prose and maths.
//
// The models are told to write every formula as LaTeX between `$…$` (inline) or
// `$$…$$` (its own line) — see [kMathMarkup] in `tutor_voice.dart`. This is the
// reader for that convention: it turns one string into an ordered list of
// segments, so a view can draw the prose as text and hand only the formulas to
// the LaTeX renderer.
//
// Pure and widget-free on purpose. Segmenting is fiddly string work with a lot
// of edge cases (a lone dollar sign in "$5", an unclosed delimiter from a
// truncated stream, `$$` inside `$…$`), and those are exactly the cases worth
// having tests for. The widget on top of this stays trivial.
//
// The guiding rule for every ambiguous case: when in doubt, it is PROSE. A
// formula shown as its source text is ugly but readable; a sentence swallowed
// into a maths renderer is gone.

/// One run of either prose or maths.
class MathSegment {
  /// For prose, the text itself. For maths, the LaTeX WITHOUT its delimiters —
  /// that is what a renderer wants.
  final String text;

  /// True when [text] is LaTeX to be rendered as maths.
  final bool isMath;

  /// True when this was a `$$…$$` block, which gets its own centred line.
  /// Always false when [isMath] is false.
  final bool isBlock;

  const MathSegment.text(this.text)
      : isMath = false,
        isBlock = false;

  const MathSegment.math(this.text, {this.isBlock = false}) : isMath = true;

  @override
  String toString() =>
      isMath ? '${isBlock ? 'block' : 'inline'}($text)' : 'text($text)';

  @override
  bool operator ==(Object other) =>
      other is MathSegment &&
      other.text == text &&
      other.isMath == isMath &&
      other.isBlock == isBlock;

  @override
  int get hashCode => Object.hash(text, isMath, isBlock);
}

/// Splits [source] into prose and maths segments, in order.
///
/// Recombining every segment's text with its delimiters restores [source]
/// exactly, so nothing the model wrote can be lost by rendering.
///
/// What is deliberately NOT treated as maths:
///   • `$` followed by a digit or whitespace — "it cost $5" and "$ x" are
///     currency and typos far more often than they are maths, and a student
///     writing about money would otherwise watch half a sentence disappear.
///   • An unclosed delimiter. Mid-stream, `The answer is $\frac{1}{2` is a
///     formula that has not finished arriving; showing it as prose for one
///     frame is right, and swallowing the rest of the reply is not.
///   • An empty delimiter pair (`$$`), which renders as nothing at all.
List<MathSegment> parseMathSegments(String source) {
  if (source.isEmpty) return const [];

  final segments = <MathSegment>[];
  final prose = StringBuffer();
  var i = 0;

  void flushProse() {
    if (prose.isEmpty) return;
    segments.add(MathSegment.text(prose.toString()));
    prose.clear();
  }

  while (i < source.length) {
    if (source[i] != r'$' || _isEscaped(source, i)) {
      prose.write(source[i]);
      i++;
      continue;
    }

    // Block first: `$$` must not be read as an empty inline pair.
    final isBlock = i + 1 < source.length && source[i + 1] == r'$';
    final delimiter = isBlock ? r'$$' : r'$';
    final contentStart = i + delimiter.length;

    if (!isBlock && !_opensInlineMath(source, contentStart)) {
      prose.write(source[i]);
      i++;
      continue;
    }

    final end = _findClosing(source, contentStart, delimiter);
    if (end < 0) {
      // Unclosed — the rest is prose, including this dollar sign.
      prose.write(source[i]);
      i++;
      continue;
    }

    // Kept untrimmed so a segment list reassembles into the source byte for
    // byte; LaTeX ignores surrounding whitespace, so the renderer doesn't care.
    final latex = source.substring(contentStart, end);
    if (latex.trim().isEmpty) {
      // `$$` / `$ $` with nothing in it: keep it as written rather than
      // rendering an empty formula box.
      prose.write(source.substring(i, end + delimiter.length));
    } else {
      flushProse();
      segments.add(MathSegment.math(latex, isBlock: isBlock));
    }
    i = end + delimiter.length;
  }

  flushProse();
  return segments;
}

/// True when [source] contains at least one maths segment — lets a view skip
/// the segmented renderer entirely for ordinary prose, which is most replies.
bool containsMath(String source) {
  for (final segment in parseMathSegments(source)) {
    if (segment.isMath) return true;
  }
  return false;
}

/// [source] with the maths delimiters removed and the commonest LaTeX spelled
/// as readable text.
///
/// For the one surface that cannot host a renderer: the Knowledge Graph draws
/// its node captions with a [TextPainter] inside a [CustomPainter], and
/// `flutter_math_fork` renders as a WIDGET — there is no way to paint it into a
/// canvas. Rebuilding the graph out of positioned widgets to gain formula
/// labels would trade a cheap single-pass paint for hundreds of laid-out
/// widgets, on the screen most likely to hold a lot of nodes.
///
/// So a graph label loses the typesetting but keeps the meaning: `$E = mc^2$`
/// reads as `E = mc²` rather than as a dollar-fenced backslash soup. Concept
/// names are short phrases far more often than they are formulas, which is what
/// makes this the proportionate trade rather than a hole.
String mathAsPlainText(String source) {
  final buffer = StringBuffer();
  for (final segment in parseMathSegments(source)) {
    buffer.write(segment.isMath ? _readableLatex(segment.text) : segment.text);
  }
  return buffer.toString();
}

/// The handful of LaTeX forms that actually turn up in a concept name, spelled
/// as text. Anything else is left as written — visibly LaTeX, but readable, and
/// never worse than the `\frac{}{}` it would otherwise show.
String _readableLatex(String latex) {
  var out = latex;
  out = out.replaceAllMapped(
      RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}'), (m) => '${m[1]}/${m[2]}');
  out = out.replaceAllMapped(
      RegExp(r'\\sqrt\{([^{}]*)\}'), (m) => '√(${m[1]})');
  out = out.replaceAllMapped(RegExp(r'\^\{?(\d)\}?'), (m) => _superscript(m[1]!));
  for (final entry in _greek.entries) {
    out = out.replaceAll(entry.key, entry.value);
  }
  out = out.replaceAll(r'\times', '×').replaceAll(r'\cdot', '·');
  out = out.replaceAll(r'\pm', '±').replaceAll(r'\approx', '≈');
  out = out.replaceAll(r'\le', '≤').replaceAll(r'\ge', '≥');
  // Leftover grouping braces carry no meaning once the commands are gone.
  return out.replaceAll('{', '').replaceAll('}', '').trim();
}

const List<String> _superscripts = [
  '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹' //
];

String _superscript(String digit) => _superscripts[int.parse(digit)];

const Map<String, String> _greek = {
  r'\alpha': 'α',
  r'\beta': 'β',
  r'\gamma': 'γ',
  r'\delta': 'δ',
  r'\Delta': 'Δ',
  r'\theta': 'θ',
  r'\lambda': 'λ',
  r'\mu': 'μ',
  r'\pi': 'π',
  r'\sigma': 'σ',
  r'\Sigma': 'Σ',
  r'\phi': 'φ',
  r'\omega': 'ω',
  r'\Omega': 'Ω',
};

/// Whether the `$` before [contentStart] plausibly opens inline maths.
///
/// `$5.00` and `$ ` are not maths. A letter, a backslash, a brace — those are.
/// A digit is the hard case, and it is the one that actually bites: a sentence
/// with two prices in it ("the book cost \$30 and the notes cost \$5") has two
/// dollar signs that pair up perfectly, so a naive reader silently renders
/// "30 and the notes cost " as a formula and eats half the sentence.
///
/// So a digit-led run is maths only when its body carries an actual operator or
/// LaTeX character. `$2x + 1$` qualifies; `$30 and the notes cost $` does not,
/// letters and all.
bool _opensInlineMath(String source, int contentStart) {
  if (contentStart >= source.length) return false;
  final c = source[contentStart];
  if (c == ' ' || c == '\n' || c == '\t') return false;
  if (_isDigit(c)) {
    final close = _findClosing(source, contentStart, r'$');
    if (close < 0) return false;
    final body = source.substring(contentStart, close);
    return body.contains(_mathematicalCharacter);
  }
  return true;
}

/// Characters that mark a run as an expression rather than a price. Bare
/// letters are excluded deliberately — see [_opensInlineMath].
final RegExp _mathematicalCharacter = RegExp(r'[\\^_{}=+*/<>]');

/// Index of the closing [delimiter] at or after [from], or -1.
///
/// A closing `$` is not accepted when it is escaped, and a newline-newline
/// (paragraph break) ends the search: an unclosed inline `$` should not swallow
/// the rest of a multi-paragraph answer looking for a partner.
int _findClosing(String source, int from, String delimiter) {
  for (var i = from; i <= source.length - delimiter.length; i++) {
    if (delimiter == r'$' && source.startsWith('\n\n', i)) return -1;
    if (!source.startsWith(delimiter, i)) continue;
    if (_isEscaped(source, i)) continue;
    // An inline scan must not stop on the first `$` of a `$$`.
    if (delimiter == r'$' &&
        i + 1 < source.length &&
        source[i + 1] == r'$' &&
        i == from) {
      continue;
    }
    return i;
  }
  return -1;
}

/// True when the character at [index] is preceded by an odd run of backslashes,
/// i.e. `\$` — a literal dollar sign the author escaped.
bool _isEscaped(String source, int index) {
  var backslashes = 0;
  for (var i = index - 1; i >= 0 && source[i] == r'\'; i--) {
    backslashes++;
  }
  return backslashes.isOdd;
}

bool _isDigit(String c) => c.codeUnitAt(0) ^ 0x30 <= 9;
