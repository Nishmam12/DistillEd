// The record button's orchestration: row-before-capture ordering, duration
// stamping on stop, and seeking playback from a stroke.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/data/persistence/lecture_recording_store.dart';
import 'package:inkflow/features/audio/data/transcript_store.dart';
import 'package:inkflow/features/audio/domain/audio_ports.dart';
import 'package:inkflow/features/audio/domain/transcript.dart';
import 'package:inkflow/features/audio/domain/lecture_recording.dart';
import 'package:inkflow/features/audio/domain/recording_session.dart';
import 'package:inkflow/features/audio/presentation/recording_notifier.dart';

import 'lecture_recording_test.dart' show FakeCapture;

class FakePlayback implements AudioPlaybackPort {
  String? loaded;
  Duration? seeked;
  bool playing = false;
  bool failLoad = false;

  @override
  Future<void> load(String absolutePath) async {
    if (failLoad) {
      throw const AudioUnavailableException('no file');
    }
    loaded = absolutePath;
  }

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause() async => playing = false;

  @override
  Future<void> seek(Duration position) async => seeked = position;

  @override
  Future<void> dispose() async {}

  @override
  Stream<Duration> get position => const Stream.empty();

  @override
  bool get isPlaying => playing;
}

typedef _B = ({
  RecordingNotifier notifier,
  FakeCapture capture,
  FakePlayback playback,
  InMemoryLectureRecordingStore store,
  String docs,
  List<LectureRecording> finished,
  void Function(bool) setTranscribe,
  InMemoryTranscriptStore transcripts,
});

({
  RecordingNotifier notifier,
  FakeCapture capture,
  FakePlayback playback,
  InMemoryLectureRecordingStore store,
  String docs,
  List<LectureRecording> finished,
  void Function(bool) setTranscribe,
  InMemoryTranscriptStore transcripts,
}) _build({bool transcribe = false}) {
  final capture = FakeCapture();
  final playback = FakePlayback();
  final store = InMemoryLectureRecordingStore();
  var engineMs = 1000;
  var transcribeOn = transcribe;
  final finished = <LectureRecording>[];
  final transcripts = InMemoryTranscriptStore();
  // A real, writable directory: recording creates the audio folder, and a
  // hard-coded '/docs' only exists on the machine that wrote the tests.
  final docs = Directory.systemTemp.createTempSync('inkflow_rec_');
  addTearDown(() => docs.deleteSync(recursive: true));
  final notifier = RecordingNotifier(
    session: RecordingSession(capture: capture, engineNowMs: () => engineMs),
    store: store,
    playback: playback,
    appDocsPath: docs.path,
    notebookId: 1,
    transcribeLectures: () => transcribeOn,
    onFinished: finished.add,
    transcripts: transcripts,
  );
  return (
    notifier: notifier,
    capture: capture,
    playback: playback,
    store: store,
    docs: docs.path,
    finished: finished,
    setTranscribe: (v) => transcribeOn = v,
    transcripts: transcripts,
  );
}

