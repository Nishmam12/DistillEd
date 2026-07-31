// Is what the local model just produced actually usable?
//
// [AiRouter] decides WHERE a request runs, from reachability, the user's opt-in
// and the input length. It has never looked at what came back. That is the gap
// this closes: a 2B-parameter model on a phone does not fail by throwing, it
// fails by producing something confident and wrong — an empty reply, the same
// clause four times, a paragraph that ignores the retrieved passages entirely,
// or a number that appears nowhere in the student's notes. All four are shown
// to the student as settled teaching.
//
// Pure, and deliberately conservative. Every check here is a heuristic, and a
// false positive costs a needless cloud round-trip (or a low-confidence badge
// on a perfectly good answer), so each is tuned to fire on output that is
// obviously broken rather than merely mediocre. The thresholds are named
// constants for exactly that reason: they are judgement calls, not measurements,
// and the next person to tune them should see that immediately.
//
// What is deliberately NOT here: any judgement of whether the answer is a GOOD
// explanation. That needs a model, costs what the generation cost, and is the
// thing the cloud tier is for. This only catches broken.

/// Why an output failed the check. Ordered roughly by how certain the signal
/// is — [empty] is unambiguous, [unsupportedClaim] is the most heuristic.
enum QualityIssue {
  /// Nothing, or so little there is nothing to read.
  empty,

  /// The same phrase or sentence repeated past the point of coherence — the
  /// classic small-model degeneration loop.
  repetition,

  /// Almost no distinct words: "the the the", or one word padded out.
  degenerate,

  /// A grounded answer that shares essentially no vocabulary with the passages
  /// it was supposed to be drawn from.
  ignoredSources,

  /// A grounded answer states a number, date or name that appears in none of
  /// the passages.
  unsupportedClaim,
}

extension QualityIssueMessage on QualityIssue {
  /// One line a low-confidence badge can show. Written for a student, and
  /// honest about the fact that the app cannot vouch for the answer.
  String get message => switch (this) {
        QualityIssue.empty => 'The on-device model returned nothing.',
        QualityIssue.repetition =>
          'The on-device model got stuck repeating itself.',
        QualityIssue.degenerate =>
          "The on-device model's answer doesn't read as an answer.",
        QualityIssue.ignoredSources =>
          "This answer doesn't seem to be based on the passages it found.",
        QualityIssue.unsupportedClaim =>
          'This answer states specifics that are not in your notes.',
      };
}

/// The verdict on one generation.
class QualityVerdict {
  /// Null when the output looks fine.
  final QualityIssue? issue;

  const QualityVerdict.ok() : issue = null;
  const QualityVerdict.failed(QualityIssue this.issue);

  bool get passed => issue == null;
}

/// What the output was supposed to be grounded in, when it was supposed to be
/// grounded in anything.
///
/// [sourcePassages] empty means an ungrounded feature (Explain teaching a topic,
/// a summary of a page): the grounding checks are skipped entirely rather than
/// being run against nothing, which would fail every output.
class QualityContext {
  final List<String> sourcePassages;

  /// The refusal a grounded feature is allowed to emit. A correct refusal is a
  /// GOOD answer — short, source-free, and exactly the behaviour the prompt
  /// asked for — so it must never be read as degenerate output and escalated
  /// to the cloud, where it would be re-answered from world knowledge.
  final String? allowedRefusal;

  const QualityContext({
    this.sourcePassages = const [],
    this.allowedRefusal,
  });

  static const ungrounded = QualityContext();

  bool get isGrounded => sourcePassages.isNotEmpty;
}

/// Below this many words, an answer is treated as no answer. Two words can be a
/// legitimate reply to "what year?", so this is set at the point where there is
/// genuinely nothing to read.
const int kMinAnswerWords = 3;

/// A phrase of this many words repeating this many times is a loop, not
/// emphasis. Three repeats of a five-word phrase is the shortest pattern that
/// is never accidental in real prose.
const int kLoopPhraseWords = 5;
const int kLoopRepeats = 3;

/// Distinct words as a share of total words, below which the text is padding.
/// Real English prose sits far above this even with heavy repetition of a topic
/// word; 0.25 is reached essentially only by degeneration.
const double kMinTypeTokenRatio = 0.25;

/// Text this short is exempt from the ratio check — "yes, it does" is a
/// perfectly good answer with a poor ratio.
const int kTypeTokenMinWords = 25;

/// Share of an answer's content words that must also appear in the passages,
/// for a grounded answer. Low on purpose: a good answer paraphrases, and the
/// point is to catch an answer written from world knowledge, not to demand
/// quotation.
const double kMinSourceOverlap = 0.18;

/// Grounded answers shorter than this skip the overlap check — a one-sentence
/// answer legitimately shares few words with a 250-word passage.
const int kOverlapMinWords = 12;

final RegExp _wordPattern = RegExp(r"[a-zA-Z0-9][a-zA-Z0-9'’\-]*");

