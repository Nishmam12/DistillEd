import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/constants/storage_paths.dart';
import 'package:inkflow/features/audio/data/transcript_store.dart';
import 'package:inkflow/features/audio/domain/lecture_recording.dart';
import 'package:inkflow/features/audio/domain/transcript.dart';

Transcript sample() => const Transcript(
      language: 'en',
      model: 'whisper-base-i8',
      segments: [
        TranscriptSegment(
            startMs: 0, endMs: 24000, text: 'Today we cover photosynthesis.'),
        TranscriptSegment(
            startMs: 24000,
            endMs: 61000,
            text: 'The light reactions happen in the thylakoid.'),
      ],
    );

void main() {
  group('Transcript JSON', () {
    test('survives a round trip', () {
      final back = Transcript.fromJson(
          jsonDecode(jsonEncode(sample().toJson())) as Map<String, dynamic>);

      expect(back.language, 'en');
      expect(back.model, 'whisper-base-i8');
      expect(back.segments, hasLength(2));
      expect(back.segments[1].startMs, 24000);
      expect(back.segments[1].endMs, 61000);
      expect(back.segments[1].text, 'The light reactions happen in the thylakoid.');
    });

    test('a file with the wrong shape is a FormatException, not a crash', () {
      expect(() => Transcript.fromJson({'language': 'en'}),
          throwsFormatException);
      expect(
          () => Transcript.fromJson({
                'language': 'en',
                'model': 'm',
                'segments': [
                  {'startMs': 'soon'},
                ],
              }),
          throwsFormatException);
    });
  });

  group('asPageText — what the AI reads of a lecture', () {
    final when = DateTime(2026, 10, 12, 10, 5); // a Monday

    test('says when it was recorded and that it is spoken, then timestamps '
        'each line', () {
      final text = sample().asPageText(recordedAt: when);

      expect(text, startsWith('Lecture recorded Mon, Oct 12 at 10:05'));
      expect(text, contains('[0:00] Today we cover photosynthesis.'));
      expect(text,
          contains('[0:24] The light reactions happen in the thylakoid.'));
    });

    test('uses hours once a lecture runs past one', () {
      const long = Transcript(language: 'en', model: 'm', segments: [
        TranscriptSegment(startMs: 3725000, endMs: 3750000, text: 'Late point.'),
      ]);

      expect(long.asPageText(recordedAt: when), contains('[1:02:05] Late point.'));
    });

    test('a transcript with no words adds nothing', () {
      const empty = Transcript(language: 'en', model: 'm', segments: []);

      expect(empty.asPageText(recordedAt: when), isEmpty);
    });

    test('lines that are not words — noise markers — are left out', () {
      const noisy = Transcript(language: 'en', model: 'm', segments: [
        TranscriptSegment(startMs: 0, endMs: 5000, text: ' ♪♪ '),
        TranscriptSegment(startMs: 5000, endMs: 10000, text: '...'),
        TranscriptSegment(startMs: 10000, endMs: 15000, text: 'Real words.'),
      ]);

      final text = noisy.asPageText(recordedAt: when);

      expect(text, contains('Real words.'));
      expect(text, isNot(contains('♪')));
      expect(text.split('\n').where((l) => l.startsWith('[')), hasLength(1));
    });

    test('Bangla comes through untouched', () {
      const bangla = Transcript(language: 'bn', model: 'm', segments: [
        TranscriptSegment(startMs: 0, endMs: 5000, text: 'আজ আমরা সালোকসংশ্লেষণ পড়ব'),
      ]);

      expect(bangla.asPageText(recordedAt: when),
          contains('[0:00] আজ আমরা সালোকসংশ্লেষণ পড়ব'));
    });
  });

  group('lectureOffsetOf — where in a lecture a passage came from', () {
    test('reads minutes and seconds', () {
      expect(lectureOffsetOf('[23:10] The mitochondria is…'),
          (23 * 60 + 10) * 1000);
    });

    test('reads hours', () {
      expect(lectureOffsetOf('[1:02:05] Late point.'), 3725000);
    });

    test('the FIRST timestamp in a passage wins', () {
      expect(lectureOffsetOf('[0:24] one\n[0:48] two'), 24000);
    });

    test('is found even when the passage starts mid-line', () {
      expect(lectureOffsetOf('…end of a sentence.\n[5:00] Next point.'), 300000);
    });

    test('a passage with none is not from a lecture', () {
      expect(lectureOffsetOf('Notes on the cell cycle'), isNull);
    });

    test('a citation number is not a timestamp', () {
      expect(lectureOffsetOf('as shown in [2] and [12]'), isNull);
    });

    test('seconds out of range are not a timestamp', () {
      expect(lectureOffsetOf('[3:75] nonsense'), isNull);
    });

    test('minutes out of range, in the hours form, are not either', () {
      expect(lectureOffsetOf('[1:75:05] nonsense'), isNull);
    });
  });

  group('the sidecar path', () {
    test('sits beside the audio and is named for it', () {
      expect(StoragePaths.transcriptSidecar('audio/n1_p2_17.wav'),
          'audio/n1_p2_17.transcript.json');
      expect(StoragePaths.transcriptSidecar('audio/n1_p2_17.m4a'),
          'audio/n1_p2_17.transcript.json');
    });
  });

  group('lectureTextOf — the lectures recorded on a page, as text', () {
    LectureRecording rec(int id, DateTime at, {String ext = 'wav'}) =>
        LectureRecording(
            id: id,
            notebookId: 1,
            pageId: 2,
            relativePath: 'audio/n1_p2_$id.$ext',
            startedAt: at,
            durationMs: 60000);

    Transcript said(String text) => Transcript(
        language: 'en',
        model: 'm',
        segments: [TranscriptSegment(startMs: 0, endMs: 5000, text: text)]);

    test('is each transcript in turn, each under its own heading', () async {
      final store = InMemoryTranscriptStore();
      final a = rec(1, DateTime(2026, 10, 12, 10, 5));
      final b = rec(2, DateTime(2026, 10, 14, 9, 0));
      await store.save(a, said('first lecture'));
      await store.save(b, said('second lecture'));

      final text = await lectureTextOf([a, b], store);

      expect(text, contains('Lecture recorded Mon, Oct 12 at 10:05'));
      expect(text, contains('[0:00] first lecture'));
      expect(text, contains('Lecture recorded Wed, Oct 14 at 09:00'));
      expect(text.indexOf('first lecture'), lessThan(text.indexOf('second lecture')));
      // A blank line between lectures, so they read as separate passages.
      expect(text, contains('\n\nLecture recorded Wed, Oct 14'));
    });

    test('leaves out recordings that were never transcribed', () async {
      final store = InMemoryTranscriptStore();
      final a = rec(1, DateTime(2026, 10, 12, 10, 5));
      final b = rec(2, DateTime(2026, 10, 14, 9, 0));
      await store.save(b, said('only this one'));

      final text = await lectureTextOf([a, b], store);

      expect(text, contains('only this one'));
      expect(text, isNot(contains('Oct 12')));
    });

    test('never opens a compressed recording — it cannot have a transcript',
        () async {
      final store = InMemoryTranscriptStore();
      final aac = rec(1, DateTime(2026, 10, 12), ext: 'm4a');
      await store.save(aac, said('should not appear'));

      expect(await lectureTextOf([aac], store), isEmpty);
    });

    test('a lecture that said nothing leaves no stray blank lines around the '
        'one that did', () async {
      final store = InMemoryTranscriptStore();
      final quiet = rec(1, DateTime(2026, 10, 12, 10, 5));
      final spoken = rec(2, DateTime(2026, 10, 14, 9, 0));
      await store.save(quiet, said(' ♪ '));
      await store.save(spoken, said('real words'));

      final text = await lectureTextOf([quiet, spoken], store);

      expect(text, startsWith('Lecture recorded Wed, Oct 14'));
      expect(text.trim(), text);
    });

    test('a page with no recordings has no lecture text', () async {
      expect(await lectureTextOf(const [], InMemoryTranscriptStore()), isEmpty);
    });

    test('a transcript with nothing intelligible adds nothing', () async {
      final store = InMemoryTranscriptStore();
      final a = rec(1, DateTime(2026, 10, 12, 10, 5));
      await store.save(a, said(' ♪ '));

      expect(await lectureTextOf([a], store), isEmpty);
    });
  });

  group('locateInLectures — where a passage was said', () {
    LectureRecording rec(int id, {String ext = 'wav', int durationMs = 600000}) =>
        LectureRecording(
            id: id,
            notebookId: 1,
            pageId: 2,
            relativePath: 'audio/n1_p2_$id.$ext',
            startedAt: DateTime(2026, 10, 12, 10, 5),
            durationMs: durationMs);

    Transcript lecture(List<(int, String)> lines) => Transcript(
        language: 'en',
        model: 'm',
        segments: [
          for (final (ms, text) in lines)
            TranscriptSegment(startMs: ms, endMs: ms + 5000, text: text),
        ]);

    test('finds the segment whose words the passage holds', () async {
      final store = InMemoryTranscriptStore();
      final a = rec(1);
      await store.save(a, lecture([(0, 'Today we cover cells.'), (83000, 'The nucleus holds the DNA.')]));

      final found = await locateInLectures(
          '[1:23] The nucleus holds the DNA.', [a], store);

      expect(found!.recording.id, 1);
      expect(found.offsetMs, 83000);
    });

    test('tells two lectures on one page apart by what was said', () async {
      // The same timestamp in both — only the words say which lecture it was.
      final store = InMemoryTranscriptStore();
      final a = rec(1);
      final b = rec(2);
      await store.save(a, lecture([(60000, 'First lecture, about cells.')]));
      await store.save(b, lecture([(60000, 'Second lecture, about atoms.')]));

      final found = await locateInLectures(
          '[1:00] Second lecture, about atoms.', [a, b], store);

      expect(found!.recording.id, 2);
    });

    test('a passage cut in the middle of a segment falls back to its timestamp',
        () async {
      final store = InMemoryTranscriptStore();
      final a = rec(1);
      await store.save(a, lecture([(300000, 'A very long sentence that was cut by the chunker.')]));

      final found =
          await locateInLectures('[5:00] A very long sentence that', [a], store);

      expect(found!.recording.id, 1);
      expect(found.offsetMs, 300000);
    });

    test('the timestamp is only believed if the lecture is that long', () async {
      final store = InMemoryTranscriptStore();
      final short = rec(1, durationMs: 60000);
      final long = rec(2, durationMs: 3600000);
      await store.save(short, lecture([(0, 'x')]));
      await store.save(long, lecture([(0, 'y')]));

      final found = await locateInLectures('[23:10] words not in either', [short, long], store);

      expect(found!.recording.id, 2);
      expect(found.offsetMs, (23 * 60 + 10) * 1000);
    });

    test('a passage that is not from a lecture is nowhere', () async {
      final store = InMemoryTranscriptStore();
      final a = rec(1);
      await store.save(a, lecture([(0, 'Cells divide.')]));

      expect(await locateInLectures('Notes on the cell cycle', [a], store), isNull);
    });

    test('a timestamp past the end of every lecture is nowhere', () async {
      final store = InMemoryTranscriptStore();
      final a = rec(1, durationMs: 60000);
      await store.save(a, lecture([(0, 'x')]));

      expect(await locateInLectures('[59:00] words', [a], store), isNull);
    });

    test('compressed recordings are never a match', () async {
      final store = InMemoryTranscriptStore();
      final aac = rec(1, ext: 'm4a');
      await store.save(aac, lecture([(0, 'Cells divide.')]));

      expect(await locateInLectures('[0:00] Cells divide.', [aac], store), isNull);
    });

    test('ignores differences in whitespace and case', () async {
      final store = InMemoryTranscriptStore();
      final a = rec(1);
      await store.save(a, lecture([(5000, 'Cells   divide.')]));

      // The stamp says 0:07 but the words say 0:05 — only matching the words
      // (despite the spacing and case) gives 5000.
      final found = await locateInLectures('[0:07] cells\ndivide.', [a], store);

      expect(found!.offsetMs, 5000);
    });

    test('a segment with no words never matches a passage', () async {
      final store = InMemoryTranscriptStore();
      final a = rec(1);
      await store.save(a, lecture([(0, ''), (9000, 'Real words here.')]));

      final found = await locateInLectures('[0:30] Real words here.', [a], store);

      expect(found!.offsetMs, 9000);
    });
  });

  group('FileTranscriptStore', () {
    late Directory docs;
    setUp(() => docs = Directory.systemTemp.createTempSync('inkflow_tr_'));
    tearDown(() => docs.deleteSync(recursive: true));

    LectureRecording recording({String path = 'audio/n1_p2_17.wav'}) =>
        LectureRecording(
            id: 1,
            notebookId: 1,
            pageId: 2,
            relativePath: path,
            startedAt: DateTime(2026, 10, 12, 10, 5),
            durationMs: 61000);

    test('what is saved is loaded back', () async {
      final store = FileTranscriptStore(docs.path);

      await store.save(recording(), sample());
      final back = await store.load(recording());

      expect(back, isNotNull);
      expect(back!.segments, hasLength(2));
      expect(back.language, 'en');
    });

    test('a recording that was never transcribed has none', () async {
      expect(await FileTranscriptStore(docs.path).load(recording()), isNull);
    });

    test('a damaged file is "none", not a crash', () async {
      final store = FileTranscriptStore(docs.path);
      final file = File('${docs.path}/audio/n1_p2_17.transcript.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{ not json');

      expect(file.existsSync(), isTrue);
      expect(await store.load(recording()), isNull);
    });

    test('saving leaves no half-written file behind', () async {
      final store = FileTranscriptStore(docs.path);

      await store.save(recording(), sample());

      final names =
          Directory('${docs.path}/audio').listSync().map((e) => e.path.split('/').last);
      expect(names, ['n1_p2_17.transcript.json']);
    });

    test('saving again replaces the transcript', () async {
      final store = FileTranscriptStore(docs.path);
      await store.save(recording(), sample());

      await store.save(
          recording(),
          const Transcript(language: 'bn', model: 'm', segments: [
            TranscriptSegment(startMs: 0, endMs: 1000, text: 'নতুন'),
          ]));

      final back = await store.load(recording());
      expect(back!.language, 'bn');
      expect(back.segments, hasLength(1));
    });

    test('knows whether a recording has been transcribed without reading it',
        () async {
      final store = FileTranscriptStore(docs.path);
      expect(await store.exists(recording()), isFalse);

      await store.save(recording(), sample());

      expect(await store.exists(recording()), isTrue);
    });
  });

  group('skipped stretches', () {
    final when = DateTime(2026, 10, 12, 10, 5);
    const seg = TranscriptSegment(startMs: 0, endMs: 5000, text: 'hello there');

    test('survive a save and load', () {
      final back = Transcript.fromJson(const Transcript(
              language: 'en', model: 'm', segments: [seg], skippedWindows: 2)
          .toJson());
      expect(back.skippedWindows, 2);
    });

    test('an older transcript without the field reads as complete', () {
      final back = Transcript.fromJson({
        'language': 'en',
        'model': 'm',
        'segments': [seg.toJson()],
      });
      expect(back.skippedWindows, 0);
    });

    test('the page text says the lecture has a gap', () {
      final text = const Transcript(
              language: 'en', model: 'm', segments: [seg], skippedWindows: 2)
          .asPageText(recordedAt: when);
      expect(text, contains('2 stretches of this recording could not be transcribed'));
    });
  });
}
