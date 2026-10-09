import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/audio/data/transcript_store.dart';
import 'package:inkflow/features/audio/domain/lecture_recording.dart';
import 'package:inkflow/features/audio/domain/lecture_transcriber.dart';
import 'package:inkflow/features/audio/domain/transcript.dart';
import 'package:inkflow/features/audio/presentation/lecture_transcription_notifier.dart';

class _Speech implements SpeechToText {
  int closed = 0;

  @override
  Future<void> close() async => closed++;

  @override
  Future<String> transcribe(Uint8List pcm, {required String language}) async =>
      '';
}

/// A transcriber that does what the test says: report progress, wait, fail.
class _FakeTranscriber extends LectureTranscriber {
  _FakeTranscriber(this.onRun) : super(speech: _Speech(), modelId: 'm');

  final Future<Transcript> Function(String path, String language,
      void Function(double)? onProgress, bool Function()? isCancelled) onRun;
  final paths = <String>[];
  final languages = <String>[];
  int running = 0;
  int peak = 0;

  @override
  Future<Transcript> transcribe(
    String wavPath, {
    required String language,
    void Function(double fraction)? onProgress,
    bool Function()? isCancelled,
  }) async {
    paths.add(wavPath);
    languages.add(language);
    running++;
    peak = running > peak ? running : peak;
    try {
      return await onRun(wavPath, language, onProgress, isCancelled);
    } finally {
      running--;
    }
  }
}

Transcript _said(String text) => Transcript(
    language: 'en',
    model: 'm',
    segments: [TranscriptSegment(startMs: 0, endMs: 5000, text: text)]);

LectureRecording _rec(int id, {String ext = 'wav', int pageId = 7}) =>
    LectureRecording(
      id: id,
      notebookId: 1,
      pageId: pageId,
      relativePath: 'audio/n1_p${pageId}_$id.$ext',
      startedAt: DateTime(2026, 10, 12, 10, 5),
      durationMs: 60000,
    );

