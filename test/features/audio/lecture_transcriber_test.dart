import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/audio/domain/lecture_transcriber.dart';

import 'wav_fixtures.dart';

/// A speech model that answers from a script and records what it was asked.
class _FakeSpeech implements SpeechToText {
  _FakeSpeech(this.reply);

  /// Called with the 0-based index of the call and its PCM.
  final FutureOr<String> Function(int call, Uint8List pcm) reply;
  final languages = <String>[];
  final lengthsMs = <int>[];
  int calls = 0;

  @override
  Future<void> close() async {}

  @override
  Future<String> transcribe(Uint8List pcm, {required String language}) async {
    languages.add(language);
    lengthsMs.add(pcm.length ~/ 32);
    return reply(calls++, pcm);
  }
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('inkflow_tr_'));
  tearDown(() => dir.deleteSync(recursive: true));

  LectureTranscriber transcriber(SpeechToText speech,
          {Exclusive? exclusive, String modelId = 'whisper-test'}) =>
      LectureTranscriber(speech: speech, modelId: modelId, exclusive: exclusive);

  test('each window of speech becomes a segment with its span', () async {
    // 60 s of continuous speech: English windows are 25 s.
    final path = writeWav(dir, pcm([(60000, 4000)]));
    final speech = _FakeSpeech((i, _) => ' words $i ');

    final t = await transcriber(speech).transcribe(path, language: 'en');

    expect(t.language, 'en');
    expect(t.model, 'whisper-test');
    expect(t.segments.map((s) => s.text), ['words 0', 'words 1', 'words 2']);
    expect(t.segments.first.startMs, 0);
    expect(t.segments.last.endMs, 60000);
    for (var i = 1; i < t.segments.length; i++) {
      expect(t.segments[i].startMs, t.segments[i - 1].endMs);
    }
  });

  test('the model is told the language, every time', () async {
    final path = writeWav(dir, pcm([(30000, 4000)]));
    final speech = _FakeSpeech((_, __) => 'x');

    await transcriber(speech).transcribe(path, language: 'bn');

    expect(speech.languages, everyElement('bn'));
  });

  test('Bangla is fed in much shorter pieces than English', () async {
    final path = writeWav(dir, pcm([(60000, 4000)]));
    final en = _FakeSpeech((_, __) => 'x');
    final bn = _FakeSpeech((_, __) => 'x');

    await transcriber(en).transcribe(path, language: 'en');
    await transcriber(bn).transcribe(path, language: 'bn');

    expect(bn.calls, greaterThan(en.calls * 2));
    expect(bn.lengthsMs.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(8000));
  });

  test('silence is never sent to the model', () async {
    // Whisper invents text for silence.
    final path =
        writeWav(dir, pcm([(25000, 4000), (25000, 0), (25000, 4000)]));
    final speech = _FakeSpeech((_, __) => 'said something');

    final t = await transcriber(speech).transcribe(path, language: 'en');

    expect(speech.calls, 2);
    expect(t.segments, hasLength(2));
  });

  test('an all-silent recording is an empty transcript, not an error', () async {
    final path = writeWav(dir, pcm([(40000, 0)]));
    final speech = _FakeSpeech((_, __) => 'never');

    final t = await transcriber(speech).transcribe(path, language: 'en');

    expect(t.isEmpty, isTrue);
    expect(speech.calls, 0);
  });

  test('text is trimmed and a window that said nothing leaves no segment',
      () async {
    final path = writeWav(dir, pcm([(60000, 4000)]));
    final speech = _FakeSpeech((i, _) => i == 1 ? '   ' : '  hello  ');

    final t = await transcriber(speech).transcribe(path, language: 'en');

    expect(t.segments.map((s) => s.text), ['hello', 'hello']);
  });

  group('sharing the device with the language model', () {
    test('every window runs under the exclusive runner', () async {
      final path = writeWav(dir, pcm([(60000, 4000)]));
      var running = 0;
      var peak = 0;
      var entered = 0;
      Future<T> exclusive<T>(Future<T> Function() job) async {
        entered++;
        running++;
        peak = running > peak ? running : peak;
        try {
          return await job();
        } finally {
          running--;
        }
      }

      final speech = _FakeSpeech((_, __) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return 'x';
      });

      await transcriber(speech, exclusive: exclusive)
          .transcribe(path, language: 'en');

      expect(entered, speech.calls, reason: 'one lock per window');
      expect(peak, 1);
    });

    test('the lock is released between windows, so a question can get in',
        () async {
      // If the whole lecture were one job, anything else wanting the model would
      // wait for the whole hour.
      final path = writeWav(dir, pcm([(60000, 4000)]));
      var holding = false;
      var heldAtStartOfNext = false;
      Future<T> exclusive<T>(Future<T> Function() job) async {
        heldAtStartOfNext = holding || heldAtStartOfNext;
        holding = true;
        try {
          return await job();
        } finally {
          holding = false;
        }
      }

      await transcriber(_FakeSpeech((_, __) => 'x'), exclusive: exclusive)
          .transcribe(path, language: 'en');

      expect(heldAtStartOfNext, isFalse);
    });
  });

  group('progress', () {
    test('goes from the first window to complete', () async {
      final path = writeWav(dir, pcm([(60000, 4000)]));
      final seen = <double>[];

      await transcriber(_FakeSpeech((_, __) => 'x')).transcribe(path,
          language: 'en', onProgress: seen.add);

      expect(seen, isNotEmpty);
      expect(seen.last, 1.0);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
    });

    test('silent stretches still count', () async {
      final path = writeWav(dir, pcm([(50000, 0)]));
      final seen = <double>[];

      await transcriber(_FakeSpeech((_, __) => 'x')).transcribe(path,
          language: 'en', onProgress: seen.add);

      expect(seen.last, 1.0);
    });
  });

  group('cancelling', () {
    test('stops, and says so — a partial transcript is never returned', () async {
      final path = writeWav(dir, pcm([(120000, 4000)]));
      var stop = false;
      final speech = _FakeSpeech((i, _) {
        if (i == 1) stop = true;
        return 'x';
      });

      await expectLater(
        transcriber(speech)
            .transcribe(path, language: 'en', isCancelled: () => stop),
        throwsA(isA<TranscriptionCancelled>()),
      );
      expect(speech.calls, 2, reason: 'no window is started after the stop');
    });
  });

  group('when the model misbehaves', () {
    test('a window it cannot read costs that window, not the lecture', () async {
      final path = writeWav(dir, pcm([(60000, 4000)]));
      final speech = _FakeSpeech((i, _) {
        if (i == 1) throw StateError('decoder blew up');
        return 'ok $i';
      });

      final t = await transcriber(speech).transcribe(path, language: 'en');

      expect(t.segments.map((s) => s.text), ['ok 0', 'ok 2']);
    });

    test('a model that is not there ends the job', () async {
      final path = writeWav(dir, pcm([(60000, 4000)]));
      final speech = _FakeSpeech((_, __) => throw const SpeechUnavailableException());

      await expectLater(transcriber(speech).transcribe(path, language: 'en'),
          throwsA(isA<SpeechUnavailableException>()));
      expect(speech.calls, 1, reason: 'the rest would fail the same way');
    });

    test('every window failing is an error, not an empty transcript', () async {
      final path = writeWav(dir, pcm([(60000, 4000)]));
      final speech = _FakeSpeech((_, __) => throw StateError('nope'));

      await expectLater(transcriber(speech).transcribe(path, language: 'en'),
          throwsA(isA<SpeechUnavailableException>()));
    });
  });

  test('a file that is not 16 kHz mono speech audio is refused', () async {
    final file = File('${dir.path}/not.wav')..writeAsBytesSync([1, 2, 3, 4]);

    await expectLater(
        transcriber(_FakeSpeech((_, __) => 'x'))
            .transcribe(file.path, language: 'en'),
        throwsFormatException);
  });
}
