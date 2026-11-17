// Tier 4.12 foundation: the ink↔audio timeline. Covers the correctness that
// device testing cannot easily reach — that a stroke seeks to the moment it was
// drawn, and keeps doing so after the app restarts.

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/data/persistence/lecture_recording_store.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/features/audio/domain/audio_ports.dart';
import 'package:margo/features/audio/domain/lecture_recording.dart';
import 'package:margo/features/audio/domain/recording_session.dart';

LectureRecording _recording({int id = 1, int durationMs = 60000}) =>
    LectureRecording(
      id: id,
      notebookId: 1,
      pageId: 10,
      relativePath: 'audio/lecture_1.m4a',
      startedAt: DateTime(2026, 7, 29, 9),
      durationMs: durationMs,
    );

class FakeCapture implements AudioCapturePort {
  bool permitted = true;
  bool started = false;
  bool cancelled = false;
  int stopReturns = 12345;
  String? path;
  AudioFormat? format;

  @override
  Future<bool> ensurePermission() async => permitted;

  @override
  Future<void> start(String absolutePath,
      {AudioFormat format = AudioFormat.aac}) async {
    path = absolutePath;
    this.format = format;
    started = true;
  }

  @override
  Future<int> stop() async {
    started = false;
    return stopReturns;
  }

  @override
  Future<void> cancel() async {
    started = false;
    cancelled = true;
  }

  bool paused = false;

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<void> resume() async => paused = false;

  @override
  bool get isRecording => started;
}

