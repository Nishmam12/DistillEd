// Word-based input budgeting shared by AI features. Callers count and cut
// WORDS; the words↔tokens math lives in [AiRouter]'s budget constants, so
// there is exactly one definition of "fits the local model".

import 'dart:math' as math;

final RegExp _whitespace = RegExp(r'\s+');
final RegExp _blankLine = RegExp(r'\n\s*\n');

int countWords(String text) =>
    text.trim().isEmpty ? 0 : text.trim().split(_whitespace).length;

/// Keeps the first [maxWords] words; returns [text] unchanged when it fits.
String truncateToWords(String text, int maxWords) {
  final words = text.trim().split(_whitespace);
  if (words.length <= maxWords) return text;
  return words.take(maxWords).join(' ');
}

/// Splits [text] into chunks that each fit [maxWords], for chunk-and-reduce
/// over content that exceeds a model's context window. Paragraphs (blank-line
/// separated) are kept whole and packed greedily so chunks stay coherent; a
/// single paragraph longer than the budget is hard-split by words. Returns an
/// empty list for blank input and a single chunk when the whole text fits.
List<String> chunkByWords(String text, int maxWords) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  if (maxWords <= 0 || countWords(trimmed) <= maxWords) return [trimmed];

  final chunks = <String>[];
  final current = StringBuffer();
  var currentWords = 0;

  void flush() {
    if (currentWords == 0) return;
    chunks.add(current.toString());
    current.clear();
    currentWords = 0;
  }

  void append(String paragraph, int words) {
    if (currentWords > 0) current.write('\n\n');
    current.write(paragraph);
    currentWords += words;
  }

  for (final raw in trimmed.split(_blankLine)) {
    final paragraph = raw.trim();
    if (paragraph.isEmpty) continue;
    final words = countWords(paragraph);

    if (words > maxWords) {
      // Too big to co-exist with anything — emit it on its own, hard-split.
      flush();
      final tokens = paragraph.split(_whitespace);
      for (var i = 0; i < tokens.length; i += maxWords) {
        chunks.add(
            tokens.sublist(i, math.min(i + maxWords, tokens.length)).join(' '));
      }
      continue;
    }

    if (currentWords + words > maxWords) flush();
    append(paragraph, words);
  }
  flush();
  return chunks;
}
