// Turning a lecture recording into a transcript, one window at a time
// (docs/AI_PIPELINE_PLAN.md, item 14).
//
// Orchestration only: cut the recording into windows ([speechWindows]), skip the
// silent ones, hand each to a speech model, and collect the words with their
// spans. The model sits behind [SpeechToText] so all of this is tested with a
// fake, and the plugin lives in `data/`.
//
// ponytail: no streaming and no word timestamps — a segment is as precise as its
// window (5–25 s). Enough to jump to "about minute 23"; add word-level times if a
// transcript view ever needs to highlight along.

import 'dart:typed_data';

import 'speech_windows.dart';
import 'transcript.dart';
import 'wav.dart';

/// A speech-to-text model.
abstract class SpeechToText {
  /// Frees the model. The next [transcribe] opens it again.
  Future<void> close();

  /// The words in [pcm] (16 kHz mono 16-bit little-endian), written in
  /// [language] — a Whisper code. Throws [SpeechUnavailableException] when the
  /// model cannot run at all.
  Future<String> transcribe(Uint8List pcm, {required String language});
}

/// The speech model cannot run — not downloaded, or its native library did not
/// load (it needs Android 11). Ends the whole job: every window would fail the
/// same way.
class SpeechUnavailableException implements Exception {
  const SpeechUnavailableException([this.reason]);
  final String? reason;

  @override
  String toString() => 'SpeechUnavailableException: ${reason ?? 'unavailable'}';
}

/// The caller asked to stop.
class TranscriptionCancelled implements Exception {
  const TranscriptionCancelled();
}

/// Runs [job] when the device's local AI is free and keeps everything else out
/// until it finishes — the same lock the language model takes, so a transcript is
/// never being written while Gemma is answering.
typedef Exclusive = Future<T> Function<T>(Future<T> Function() job);

Future<T> _alone<T>(Future<T> Function() job) => job();

class LectureTranscriber {
  LectureTranscriber({
    required this._speech,
    required this._modelId,
    Exclusive? exclusive,
  })  : _exclusive = exclusive ?? _alone;

  final SpeechToText _speech;
  final String _modelId;
  final Exclusive _exclusive;

  /// Transcribes the 16 kHz mono WAV at [wavPath] as [language].
  ///
  /// The lock is taken per WINDOW, not for the whole job, so a lecture's hour
  /// never keeps a student's question waiting — it only ever waits for one window.
  ///
  /// [onProgress] gets 0–1 after every window, silent ones included.
  /// [isCancelled] is asked before each window; true throws
  /// [TranscriptionCancelled] and nothing is returned, so a half-finished
  /// transcript is never mistaken for a whole one.
  ///
  /// A window the model cannot read is skipped. Throws [FormatException] for a
  /// file that is not 16 kHz mono audio, and [SpeechUnavailableException] when
  /// the model is not there or no window could be transcribed at all.
  Future<Transcript> transcribe(
    String wavPath, {
    required String language,
    void Function(double fraction)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final source = await WavSource.open(wavPath);
    try {
      final total = source.durationMs;
      final segments = <TranscriptSegment>[];
      var attempted = 0;
      var succeeded = 0;
      var skipped = 0;

      await for (final window
          in speechWindows(source, windowMs: speechWindowMs(language))) {
        if (isCancelled?.call() ?? false) throw const TranscriptionCancelled();

        if (!window.silent) {
          attempted++;
          try {
            final text = (await _exclusive(
                    () => _speech.transcribe(window.pcm, language: language)))
                .trim();
            succeeded++;
            if (text.isNotEmpty) {
              segments.add(TranscriptSegment(
                startMs: window.startMs,
                endMs: window.endMs,
                text: text,
              ));
            }
          } on SpeechUnavailableException {
            rethrow;
          } catch (_) {
            // One window the model cannot read costs that window, not the lecture;
            // the count is kept so the transcript says it has a gap.
            skipped++;
          }
        }
        onProgress?.call(total == 0 ? 1.0 : window.endMs / total);
      }

      if (attempted > 0 && succeeded == 0) {
        throw const SpeechUnavailableException('no window could be transcribed');
      }
      return Transcript(
          language: language,
          model: _modelId,
          segments: segments,
          skippedWindows: skipped);
    } finally {
      await source.close();
    }
  }
}
