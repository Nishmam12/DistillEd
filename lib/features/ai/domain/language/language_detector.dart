// What language a piece of recognised text is in — or whether it is any language
// at all (docs/AI_PIPELINE_PLAN.md, item 18).
//
// ML Kit's text recognition reads Latin script (and a few others) but not
// Bengali. Handed a page of Bengali it does not fail: it answers with letters
// that are no language, and that noise would become the page's text. Language ID
// is the cheap, on-device way to tell: real text is identified, noise is not.
//
// Deliberately NOT used to choose the handwriting model. Language ID goes by
// script, so any run of Bengali-script junk comes back as Bengali — it can say
// "this is not language", but it cannot confirm that a model read the right
// thing, which is what picking a model from its own output would need.

/// "No language found" — the tag ML Kit answers when nothing reaches its
/// confidence threshold.
const String kUndetermined = 'und';

/// Letters a text needs before "no language found" means the text is not
/// language, rather than that it was too short to tell. Language ID is unreliable
/// on a few words: "F = ma" is not noise.
const int kMinLettersToJudge = 24;

/// Identifies the language of a text.
abstract class LanguageDetector {
  /// The BCP-47 tag of [text]'s main language (`en`, `bn`, `bn-Latn`, …),
  /// [kUndetermined] when it is no language, or null when the detector could not
  /// run — a different answer from "no language", which is why it is not `und`.
  Future<String?> identify(String text);
}

/// Whether [text] is gibberish: long enough to judge, and no language found.
///
/// False whenever it cannot be sure — too short, a detector that could not run,
/// one that threw. This guard exists to drop noise; a broken guard must never
/// drop text.
Future<bool> isUnreadable(String text, LanguageDetector detector) async {
  if (letterCount(text) < kMinLettersToJudge) return false;
  try {
    return await detector.identify(text) == kUndetermined;
  } catch (_) {
    return false;
  }
}

/// How many letters [text] has, counting the marks that attach to them. Marks
/// count because in Indic scripts the vowel signs are combining marks, not
/// letters: a Bengali sentence of thirty characters has far fewer than thirty
/// `\p{L}`.
int letterCount(String text) =>
    RegExp(r'[\p{L}\p{M}]', unicode: true).allMatches(text).length;
