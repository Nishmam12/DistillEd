// Checks a figure description against text read some OTHER way.
//
// A vision model rates its own reading ("confidence": 0.9), and a small model
// is confident about readings it invented. But most figures carry labels, and
// the page's labels are usually known independently: typed text is exact, a
// PDF page has its own text layer, and handwriting was already read by ML Kit.
// A description whose labels appear nowhere in that text was not read off this
// figure, whatever the model says about itself.
//
// Pure. The verdict is a share (0–1) that the caller stores on the figure and
// the quality bar uses to decide whether to ask a stronger model.

import 'figure.dart';

final RegExp _token = RegExp(r'[\p{L}\p{N}]+', unicode: true);

List<String> _tokens(String text) => [
      for (final m in _token.allMatches(text.toLowerCase()))
        if (m[0]!.length >= 2) m[0]!,
    ];

/// Fewer words than this on the page and there is too little to judge by.
const int _kMinReferenceTokens = 3;

/// The share of what [figure] names — its title and its series/node labels —
/// that is found in [referenceText], or null when there is nothing to check
/// (no reference text to speak of, or a description that names nothing).
///
/// Matching forgives what handwriting recognition gets wrong: a word counts
/// when it is in the reference exactly, differs from a reference word by one
/// letter, or shares a long prefix with one ("cost" / "costs").
double? groundingOf(FigureDescription figure, String referenceText) {
  final reference = _tokens(referenceText).toSet();
  if (reference.length < _kMinReferenceTokens) return null;

  final claims = <String>[
    if (figure.title.trim().isNotEmpty) figure.title,
    for (final s in figure.series) s.label,
  ];
  var total = 0, confirmed = 0;
  for (final claim in claims) {
    final words = _tokens(claim);
    if (words.isEmpty) continue;
    total++;
    final found = words.where((w) => _inReference(w, reference)).length;
    if (found * 2 >= words.length) confirmed++;
  }
  return total == 0 ? null : confirmed / total;
}

bool _inReference(String word, Set<String> reference) {
  if (reference.contains(word)) return true;
  if (word.length < 4) return false;
  for (final r in reference) {
    if ((r.length - word.length).abs() > 1) continue;
    if (_withinOneEdit(word, r)) return true;
  }
  return false;
}

/// Whether [a] and [b] differ by at most one inserted, removed or changed
/// letter.
bool _withinOneEdit(String a, String b) {
  if (a == b) return true;
  final short = a.length <= b.length ? a : b;
  final long = a.length <= b.length ? b : a;
  if (long.length - short.length > 1) return false;
  var i = 0, j = 0, edits = 0;
  while (i < short.length && j < long.length) {
    if (short[i] == long[j]) {
      i++;
      j++;
      continue;
    }
    if (++edits > 1) return false;
    if (short.length == long.length) i++;
    j++;
  }
  return true;
}
