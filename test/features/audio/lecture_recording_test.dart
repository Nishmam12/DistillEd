// Tier 4.12 foundation: the ink↔audio timeline. Covers the correctness that
// device testing cannot easily reach — that a stroke seeks to the moment it was
// drawn, and keeps doing so after the app restarts.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/data/persistence/lecture_recording_store.dart';
import 'package:inkflow/features/audio/domain/audio_ports.dart';
import 'package:inkflow/features/audio/domain/lecture_recording.dart';
import 'package:inkflow/features/audio/domain/recording_session.dart';

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

  @override
  Future<bool> ensurePermission() async => permitted;

  @override
  Future<void> start(String absolutePath) async {
    path = absolutePath;
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

  @override
  bool get isRecording => started;
}

void main() {
  group('RecordingClock', () {
    test('offset is measured from when audio actually started', () {
      const clock = RecordingClock(startedAtEngineMs: 5000, recordingId: 1);

      expect(clock.offsetFor(5000), 0);
      expect(clock.offsetFor(9500), 4500);
    });

    test('a stroke just before the start clamps to zero', () {
      const clock = RecordingClock(startedAtEngineMs: 5000, recordingId: 1);

      expect(clock.offsetFor(4990), 0);
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
}
