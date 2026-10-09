// Word-based input budgeting shared by AI features. Callers count and cut
// WORDS; the words↔tokens math lives here and in [AiRouter]'s budget constants,
// so there is exactly one definition of "fits the local model".
//
// A budget "word" is an English-sized one (~1.35 tokens). A word in a script the
// tokenizer splits finely (Bangla, Devanagari and the other Indic scripts) costs
// more of the budget, so a 250-word chunk or a 4096-token prompt does not
// overrun its model's window just because the page is not English.

import 'dart:math' as math;

final RegExp _whitespace = RegExp(r'\s+');
final RegExp _blankLine = RegExp(r'\n\s*\n');

/// Tokens per English word, the unit a budget word is measured in.
const double kLatinTokensPerWord = 1.35;

// ponytail: estimates (~0.5 tokens per Indic character, ~0.29 per other), not a
// tokenizer; measure with the model's own tokenizer and adjust if chunks still
// truncate. CJK is not handled: it has no spaces, so word splitting cannot cut it.
const double _indicTokensPerChar = 0.5;
const double _otherTokensPerChar = 0.29;

bool _isIndic(int rune) => rune >= 0x0900 && rune <= 0x0DFF;

/// How much of a word budget [word] uses: 1.0 for any word without Indic
/// characters (so English behaves exactly as it always has), more for Indic ones.
double wordCost(String word) {
  var indic = 0;
  var other = 0;
  for (final rune in word.runes) {
    _isIndic(rune) ? indic++ : other++;
  }
  if (indic == 0) return 1.0;
  final tokens = indic * _indicTokensPerChar + other * _otherTokensPerChar;
  return math.max(1.0, tokens / kLatinTokensPerWord);
}

int countWords(String text) =>
    text.trim().isEmpty ? 0 : text.trim().split(_whitespace).length;

/// [text]'s size in budget words — what to compare against a word budget. Equals
/// [countWords] for English; larger for Indic scripts.
int budgetWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  var cost = 0.0;
  for (final word in trimmed.split(_whitespace)) {
    cost += wordCost(word);
  }
  return cost.ceil();
}

/// Keeps the first [maxWords] budget words; returns [text] unchanged when it fits.
String truncateToWords(String text, int maxWords) {
  if (budgetWords(text) <= maxWords) return text;
  var cost = 0.0;
  var kept = 0;
  var end = 0;
  // Cut the original string at a word boundary so newlines are kept.
  for (final m in RegExp(r'\S+').allMatches(text)) {
    cost += wordCost(m[0]!);
    if (cost > maxWords && kept > 0) break;
    kept++;
    end = m.end;
  }
  return text.substring(text.length - text.trimLeft().length, end);
}

/// Splits [text] into chunks that each fit [maxWords], for chunk-and-reduce
/// over content that exceeds a model's context window. Paragraphs (blank-line
/// separated) are kept whole and packed greedily so chunks stay coherent; a
/// single paragraph longer than the budget is hard-split by words. Returns an
/// empty list for blank input and a single chunk when the whole text fits.
List<String> chunkByWords(String text, int maxWords) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  if (maxWords <= 0 || budgetWords(trimmed) <= maxWords) return [trimmed];

  final chunks = <String>[];
  final current = StringBuffer();
  var currentWords = 0.0;

  void flush() {
    if (currentWords == 0) return;
    chunks.add(current.toString());
    current.clear();
    currentWords = 0;
  }

  void append(String paragraph, num words) {
    if (currentWords > 0) current.write('\n\n');
    current.write(paragraph);
    currentWords += words;
  }

  for (final raw in trimmed.split(_blankLine)) {
    final paragraph = raw.trim();
    if (paragraph.isEmpty) continue;
    final words = budgetWords(paragraph);

    if (words > maxWords) {
      // Too big to co-exist with anything — emit it on its own, hard-split.
      flush();
      final tokens = paragraph.split(_whitespace);
      final piece = <String>[];
      var pieceCost = 0.0;
      for (final token in tokens) {
        final cost = wordCost(token);
        if (pieceCost + cost > maxWords && piece.isNotEmpty) {
          chunks.add(piece.join(' '));
          piece.clear();
          pieceCost = 0;
        }
        piece.add(token);
        pieceCost += cost;
      }
      if (piece.isNotEmpty) chunks.add(piece.join(' '));
      continue;
    }

    if (currentWords + words > maxWords) flush();
    append(paragraph, words);
  }
  flush();
  return chunks;
}