/// Lets queued work run.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  late InMemoryTranscriptStore store;
  late _Speech speech;
  late List<LectureRecording> indexed;

  LectureTranscriptionNotifier notifier(_FakeTranscriber transcriber,
          {String language = 'en',
          Future<void> Function(LectureRecording)? onTranscribed}) =>
      LectureTranscriptionNotifier(
        transcriber: transcriber,
        speech: speech,
        store: store,
        appDocsPath: '/docs',
        languageFor: (_) async => language,
        onTranscribed: onTranscribed ?? (r) async => indexed.add(r),
      );

  setUp(() {
    store = InMemoryTranscriptStore();
    speech = _Speech();
    indexed = [];
  });

  test('a recording is transcribed, saved, and then handed on to be indexed',
      () async {
    final t = _FakeTranscriber((_, _, _, _) async => _said('hello'));
    final n = notifier(t);

    n.enqueue(_rec(1));
    await settle();

    expect(n.state[1]!.phase, TranscriptionPhase.done);
    expect((await store.load(_rec(1)))!.segments.single.text, 'hello');
    expect(indexed.map((r) => r.id), [1]);
    expect(t.paths, ['/docs/audio/n1_p7_1.wav']);
  });

  test('progress is visible while it runs', () async {
    final gate = Completer<void>();
    final t = _FakeTranscriber((_, _, progress, _) async {
      progress!(0.4);
      await gate.future;
      return _said('x');
    });
    final n = notifier(t);

    n.enqueue(_rec(1));
    await settle();

    expect(n.state[1]!.phase, TranscriptionPhase.running);
    expect(n.state[1]!.progress, closeTo(0.4, 1e-9));

    gate.complete();
    await settle();
    expect(n.state[1]!.phase, TranscriptionPhase.done);
  });

  test('it is transcribed in the language chosen for it', () async {
    final t = _FakeTranscriber((_, _, _, _) async => _said('x'));

    notifier(t, language: 'bn').enqueue(_rec(1));
    await settle();

    expect(t.languages, ['bn']);
  });

  test('queued recordings run one at a time, in order', () async {
    final t = _FakeTranscriber((_, _, _, _) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _said('x');
    });
    final n = notifier(t);

    n.enqueue(_rec(1));
    n.enqueue(_rec(2));
    n.enqueue(_rec(3));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(t.peak, 1);
    expect(t.paths.map((p) => p.split('_').last), ['1.wav', '2.wav', '3.wav']);
    expect(n.state.values.map((s) => s.phase),
        everyElement(TranscriptionPhase.done));
  });

  test('asking twice for the same recording runs it once', () async {
    final t = _FakeTranscriber((_, _, _, _) async => _said('x'));
    final n = notifier(t);

    n.enqueue(_rec(1));
    n.enqueue(_rec(1));
    await settle();

    expect(t.paths, hasLength(1));
  });

  test('asking again while it runs does not send it back to "queued"',
      () async {
    final gate = Completer<void>();
    final t = _FakeTranscriber((_, _, progress, _) async {
      progress!(0.5);
      await gate.future;
      return _said('x');
    });
    final n = notifier(t);

    n.enqueue(_rec(1));
    await settle();
    n.enqueue(_rec(1));

    expect(n.state[1]!.phase, TranscriptionPhase.running);
    expect(n.state[1]!.progress, closeTo(0.5, 1e-9));
    gate.complete();
    await settle();
  });

  test('one that is already transcribed is not done again', () async {
    await store.save(_rec(1), _said('earlier'));
    final t = _FakeTranscriber((_, _, _, _) async => _said('again'));
    final n = notifier(t);

    n.enqueue(_rec(1));
    await settle();

    expect(t.paths, isEmpty);
    expect(n.state[1]!.phase, TranscriptionPhase.done);
    expect((await store.load(_rec(1)))!.segments.single.text, 'earlier');
  });

  test('a recording made without transcripts on is refused, plainly', () async {
    final t = _FakeTranscriber((_, _, _, _) async => _said('x'));
    final n = notifier(t);

    n.enqueue(_rec(1, ext: 'm4a'));
    await settle();

    expect(n.state[1]!.phase, TranscriptionPhase.failed);
    expect(n.state[1]!.message, contains('before'));
    expect(t.paths, isEmpty);
  });

  test('a recording with nothing in it still finishes — saved as empty',
      () async {
    final t = _FakeTranscriber((_, _, _, _) async => const Transcript(
        language: 'en', model: 'm', segments: []));
    final n = notifier(t);

    n.enqueue(_rec(1));
    await settle();

    expect(n.state[1]!.phase, TranscriptionPhase.done);
    expect(await store.exists(_rec(1)), isTrue);
  });

  group('when it fails', () {
    test('the recording is marked failed with a reason, nothing is saved',
        () async {
      final t = _FakeTranscriber(
          (_, _, _, _) async => throw const FormatException('bad wav'));
      final n = notifier(t);

      n.enqueue(_rec(1));
      await settle();

      expect(n.state[1]!.phase, TranscriptionPhase.failed);
      expect(n.state[1]!.message, isNotEmpty);
      expect(await store.exists(_rec(1)), isFalse);
      expect(indexed, isEmpty);
    });

    test('the next one in the queue still runs', () async {
      final t = _FakeTranscriber((path, _, _, _) async {
        if (path.endsWith('_1.wav')) throw StateError('boom');
        return _said('ok');
      });
      final n = notifier(t);

      n.enqueue(_rec(1));
      n.enqueue(_rec(2));
      await settle();

      expect(n.state[1]!.phase, TranscriptionPhase.failed);
      expect(n.state[2]!.phase, TranscriptionPhase.done);
    });

    test('a missing speech model fails the rest of the queue the same way, '
        'without trying them', () async {
      final t = _FakeTranscriber(
          (_, _, _, _) async => throw const SpeechUnavailableException());
      final n = notifier(t);

      n.enqueue(_rec(1));
      n.enqueue(_rec(2));
      n.enqueue(_rec(3));
      await settle();

      expect(t.paths, hasLength(1));
      expect(n.state.values.map((s) => s.phase),
          everyElement(TranscriptionPhase.failed));
      expect(n.state[3]!.message, n.state[1]!.message);
    });

    test('indexing that fails does not undo a finished transcript', () async {
      final t = _FakeTranscriber((_, _, _, _) async => _said('x'));
      final n = notifier(t,
          onTranscribed: (_) async => throw StateError('index failed'));

      n.enqueue(_rec(1));
      await settle();

      expect(n.state[1]!.phase, TranscriptionPhase.done);
      expect(await store.exists(_rec(1)), isTrue);
    });
  });

  group('cancelling', () {
    test('a running job stops and leaves nothing behind', () async {
      final started = Completer<void>();
      final t = _FakeTranscriber((_, _, _, isCancelled) async {
        started.complete();
        while (!(isCancelled?.call() ?? false)) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        throw const TranscriptionCancelled();
      });
      final n = notifier(t);

      n.enqueue(_rec(1));
      await started.future;
      n.cancel(1);
      await settle();

      expect(n.state.containsKey(1), isFalse);
      expect(await store.exists(_rec(1)), isFalse);
      expect(indexed, isEmpty);
    });

    test('a queued one never runs', () async {
      final gate = Completer<void>();
      final t = _FakeTranscriber((_, _, _, _) async {
        await gate.future;
        return _said('x');
      });
      final n = notifier(t);

      n.enqueue(_rec(1));
      n.enqueue(_rec(2));
      await settle();
      n.cancel(2);
      gate.complete();
      await settle();

      expect(t.paths, hasLength(1));
      expect(n.state.containsKey(2), isFalse);
    });
  });

  test('the speech model is freed when the queue runs dry', () async {
    final t = _FakeTranscriber((_, _, _, _) async => _said('x'));
    final n = notifier(t);

    n.enqueue(_rec(1));
    n.enqueue(_rec(2));
    await settle();

    expect(speech.closed, 1, reason: 'once, after the last — not between them');
  });

  group('LectureRecording.isSpeechAudio', () {
    test('is true only for the WAV recordings made for transcription', () {
      expect(_rec(1).isSpeechAudio, isTrue);
      expect(_rec(1, ext: 'WAV').isSpeechAudio, isTrue);
      expect(_rec(1, ext: 'm4a').isSpeechAudio, isFalse);
    });
  });

  group('transcriptionNotices — what the editor says about the queue', () {
    const running = TranscriptionStatus(TranscriptionPhase.running, progress: .5);
    const done = TranscriptionStatus(TranscriptionPhase.done);
    const failed =
        TranscriptionStatus(TranscriptionPhase.failed, message: 'No model.');

    test('a lecture on this page finishing is announced', () {
      expect(
          transcriptionNotices(
              previous: {1: running}, next: {1: done}, onPage: [_rec(1)]),
          ['Lecture transcript ready']);
    });

    test('a failure is announced with its reason', () {
      expect(
          transcriptionNotices(
              previous: {1: running}, next: {1: failed}, onPage: [_rec(1)]),
          ['No model.']);
    });

    test('progress ticks are not announced', () {
      expect(
          transcriptionNotices(
              previous: {1: running},
              next: {1: const TranscriptionStatus(TranscriptionPhase.running, progress: .9)},
              onPage: [_rec(1)]),
          isEmpty);
    });

    test('something already finished is not announced again', () {
      expect(
          transcriptionNotices(
              previous: {1: done}, next: {1: done, 2: running}, onPage: [_rec(1)]),
          isEmpty);
    });

    test('a lecture on another page is not this page\'s news', () {
      expect(
          transcriptionNotices(
              previous: {5: running}, next: {5: done}, onPage: [_rec(1)]),
          isEmpty);
    });

    test('the first time a recording appears already finished counts', () {
      // e.g. an already-transcribed lecture queued again: done straight away.
      expect(
          transcriptionNotices(previous: null, next: {1: done}, onPage: [_rec(1)]),
          ['Lecture transcript ready']);
    });

    test('a recording that has no status says nothing', () {
      expect(
          transcriptionNotices(previous: {}, next: {}, onPage: [_rec(1)]),
          isEmpty);
    });
  });
}
