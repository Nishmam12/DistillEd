// The record button's orchestration: row-before-capture ordering, duration
// stamping on stop, and seeking playback from a stroke.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/data/persistence/lecture_recording_store.dart';
import 'package:inkflow/features/audio/domain/audio_ports.dart';
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

({
  RecordingNotifier notifier,
  FakeCapture capture,
  FakePlayback playback,
  InMemoryLectureRecordingStore store,
}) _build() {
  final capture = FakeCapture();
  final playback = FakePlayback();
  final store = InMemoryLectureRecordingStore();
  var engineMs = 1000;
  final notifier = RecordingNotifier(
    session: RecordingSession(capture: capture, engineNowMs: () => engineMs),
    store: store,
    playback: playback,
    appDocsPath: '/docs',
    notebookId: 1,
  );
  return (
    notifier: notifier,
    capture: capture,
    playback: playback,
    store: store,
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

    expect(f.capture.path, startsWith('/docs/audio/n1_p10_'));
    expect(f.capture.path, endsWith('.m4a'));
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

      expect(f.playback.loaded, startsWith('/docs/audio/'));
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
