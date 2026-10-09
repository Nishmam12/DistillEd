import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/audio/domain/speech_windows.dart';

import 'wav_fixtures.dart';

void main() {
  group('rmsOf', () {
    test('silence is zero', () {
      expect(rmsOf(pcm([(500, 0)])), 0);
    });

    test('a square wave at an amplitude has that RMS', () {
      expect(rmsOf(pcm([(500, 8000)])), closeTo(8000, 1));
    });

    test('nothing at all is zero, not a crash', () {
      expect(rmsOf(Uint8List(0)), 0);
    });
  });

  group('isSilent — a window with nothing to transcribe', () {
    test('room noise is silence', () {
      expect(isSilent(pcm([(1000, 80)])), isTrue);
    });

    test('speech level is not', () {
      expect(isSilent(pcm([(1000, 3000)])), isFalse);
    });

    test('a window that is mostly pause but holds a word is not silence', () {
      expect(isSilent(pcm([(3000, 0), (400, 6000), (3000, 0)])), isFalse);
    });
  });

  group('speechWindowMs — how much audio one transcription is handed', () {
    test('English gets most of the 30 s window', () {
      expect(speechWindowMs('en'), inInclusiveRange(20000, 28000));
    });

    test('Bangla gets far less: Whisper caps a window at 128 tokens and Bengali '
        'costs several per word', () {
      expect(speechWindowMs('bn'), lessThanOrEqualTo(8000));
      expect(speechWindowMs('bn'), lessThan(speechWindowMs('en')));
    });

    test('anything else is in between', () {
      expect(speechWindowMs('de'), greaterThan(speechWindowMs('bn')));
      expect(speechWindowMs('de'), lessThan(speechWindowMs('en')));
    });
  });

  group('pauseCutMs — where to end a window', () {
    test('lands in the pause, not in the middle of a word', () {
      // 10 s window; a 300 ms pause centred at 8.5 s.
      final window = pcm([(8350, 5000), (300, 0), (1350, 5000)]);

      final cut = pauseCutMs(window);

      expect(cut, inInclusiveRange(8350, 8650));
    });

    test('with no pause, uses the whole window', () {
      final window = pcm([(10000, 5000)]);

      expect(pauseCutMs(window), 10000);
    });

    test('never cuts the window to less than half — progress is guaranteed',
        () {
      // The only quiet moment is near the START.
      final window = pcm([(1000, 0), (9000, 5000)]);

      expect(pauseCutMs(window), greaterThanOrEqualTo(5000));
    });

    test('a SHORT window is not cut below half either — its search stretch is '
        'at least a second, which would otherwise reach back to the start', () {
      // 1.2 s: a pause at the very start, speech after it.
      final window = pcm([(500, 0), (700, 5000)]);

      expect(pauseCutMs(window), greaterThanOrEqualTo(600));
    });

    test('a window of silence cuts at its end', () {
      expect(pauseCutMs(pcm([(6000, 0)])), 6000);
    });
  });

  group('speechWindows — walking a whole recording', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('inkflow_win_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('covers the recording with no gaps and no overlaps', () async {
      final source = await wavOf(dir, pcm([(25000, 4000)]));

      final windows = await speechWindows(source, windowMs: 10000).toList();

      expect(windows.first.startMs, 0);
      for (var i = 1; i < windows.length; i++) {
        expect(windows[i].startMs, windows[i - 1].endMs);
      }
      expect(windows.last.endMs, 25000);
      await source.close();
    });

    test('no window is longer than asked', () async {
      final source = await wavOf(dir, pcm([(25000, 4000)]));

      final windows = await speechWindows(source, windowMs: 10000).toList();

      for (final w in windows) {
        expect(w.endMs - w.startMs, lessThanOrEqualTo(10000));
      }
      await source.close();
    });

    test('a window\'s audio is exactly its span', () async {
      final source = await wavOf(dir, pcm([(12000, 4000)]));

      final windows = await speechWindows(source, windowMs: 5000).toList();

      for (final w in windows) {
        expect(w.pcm.length, (w.endMs - w.startMs) * 32);
      }
      await source.close();
    });

    test('cuts at the pause when one is near the end of a window', () async {
      // 8 s of speech, a 400 ms pause at 7.6–8.0 s, then more speech.
      final source =
          await wavOf(dir, pcm([(7600, 4000), (400, 0), (6000, 4000)]));

      final windows = await speechWindows(source, windowMs: 9000).toList();

      expect(windows.first.endMs, inInclusiveRange(7600, 8000));
      await source.close();
    });

    test('flags silent windows so they are not sent to the model', () async {
      final source =
          await wavOf(dir, pcm([(5000, 4000), (5000, 0), (5000, 4000)]));

      final windows = await speechWindows(source, windowMs: 5000).toList();

      expect(windows.map((w) => w.silent), [false, true, false]);
      await source.close();
    });

    test('an empty recording has no windows', () async {
      final source = await wavOf(dir, Uint8List(0));

      expect(await speechWindows(source, windowMs: 5000).toList(), isEmpty);
      await source.close();
    });

    test('the last window is never cut — it is all that is left', () async {
      // A pause near the end of a recording that fits in one window must not
      // split off a tiny trailing window of its own.
      final source =
          await wavOf(dir, pcm([(2500, 4000), (300, 0), (200, 4000)]));

      final windows = await speechWindows(source, windowMs: 25000).toList();

      expect(windows, hasLength(1));
      await source.close();
    });

    test('a recording shorter than a window is one window', () async {
      final source = await wavOf(dir, pcm([(3000, 4000)]));

      final windows = await speechWindows(source, windowMs: 25000).toList();

      expect(windows, hasLength(1));
      expect(windows.single.endMs, 3000);
      await source.close();
    });
  });
}
