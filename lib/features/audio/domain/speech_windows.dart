// Cutting a lecture into the windows a speech model can take
// (docs/AI_PIPELINE_PLAN.md, item 14).
//
// The model hears a fixed window and silently drops whatever runs past it
// (Whisper: 30 s; Moonshine: 5 s), so an hour of lecture has to be fed in
// pieces. The cuts matter: slicing mid-word loses the word on both sides, so
// each window ends at the quietest moment near its end, where a speaker has
// paused. Windows with nothing in them are flagged so they are never sent —
// Whisper invents text for silence.
//
// Pure apart from reading samples from a [WavSource].

import 'dart:math' as math;
import 'dart:typed_data';

import 'wav.dart';

/// RMS (of 16-bit samples, so up to 32768) below which a window is treated as
/// silence. Room noise is tens to a couple of hundred; speech is thousands.
///
/// ponytail: a starting point, not measured on a real classroom recording.
const int kSilenceRms = 300;

/// Bytes in a millisecond of 16 kHz mono 16-bit audio.
const int _bytesPerMs = 32;

/// Width of the frames pauses are looked for in.
const int _frameMs = 100;

/// The root-mean-square level of 16-bit little-endian PCM [pcm]; 0 for none.
double rmsOf(Uint8List pcm) {
  final samples = pcm.length ~/ 2;
  if (samples == 0) return 0;
  final view = ByteData.sublistView(pcm);
  var sum = 0.0;
  for (var i = 0; i < samples; i++) {
    final s = view.getInt16(i * 2, Endian.little);
    sum += s * s;
  }
  return math.sqrt(sum / samples);
}

/// Whether [pcm] holds nothing to transcribe.
bool isSilent(Uint8List pcm) => rmsOf(pcm) < kSilenceRms;

/// How many milliseconds of audio to hand the model at once, for [language]
/// (a Whisper code).
///
/// A Whisper window is 30 s, but its decoder is capped at 128 tokens, and a
/// language that needs many tokens per word runs out of them long before the
/// audio does: English spends about 3 tokens a second, so 25 s fits; Bengali
/// spends many times that, so its windows must be short or the end of every one
/// is lost.
///
/// ponytail: starting points from the token arithmetic, not measured. Shorten
/// Bangla further (or lengthen it) once real lectures have been transcribed.
int speechWindowMs(String language) => switch (language) {
      'en' => 25000,
      'bn' => 6000,
      _ => 15000,
    };

/// Where to end a [window] of audio: the middle of the quietest 100 ms frame in
/// its last stretch, as milliseconds from its start. The whole window when there
/// is no real pause to cut at.
///
/// The search covers the last fifth of the window (at least a second) but never
/// reaches back past its half-way point, so a window is always at least half
/// used and the walk through a recording always makes progress. A "pause" is a
/// frame under 30% of the window's overall level: a steady tone, or true
/// silence, has none, and is not cut.
int pauseCutMs(Uint8List window) {
  final lengthMs = window.length ~/ _bytesPerMs;
  final overall = rmsOf(window);
  final from =
      math.max<int>(lengthMs ~/ 2, lengthMs - math.max<int>(1000, lengthMs ~/ 5));

  var quietest = double.infinity;
  var cut = lengthMs;
  for (var end = from + _frameMs; end <= lengthMs; end += _frameMs) {
    final frame = Uint8List.sublistView(
        window, (end - _frameMs) * _bytesPerMs, end * _bytesPerMs);
    final level = rmsOf(frame);
    // `<=`: of equally quiet frames the LATER one, so windows stay long.
    if (level <= quietest) {
      quietest = level;
      cut = end - _frameMs ~/ 2;
    }
  }
  return quietest < overall * 0.3 ? cut : lengthMs;
}

/// One stretch of a recording, ready to transcribe.
class SpeechWindow {
  final int startMs;
  final int endMs;

  /// Its samples: 16 kHz mono 16-bit PCM, exactly `endMs - startMs` long.
  final Uint8List pcm;

  /// Nothing in it worth sending to the model.
  final bool silent;

  const SpeechWindow({
    required this.startMs,
    required this.endMs,
    required this.pcm,
    required this.silent,
  });
}

/// Walks [source] in windows of at most [windowMs], each cut at a pause near its
/// end (see [pauseCutMs]), with no gaps and no overlaps between them.
Stream<SpeechWindow> speechWindows(
  WavSource source, {
  required int windowMs,
}) async* {
  final total = source.durationMs;
  var start = 0;
  while (start < total) {
    final maxEnd = math.min(start + windowMs, total);
    var pcm = await source.readPcm(startMs: start, endMs: maxEnd);
    var end = maxEnd;
    if (maxEnd < total) {
      end = start + pauseCutMs(pcm);
      pcm = Uint8List.sublistView(pcm, 0, (end - start) * _bytesPerMs);
    }
    yield SpeechWindow(
      startMs: start,
      endMs: end,
      pcm: pcm,
      silent: isSilent(pcm),
    );
    start = end;
  }
}
