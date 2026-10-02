// Where lecture transcripts live: a JSON file beside each recording's audio.

import 'dart:convert';
import 'dart:io';

import '../../../core/constants/storage_paths.dart';
import '../domain/lecture_recording.dart';
import '../domain/transcript.dart';

abstract class TranscriptStore {
  /// The transcript of [recording], or null when it has none — never been
  /// transcribed, or its file is damaged.
  Future<Transcript?> load(LectureRecording recording);

  Future<void> save(LectureRecording recording, Transcript transcript);

  /// Whether [recording] has a transcript, without reading it.
  Future<bool> exists(LectureRecording recording);
}

class FileTranscriptStore implements TranscriptStore {
  /// [_docsDir] is the app documents directory the recording's relative path is
  /// resolved against.
  FileTranscriptStore(this._docsDir);

  final String _docsDir;

  File _fileOf(LectureRecording recording) => File(
      '$_docsDir/${StoragePaths.transcriptSidecar(recording.relativePath)}');

  @override
  Future<bool> exists(LectureRecording recording) =>
      _fileOf(recording).exists();

  @override
  Future<Transcript?> load(LectureRecording recording) async {
    final file = _fileOf(recording);
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return Transcript.fromJson((json as Map).cast<String, Object?>());
    } catch (_) {
      // A damaged or unreadable file is "no transcript": the audio is intact and
      // it can be transcribed again.
      return null;
    }
  }

  @override
  Future<void> save(LectureRecording recording, Transcript transcript) async {
    final file = _fileOf(recording);
    await file.parent.create(recursive: true);
    // Written aside and renamed in, so a crash mid-write leaves the old
    // transcript (or none) rather than half of a new one.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(transcript.toJson()), flush: true);
    await temp.rename(file.path);
  }
}

/// In-memory store for tests.
class InMemoryTranscriptStore implements TranscriptStore {
  final Map<String, Transcript> _byPath = {};

  @override
  Future<bool> exists(LectureRecording recording) async =>
      _byPath.containsKey(recording.relativePath);

  @override
  Future<Transcript?> load(LectureRecording recording) async =>
      _byPath[recording.relativePath];

  @override
  Future<void> save(LectureRecording recording, Transcript transcript) async =>
      _byPath[recording.relativePath] = transcript;
}

/// The transcripts of [recordings] (the lectures recorded on one page, oldest
/// first) as the text the AI reads: each under its own "Lecture recorded …"
/// heading, blank-line separated. Empty when none has been transcribed.
Future<String> lectureTextOf(
  Iterable<LectureRecording> recordings,
  TranscriptStore store,
) async {
  final parts = <String>[];
  for (final recording in recordings) {
    // A compressed recording cannot have a transcript; skip the lookup.
    if (!recording.isSpeechAudio) continue;
    final transcript = await store.load(recording);
    if (transcript == null) continue;
    final text = transcript.asPageText(recordedAt: recording.startedAt);
    if (text.isNotEmpty) parts.add(text);
  }
  return parts.join('\n\n');
}

/// Where in a lecture a passage was said.
typedef LectureLocation = ({LectureRecording recording, int offsetMs});

/// Finds where [passage] — a piece of a page's text, as an answer's source card
/// quotes it — was said in [recordings] (the lectures recorded on that page).
///
/// The words come first: the first segment whose text the passage holds names its
/// recording and its start. That is what tells two lectures on one page apart,
/// whose timestamps can be identical. A passage the chunker cut inside a segment
/// holds no whole one, so the `[m:ss]` stamp it carries is the fallback, taken
/// from the first lecture long enough to hold it. Null when it is nowhere.
Future<LectureLocation?> locateInLectures(
  String passage,
  Iterable<LectureRecording> recordings,
  TranscriptStore store,
) async {
  final speech = [
    for (final r in recordings)
      if (r.isSpeechAudio) r,
  ];
  final flat = _flat(passage);

  for (final recording in speech) {
    final transcript = await store.load(recording);
    if (transcript == null) continue;
    for (final segment in transcript.segments) {
      final words = _flat(segment.text);
      if (words.isNotEmpty && flat.contains(words)) {
        return (recording: recording, offsetMs: segment.startMs);
      }
    }
  }

  final offset = lectureOffsetOf(passage);
  if (offset == null) return null;
  for (final recording in speech) {
    if (recording.contains(offset)) {
      return (recording: recording, offsetMs: offset);
    }
  }
  return null;
}

/// Lower-cased with every run of whitespace a single space, so a passage's line
/// breaks and spacing do not decide whether it matches.
String _flat(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
