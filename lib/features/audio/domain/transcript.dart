// What was SAID in a lecture, as text with timestamps
// (docs/AI_PIPELINE_PLAN.md, item 14).
//
// A transcript is kept as segments — each with the span of the recording it came
// from — so it can be listed and played from, and rendered into the page text
// the AI reads. That rendering carries the timestamps in the words themselves
// (`[23:10] …`), which is what lets an answer say "minute 23 of Monday's
// lecture" and lets a source card find its way back to that moment, all through
// the ordinary text pipeline: no second index, no schema.

import 'lecture_recording.dart';

/// One transcribed stretch of a recording.
class TranscriptSegment {
  final int startMs;
  final int endMs;
  final String text;

  const TranscriptSegment({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  Map<String, Object?> toJson() =>
      {'startMs': startMs, 'endMs': endMs, 'text': text};

  factory TranscriptSegment.fromJson(Map<String, Object?> json) {
    final start = json['startMs'];
    final end = json['endMs'];
    final text = json['text'];
    if (start is! int || end is! int || text is! String) {
      throw const FormatException('Not a transcript segment');
    }
    return TranscriptSegment(startMs: start, endMs: end, text: text);
  }
}

/// A whole lecture's transcript.
class Transcript {
  /// The Whisper language code it was transcribed as (`en`, `bn`, …).
  final String language;

  /// Which speech model wrote it — a transcript is only as good as its model, and
  /// a better one may be worth re-running for.
  final String model;

  final List<TranscriptSegment> segments;

  /// Stretches of the recording the model could not read. Zero for a transcript
  /// that covers the whole lecture; kept so a gap is never mistaken for silence.
  final int skippedWindows;

  const Transcript({
    required this.language,
    required this.model,
    required this.segments,
    this.skippedWindows = 0,
  });

  bool get isEmpty => segments.isEmpty;

  Map<String, Object?> toJson() => {
        'language': language,
        'model': model,
        'segments': [for (final s in segments) s.toJson()],
        if (skippedWindows > 0) 'skippedWindows': skippedWindows,
      };

  /// Throws [FormatException] for anything that is not a transcript.
  factory Transcript.fromJson(Map<String, Object?> json) {
    final language = json['language'];
    final model = json['model'];
    final segments = json['segments'];
    if (language is! String || model is! String || segments is! List) {
      throw const FormatException('Not a transcript');
    }
    final skipped = json['skippedWindows'];
    return Transcript(
      language: language,
      model: model,
      skippedWindows: skipped is int ? skipped : 0,
      segments: [
        for (final s in segments)
          TranscriptSegment.fromJson((s as Map).cast<String, Object?>()),
      ],
    );
  }

  /// The lecture as the text the AI reads: a line saying when it was recorded and
  /// that it is speech, then one `[m:ss] words` line per segment. Empty when
  /// nothing intelligible was said.
  ///
  /// A segment that is only punctuation or a noise marker ("♪♪", "...") is left
  /// out: it is what a model writes for silence and music, not something said.
  String asPageText({required DateTime recordedAt}) {
    final lines = [
      for (final s in segments)
        if (_hasWords(s.text))
          '[${LectureRecording.formatOffset(s.startMs)}] ${s.text.trim()}',
    ];
    if (lines.isEmpty) return '';
    return [
      'Lecture recorded ${formatLectureWhen(recordedAt)} '
          '(spoken words, transcribed on this device):',
      ...lines,
      if (skippedWindows > 0)
        '(${skippedWindows == 1 ? 'One stretch' : '$skippedWindows stretches'} '
            'of this recording could not be transcribed.)',
    ].join('\n');
  }
}

bool _hasWords(String text) =>
    RegExp(r'[\p{L}\p{M}\p{N}]', unicode: true).hasMatch(text);

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// "Mon, Oct 12 at 10:05" — no intl dependency for one line.
String formatLectureWhen(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day} '
      'at ${two(d.hour)}:${two(d.minute)}';
}

final RegExp _timestamp = RegExp(r'\[((?:\d{1,2}:)?\d{1,2}):(\d{2})\]');

/// How far into a lecture the passage [text] came from — the first `[m:ss]` or
/// `[h:mm:ss]` stamp in it, in milliseconds — or null when it has none (a page of
/// ordinary notes). A bare `[2]` is a citation, not a time.
int? lectureOffsetOf(String text) {
  for (final match in _timestamp.allMatches(text)) {
    final seconds = int.parse(match.group(2)!);
    if (seconds > 59) continue;
    final head = match.group(1)!.split(':').map(int.parse).toList();
    final hours = head.length == 2 ? head[0] : 0;
    final minutes = head.length == 2 ? head[1] : head[0];
    if (head.length == 2 && minutes > 59) continue;
    return ((hours * 60 + minutes) * 60 + seconds) * 1000;
  }
  return null;
}
