// Word-based input budgeting shared by AI features. Callers count and cut
// WORDS; the words↔tokens math lives in [AiRouter]'s budget constants, so
// there is exactly one definition of "fits the local model".

final RegExp _whitespace = RegExp(r'\s+');

int countWords(String text) =>
    text.trim().isEmpty ? 0 : text.trim().split(_whitespace).length;

/// Keeps the first [maxWords] words; returns [text] unchanged when it fits.
String truncateToWords(String text, int maxWords) {
  final words = text.trim().split(_whitespace);
  if (words.length <= maxWords) return text;
  return words.take(maxWords).join(' ');
}
