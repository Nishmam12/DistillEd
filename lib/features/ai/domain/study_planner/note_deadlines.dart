// Dates the student wrote in their notes that are worth counting down to
// (docs/AI_PIPELINE_PLAN.md, item 16): "Quiz 2 on Oct 14", "final exam next
// Thursday".
//
// Reading a date out of free text is ML Kit's job (`DateFinder`, behind a port so
// everything here is tested without a device); deciding WHICH dates matter is
// this file's. A notebook is full of dates that are not deadlines — "the treaty
// was signed on Oct 14" — so a date is only offered when the line it sits on
// also names something to prepare for. The rest of the planner stays what it was:
// a deterministic schedule from real signals, no model deciding it.

/// Finds the calendar dates written in a piece of text.
abstract class DateFinder {
  /// The dates in [text], resolved against [now] so relative ones ("next
  /// Thursday") mean the one after today. Only dates precise to a day or finer —
  /// "in October" is not a day to count down to. Empty when there are none or
  /// the finder is unavailable.
  Future<List<DateTime>> find(String text, {required DateTime now});
}

/// Thrown by a [DateFinder] that cannot run at all — its model is missing and
/// could not be fetched. Unlike a line it merely cannot read, this fails the
/// whole lookup: every other line would fail the same way, and "no dates found"
/// would be a lie.
class DateFinderUnavailable implements Exception {
  const DateFinderUnavailable([this.reason]);
  final String? reason;

  @override
  String toString() => 'DateFinderUnavailable: ${reason ?? 'unavailable'}';
}

/// A date in the notes that looks like something to prepare for.
class NoteDeadline {
  /// The day, at midnight local time.
  final DateTime date;

  /// The line it was written on — "Quiz 2 on Oct 14" — shown so the student can
  /// tell what the date is for.
  final String label;

  /// The page it was found on.
  final int pageId;

  const NoteDeadline({
    required this.date,
    required this.label,
    required this.pageId,
  });
}

/// Longest label kept, ellipsis included.
const int kDeadlineLabelMax = 80;

/// How far ahead a date may be. The planner's date picker stops at a year, and
/// its countdown is capped far sooner (`StudyHorizon.examDayCap`).
const int kDeadlineHorizonDays = 365;

/// Words that make a date worth offering. English only — ML Kit's entity model
/// has no Bangla — and whole words only ("finally" is not "final").
///
/// ponytail: a cue must be on the same line or sentence as its date, so a
/// deadline wrapped across two lines is missed. Widen to a line of context if
/// that turns out to matter.
final RegExp _deadlineCue = RegExp(
  r'\b(exams?|tests?|quiz(?:zes)?|midterms?|finals?|deadlines?|due|'
  r'assignments?|submissions?|submit|presentations?|vivas?)\b',
  caseSensitive: false,
);

/// A sentence ends at ". " only before a capital: "Oct. 14" is a date, not a
/// full stop.
final RegExp _sentenceBreak = RegExp(r'(?<=[.!?])\s+(?=[A-Z])');

/// The upcoming deadlines written in [pageTexts] (page id → its text), soonest
/// first, at most [limit].
///
/// Only lines that name a deadline word are sent to [finder], so a long notebook
/// costs a handful of model calls, not one per line. A line the finder fails on
/// is skipped — it costs that line, never the rest — unless the finder is
/// [DateFinderUnavailable], which ends the lookup.
Future<List<NoteDeadline>> findNoteDeadlines({
  required Map<int, String> pageTexts,
  required DateFinder finder,
  required DateTime now,
  int limit = 5,
}) async {
  final today = DateTime(now.year, now.month, now.day);
  final last = DateTime(today.year, today.month, today.day + kDeadlineHorizonDays);

  final found = <NoteDeadline>[];
  final seen = <String>{};

  for (final page in pageTexts.entries) {
    for (final unit in _units(page.value)) {
      if (!_deadlineCue.hasMatch(unit)) continue;

      final List<DateTime> dates;
      try {
        dates = await finder.find(unit, now: now);
      } on DateFinderUnavailable {
        rethrow;
      } catch (_) {
        continue;
      }

      final label = _labelOf(unit);
      for (final when in dates) {
        final day = DateTime(when.year, when.month, when.day);
        if (day.isBefore(today) || day.isAfter(last)) continue;
        // The same line copied onto another page is one deadline, not two.
        if (!seen.add('${day.millisecondsSinceEpoch}|${label.toLowerCase()}')) {
          continue;
        }
        found.add(NoteDeadline(date: day, label: label, pageId: page.key));
      }
    }
  }

  // Dart's sort is not stable; the index keeps same-day deadlines in the order
  // they were found.
  final ordered = [for (var i = 0; i < found.length; i++) (i, found[i])]
    ..sort((a, b) {
      final byDate = a.$2.date.compareTo(b.$2.date);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  return [for (final (_, deadline) in ordered.take(limit)) deadline];
}

/// The lines and sentences of [text], trimmed, blanks dropped — the unit a
/// deadline word and its date have to share.
Iterable<String> _units(String text) sync* {
  for (final line in text.split('\n')) {
    for (final sentence in line.split(_sentenceBreak)) {
      final trimmed = sentence.trim();
      if (trimmed.isNotEmpty) yield trimmed;
    }
  }
}

/// [unit] with its whitespace collapsed (handwriting recognition leaves runs of
/// it), cut to [kDeadlineLabelMax] with an ellipsis.
String _labelOf(String unit) {
  final flat = unit.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.length <= kDeadlineLabelMax) return flat;
  return '${flat.substring(0, kDeadlineLabelMax - 1).trimRight()}…';
}