/// Checks [output] against [context].
///
/// Returns the FIRST issue found, in the order the enum declares — a reply that
/// is both empty and unsourced is reported as empty, which is the more useful
/// thing to tell someone.
QualityVerdict checkOutputQuality(
  String output, {
  QualityContext context = QualityContext.ungrounded,
}) {
  final text = output.trim();
  if (text.isEmpty) return const QualityVerdict.failed(QualityIssue.empty);

  // A grounded refusal is a correct answer and is exempt from everything below.
  final refusal = context.allowedRefusal;
  if (refusal != null && _isRefusal(text, refusal)) {
    return const QualityVerdict.ok();
  }

  final words = _words(text);
  if (words.length < kMinAnswerWords) {
    return const QualityVerdict.failed(QualityIssue.empty);
  }

  if (_loops(words)) {
    return const QualityVerdict.failed(QualityIssue.repetition);
  }

  if (words.length >= kTypeTokenMinWords &&
      words.toSet().length / words.length < kMinTypeTokenRatio) {
    return const QualityVerdict.failed(QualityIssue.degenerate);
  }

  if (!context.isGrounded) return const QualityVerdict.ok();

  final sourceWords = <String>{};
  for (final passage in context.sourcePassages) {
    sourceWords.addAll(_words(passage));
  }

  if (words.length >= kOverlapMinWords) {
    final content = [
      for (final w in words)
        if (!_stopWords.contains(w)) w
    ];
    if (content.isNotEmpty) {
      final shared = content.where(sourceWords.contains).length;
      if (shared / content.length < kMinSourceOverlap) {
        return const QualityVerdict.failed(QualityIssue.ignoredSources);
      }
    }
  }

  // Numbers are the specifics a student is most likely to copy down and most
  // likely to be harmed by. A figure the passages never mention was either
  // invented or arithmetic the model did unasked, and either way it is not
  // grounded. Years and small counts that appear in the question itself are
  // covered because the question's words reach here through the passages the
  // retriever matched to it.
  //
  // Citation markers are stripped first. [NotesQa] ORDERS the model to write
  // "[1]", "[2]" — those numbers refer to the passage list, not to anything in
  // the notes, so scanning them would flag every correctly-cited answer as
  // making an unsupported claim.
  for (final number in _numbersIn(_withoutCitations(text))) {
    if (!sourceWords.contains(number)) {
      return const QualityVerdict.failed(QualityIssue.unsupportedClaim);
    }
  }

  return const QualityVerdict.ok();
}

/// Lower-cased word tokens.
List<String> _words(String text) => [
      for (final m in _wordPattern.allMatches(text.toLowerCase())) m[0]!,
    ];

/// Drops `[1]`-style passage citations — see the call site.
String _withoutCitations(String text) =>
    text.replaceAll(RegExp(r'\[\s*\d+(?:\s*[,;]\s*\d+)*\s*\]'), ' ');

/// Bare numeric tokens (not part of an identifier like "h2o").
Iterable<String> _numbersIn(String text) sync* {
  for (final m in RegExp(r'(?<![a-zA-Z0-9])\d+(?:[.,]\d+)*(?![a-zA-Z0-9])')
      .allMatches(text)) {
    yield m[0]!.toLowerCase();
  }
}

/// True when any window of [kLoopPhraseWords] consecutive words occurs
/// [kLoopRepeats] or more times.
bool _loops(List<String> words) {
  if (words.length < kLoopPhraseWords * kLoopRepeats) return false;
  final counts = <String, int>{};
  for (var i = 0; i + kLoopPhraseWords <= words.length; i++) {
    final key = words.sublist(i, i + kLoopPhraseWords).join(' ');
    final n = (counts[key] ?? 0) + 1;
    if (n >= kLoopRepeats) return true;
    counts[key] = n;
  }
  return false;
}

/// Matches a refusal leniently — a model rarely echoes a canned line byte for
/// byte, and the same lenient rule the Ask notifier already uses applies here.
bool _isRefusal(String text, String refusal) {
  final a = text.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '');
  final b = refusal.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '');
  return a.contains(b) || (b.contains(a) && a.length > b.length * 0.6);
}

/// Words too common to say anything about grounding. Short and fixed rather
/// than a real stop list: this only has to stop "the" and "is" from carrying an
/// overlap score.
const Set<String> _stopWords = {
  'a', 'an', 'and', 'are', 'as', 'at', 'be', 'been', 'but', 'by', 'can', 'do',
  'does', 'for', 'from', 'has', 'have', 'how', 'i', 'if', 'in', 'into', 'is',
  'it', 'its', 'of', 'on', 'or', 'that', 'the', 'their', 'them', 'then',
  'there', 'these', 'they', 'this', 'to', 'was', 'were', 'what', 'when',
  'which', 'while', 'why', 'will', 'with', 'you', 'your', //
};