void main() {
  group('RecordingClock', () {
    test('offset is measured from when audio actually started', () {
      final clock = RecordingClock(startedAtEngineMs: 5000, recordingId: 1);

      expect(clock.offsetFor(5000), 0);
      expect(clock.offsetFor(9500), 4500);
    });

    test('a stroke just before the start clamps to zero', () {
      final clock = RecordingClock(startedAtEngineMs: 5000, recordingId: 1);

      expect(clock.offsetFor(4990), 0);
    });

    // The plan's test: draw, pause 10 s, resume, draw. The audio file has no
    // gap where the pause was, so the second offset must not include it.
    test('paused time is not part of later offsets', () {
      final clock = RecordingClock(startedAtEngineMs: 0, recordingId: 1);
      expect(clock.offsetFor(2000), 2000);
      clock
        ..pause(3000)
        ..resume(13000);
      expect(clock.offsetFor(15000), 5000);
    });

    test('a stroke begun before a pause keeps its offset when stamped later',
        () {
      final clock = RecordingClock(startedAtEngineMs: 0, recordingId: 1)
        ..pause(3000)
        ..resume(13000);
      expect(clock.offsetFor(2000), 2000);
    });

    test('ink drawn during a pause points at the moment of the pause', () {
      final clock = RecordingClock(startedAtEngineMs: 0, recordingId: 1)
        ..pause(3000);
      expect(clock.offsetFor(8000), 3000);
      clock.resume(13000);
      expect(clock.offsetFor(8000), 3000);
    });

    test('several pauses add up; pause and resume twice are ignored', () {
      final clock = RecordingClock(startedAtEngineMs: 0, recordingId: 1)
        ..pause(1000)
        ..pause(1500)
        ..resume(2000)
        ..resume(2500)
        ..pause(5000)
        ..resume(9000);
      expect(clock.isPaused, isFalse);
      expect(clock.offsetFor(10000), 10000 - 1000 - 4000);
    });
  });

  group('stamping strokes', () {
    late FakeCapture capture;
    late int engineMs;
    late RecordingSession session;

    setUp(() {
      capture = FakeCapture();
      engineMs = 1000;
      session = RecordingSession(
        capture: capture,
        engineNowMs: () => engineMs,
      );
    });

    test('an idle session stamps nothing', () {
      expect(session.stampFor(1200), isNull);
      expect(session.isRecording, isFalse);
    });

    test('a stroke drawn while recording gets an offset', () async {
      await session.begin(
          recording: _recording(), absolutePath: '/tmp/a.m4a');

      final stamp = session.stampFor(engineMs + 3000);

      expect(stamp, isNotNull);
      expect(stamp!.recordingId, 1);
      expect(stamp.audioOffsetMs, 3000);
    });

    test('pause and resume reach the capture, and later ink skips the pause',
        () async {
      await session.begin(
          recording: _recording(), absolutePath: '/tmp/a.m4a');
      engineMs += 2000;
      await session.pause();
      expect(capture.paused, isTrue);
      expect(session.isPaused, isTrue);
      expect(session.isRecording, isTrue);
      final during = engineMs + 4000;
      engineMs += 10000;
      await session.resume();
      expect(capture.paused, isFalse);

      expect(session.stampFor(during)!.audioOffsetMs, 2000);
      expect(session.stampFor(engineMs + 1000)!.audioOffsetMs, 3000);
    });

    test('a paused session can be stopped', () async {
      await session.begin(
          recording: _recording(), absolutePath: '/tmp/a.m4a');
      await session.pause();
      final done = await session.stop();
      expect(done.durationMs, capture.stopReturns);
      expect(session.isRecording, isFalse);
    });

    test('stops stamping once the session ends', () async {
      await session.begin(
          recording: _recording(), absolutePath: '/tmp/a.m4a');
      await session.stop();

      expect(session.stampFor(engineMs + 3000), isNull);
    });

    test('refuses to start without permission', () async {
      capture.permitted = false;

      expect(
        () => session.begin(
            recording: _recording(), absolutePath: '/tmp/a.m4a'),
        throwsA(isA<AudioUnavailableException>()),
      );
    });

    test('refuses a second concurrent recording', () async {
      await session.begin(
          recording: _recording(), absolutePath: '/tmp/a.m4a');

      expect(
        () => session.begin(
            recording: _recording(id: 2), absolutePath: '/tmp/b.m4a'),
        throwsStateError,
      );
    });

    test('stop returns the captured duration', () async {
      capture.stopReturns = 42000;
      await session.begin(
          recording: _recording(durationMs: 0), absolutePath: '/tmp/a.m4a');

      final finished = await session.stop();

      expect(finished.durationMs, 42000);
      expect(session.isRecording, isFalse);
    });

    test('cancel abandons the capture and returns to idle', () async {
      await session.begin(
          recording: _recording(), absolutePath: '/tmp/a.m4a');

      await session.cancel();

      expect(capture.cancelled, isTrue);
      expect(session.isRecording, isFalse);
      expect(session.stampFor(engineMs + 100), isNull);
    });

    test('stop on an idle session throws rather than inventing a recording',
        () {
      expect(session.stop, throwsStateError);
    });
  });

  group('seeking from a stroke', () {
    test('an unrecorded stroke seeks nowhere', () {
      expect(
        seekTargetFor(
          recordingId: null,
          audioOffsetMs: null,
          recordings: [_recording()],
        ),
        isNull,
      );
    });

    test('a recorded stroke seeks to its own moment', () {
      final target = seekTargetFor(
        recordingId: 1,
        audioOffsetMs: 4500,
        recordings: [_recording()],
      );

      expect(target!.recordingId, 1);
      expect(target.offsetMs, 4500);
    });

    test('a stroke whose recording was deleted seeks nowhere', () {
      // The stroke keeps its stamp after the recording is removed; it must not
      // seek into some other recording that happens to share the id space.
      expect(
        seekTargetFor(
          recordingId: 99,
          audioOffsetMs: 4500,
          recordings: [_recording()],
        ),
        isNull,
      );
    });

    test('an offset past the end clamps to the end', () {
      final target = seekTargetFor(
        recordingId: 1,
        audioOffsetMs: 999999,
        recordings: [_recording(durationMs: 60000)],
      );

      expect(target!.offsetMs, 60000);
    });

    test('picks the right recording when a page has several', () {
      final target = seekTargetFor(
        recordingId: 2,
        audioOffsetMs: 1000,
        recordings: [_recording(id: 1), _recording(id: 2)],
      );

      expect(target!.recordingId, 2);
    });
  });

  group('offsets survive a restart', () {
    test('a stored offset is independent of the engine clock epoch', () async {
      // Session one: engine clock starts at 900_000.
      final capture = FakeCapture()..stopReturns = 10000;
      var engineMs = 900000;
      final session =
          RecordingSession(capture: capture, engineNowMs: () => engineMs);
      await session.begin(
          recording: _recording(durationMs: 0), absolutePath: '/tmp/a.m4a');
      final stamp = session.stampFor(engineMs + 2500)!;
      await session.stop();

      // Session two, after a relaunch: the engine clock is back near zero, so a
      // raw timestamp would be meaningless. The stored OFFSET still resolves.
      final target = seekTargetFor(
        recordingId: stamp.recordingId,
        audioOffsetMs: stamp.audioOffsetMs,
        recordings: [_recording(durationMs: 10000)],
      );

      expect(target!.offsetMs, 2500);
    });
  });

  group('LectureRecordingStore', () {
    test('insert assigns an id', () async {
      final store = InMemoryLectureRecordingStore();

      final stored = await store.insert(_recording(id: 0, durationMs: 0));

      expect(stored.id, greaterThan(0));
    });

    test('setDuration stamps a finished recording', () async {
      final store = InMemoryLectureRecordingStore();
      final stored = await store.insert(_recording(id: 0, durationMs: 0));

      await store.setDuration(stored.id, 30000);

      expect((await store.forPage(10)).single.durationMs, 30000);
    });

    test('scopes by page and notebook', () async {
      final store = InMemoryLectureRecordingStore();
      await store.insert(_recording(id: 0));

      expect(await store.forPage(10), hasLength(1));
      expect(await store.forPage(11), isEmpty);
      expect(await store.forNotebook(1), hasLength(1));
    });

    test('delete removes it', () async {
      final store = InMemoryLectureRecordingStore();
      final stored = await store.insert(_recording(id: 0));

      await store.delete(stored.id);

      expect(await store.forPage(10), isEmpty);
    });
  });

  group('formatting', () {
    test('renders elapsed time the way a player does', () {
      expect(LectureRecording.formatOffset(0), '0:00');
      expect(LectureRecording.formatOffset(5000), '0:05');
      expect(LectureRecording.formatOffset(65000), '1:05');
      expect(LectureRecording.formatOffset(3725000), '1:02:05');
    });

    test('a negative offset reads as zero', () {
      expect(LectureRecording.formatOffset(-1), '0:00');
    });
  });

  group('inkDuring — transcript line to ink', () {
    FreehandElement stroke(String id, {int? rec, int? at}) => FreehandElement(
        id: id,
        zOrder: 0,
        points: const [],
        color: 0,
        size: 2,
        recordingId: rec,
        audioOffsetMs: at);

    test('picks the strokes begun during the line, of that recording only', () {
      final ids = inkDuring([
        stroke('before', rec: 1, at: 900),
        stroke('start', rec: 1, at: 1000),
        stroke('mid', rec: 1, at: 1500),
        stroke('end', rec: 1, at: 2000),
        stroke('after', rec: 1, at: 2001),
        stroke('other lecture', rec: 2, at: 1500),
        stroke('unrecorded'),
      ], recordingId: 1, fromMs: 1000, toMs: 2000);
      expect(ids, ['start', 'mid', 'end']);
    });
  });
}