void main() {
  test('start persists the row before capture begins', () async {
    final f = _build();

    await f.notifier.start(10);

    // The row must exist first — strokes need its id from the very first one.
    expect(f.store.recordings, hasLength(1));
    expect(f.notifier.state.isRecording, isTrue);
    expect(f.notifier.state.active!.id, greaterThan(0));
    expect(f.capture.started, isTrue);
  });

  test('the audio file path is scoped to the notebook and page', () async {
    final f = _build();

    await f.notifier.start(10);

    expect(f.capture.path, startsWith('${f.docs}/audio/n1_p10_'));
    expect(f.capture.path, endsWith('.m4a'));
  });

  group('playPassage — a source card jumping into a lecture', () {
    Future<(_B, LectureRecording)> lectureWith(
        List<(int, String)> lines) async {
      final f = _build(transcribe: true);
      f.capture.stopReturns = 600000;
      await f.notifier.start(10);
      await f.notifier.stop(10);
      final recording = f.store.recordings.single.copyWith(durationMs: 600000);
      await f.transcripts.save(
          recording,
          Transcript(language: 'en', model: 'm', segments: [
            for (final (ms, text) in lines)
              TranscriptSegment(startMs: ms, endMs: ms + 5000, text: text),
          ]));
      return (f, recording);
    }

    test('plays the lecture from where the passage was said', () async {
      final (f, recording) =
          await lectureWith([(0, 'Intro words.'), (83000, 'The nucleus holds DNA.')]);

      await f.notifier
          .playPassage(pageId: 10, passage: '[1:23] The nucleus holds DNA.');

      expect(f.playback.loaded, '${f.docs}/${recording.relativePath}');
      expect(f.playback.seeked, const Duration(milliseconds: 83000));
      expect(f.playback.playing, isTrue);
    });

    test('a passage that is not from a lecture plays nothing', () async {
      final (f, _) = await lectureWith([(0, 'Intro words.')]);

      await f.notifier.playPassage(pageId: 10, passage: 'Notes on the cell cycle');

      expect(f.playback.loaded, isNull);
      expect(f.playback.playing, isFalse);
    });

    test('with no transcripts wired it plays nothing', () async {
      final capture = FakeCapture();
      final store = InMemoryLectureRecordingStore();
      final playback = FakePlayback();
      final docs = Directory.systemTemp.createTempSync('inkflow_rec3_');
      addTearDown(() => docs.deleteSync(recursive: true));
      final notifier = RecordingNotifier(
        session: RecordingSession(capture: capture, engineNowMs: () => 0),
        store: store,
        playback: playback,
        appDocsPath: docs.path,
        notebookId: 1,
      );

      await notifier.playPassage(pageId: 10, passage: '[0:05] anything');

      expect(playback.loaded, isNull);
    });

    test('a file that cannot be opened surfaces an error rather than throwing',
        () async {
      final (f, _) = await lectureWith([(5000, 'Some words.')]);
      f.playback.failLoad = true;

      await f.notifier.playPassage(pageId: 10, passage: '[0:05] Some words.');

      expect(f.notifier.state.error, isNotNull);
    });
  });

  group('lecture transcripts', () {
    test('with transcripts on, the audio is 16 kHz mono WAV — the format the '
        'speech model takes as it is', () async {
      final f = _build(transcribe: true);

      await f.notifier.start(10);

      expect(f.capture.format, AudioFormat.speechWav);
      expect(f.capture.path, endsWith('.wav'));
      expect(f.store.recordings.single.relativePath, endsWith('.wav'));
      expect(f.store.recordings.single.isSpeechAudio, isTrue);
    });

    test('the language the student chose is stamped on the recording',
        () async {
      final f = _build(transcribe: true);

      await f.notifier.start(10, language: 'bn');

      expect(f.store.recordings.single.relativePath, endsWith('_bn.wav'));
    });

    test('with transcripts off, it is compressed AAC exactly as before',
        () async {
      final f = _build();

      await f.notifier.start(10);

      expect(f.capture.format, AudioFormat.aac);
      expect(f.capture.path, endsWith('.m4a'));
    });

    test('a finished WAV recording is handed on to be transcribed, with its '
        'length filled in', () async {
      final f = _build(transcribe: true);
      f.capture.stopReturns = 45000;
      await f.notifier.start(10);

      await f.notifier.stop(10);

      expect(f.finished, hasLength(1));
      expect(f.finished.single.durationMs, 45000);
      expect(f.finished.single.pageId, 10);
    });

    test('a finished AAC recording is not — it cannot be transcribed', () async {
      final f = _build();
      await f.notifier.start(10);

      await f.notifier.stop(10);

      expect(f.finished, isEmpty);
    });

    test('turning the setting off mid-lecture changes nothing for it', () async {
      final f = _build(transcribe: true);
      await f.notifier.start(10);

      f.setTranscribe(false);
      await f.notifier.stop(10);

      expect(f.capture.format, AudioFormat.speechWav);
      expect(f.finished, hasLength(1));
    });

    test('a hand-off that fails never costs the recording', () async {
      final f = _build(transcribe: true);
      f.capture.stopReturns = 1000;
      // A fresh notifier whose hand-off throws.
      final capture = FakeCapture();
      final store = InMemoryLectureRecordingStore();
      final docs = Directory.systemTemp.createTempSync('inkflow_rec2_');
      addTearDown(() => docs.deleteSync(recursive: true));
      final notifier = RecordingNotifier(
        session: RecordingSession(capture: capture, engineNowMs: () => 0),
        store: store,
        playback: FakePlayback(),
        appDocsPath: docs.path,
        notebookId: 1,
        transcribeLectures: () => true,
        onFinished: (_) => throw StateError('queue closed'),
      );
      await notifier.start(10);

      await notifier.stop(10);

      expect(notifier.state.isRecording, isFalse);
      expect(store.recordings.single.durationMs, greaterThan(0));
    });
  });

  test('a refused permission surfaces an error and does not record', () async {
    final f = _build();
    f.capture.permitted = false;

    await f.notifier.start(10);

    expect(f.notifier.state.isRecording, isFalse);
    expect(f.notifier.state.error, contains('Microphone permission'));
  });

  test('stop stamps the duration on the stored row', () async {
    final f = _build();
    f.capture.stopReturns = 45000;
    await f.notifier.start(10);

    await f.notifier.stop(10);

    expect(f.notifier.state.isRecording, isFalse);
    expect(f.store.recordings.single.durationMs, 45000);
    expect(f.notifier.state.onPage.single.durationMs, 45000);
  });

  test('stopping when not recording is a no-op', () async {
    final f = _build();

    await f.notifier.stop(10);

    expect(f.store.recordings, isEmpty);
  });

  test('starting twice does not open a second recording', () async {
    final f = _build();
    await f.notifier.start(10);

    await f.notifier.start(10);

    expect(f.store.recordings, hasLength(1));
  });

  group('playFromStroke', () {
    test('seeks to the stroke\'s moment and plays', () async {
      final f = _build();
      f.capture.stopReturns = 60000;
      await f.notifier.start(10);
      await f.notifier.stop(10);
      final id = f.store.recordings.single.id;

      await f.notifier.playFromStroke(recordingId: id, audioOffsetMs: 12000);

      expect(f.playback.loaded, startsWith('${f.docs}/audio/'));
      expect(f.playback.seeked, const Duration(milliseconds: 12000));
      expect(f.playback.isPlaying, isTrue);
    });

    test('an unrecorded stroke plays nothing', () async {
      final f = _build();
      await f.notifier.loadForPage(10);

      await f.notifier.playFromStroke(recordingId: null, audioOffsetMs: null);

      expect(f.playback.loaded, isNull);
      expect(f.playback.isPlaying, isFalse);
    });

    test('a stroke whose recording is gone plays nothing', () async {
      final f = _build();
      await f.notifier.loadForPage(10);

      await f.notifier.playFromStroke(recordingId: 999, audioOffsetMs: 1000);

      expect(f.playback.loaded, isNull);
    });

    test('an unreadable file surfaces an error rather than throwing', () async {
      final f = _build();
      f.capture.stopReturns = 60000;
      await f.notifier.start(10);
      await f.notifier.stop(10);
      f.playback.failLoad = true;
      final id = f.store.recordings.single.id;

      await f.notifier.playFromStroke(recordingId: id, audioOffsetMs: 1000);

      expect(f.notifier.state.error, isNotNull);
    });
  });

  test('loadForPage lists only that page\'s recordings', () async {
    final f = _build();
    f.capture.stopReturns = 1000;
    await f.notifier.start(10);
    await f.notifier.stop(10);

    await f.notifier.loadForPage(11);

    expect(f.notifier.state.onPage, isEmpty);
  });
}
