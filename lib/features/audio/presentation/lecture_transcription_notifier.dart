// The queue that turns finished recordings into transcripts
// (docs/AI_PIPELINE_PLAN.md, item 14), and what the UI shows of it.
//
// One job at a time: transcription is the heaviest thing a recording leads to,
// and it takes the same lock as the language model per window (see
// [LectureTranscriber]), so running two at once would only make each slower. It
// is background work — nothing here ever blocks the editor, and a failure costs
// that lecture's transcript, never the recording.

import 'package:flutter_riverpod/legacy.dart';

import '../data/transcript_store.dart';
import '../domain/lecture_recording.dart';
import '../domain/lecture_transcriber.dart';

enum TranscriptionPhase { queued, running, done, failed }

class TranscriptionStatus {
  final TranscriptionPhase phase;

  /// 0–1 while [TranscriptionPhase.running].
  final double progress;

  /// Why it failed, for a person to read.
  final String? message;

  const TranscriptionStatus(this.phase, {this.progress = 0, this.message});
}

class LectureTranscriptionNotifier
    extends StateNotifier<Map<int, TranscriptionStatus>> {
  LectureTranscriptionNotifier({
    required this._transcriber,
    required this._speech,
    required this._store,
    required String appDocsPath,
    required this._languageFor,
    this._onTranscribed,
  })  : _docs = appDocsPath,
        super(const {});

  final LectureTranscriber _transcriber;
  final SpeechToText _speech;
  final TranscriptStore _store;
  final String _docs;
  final Future<String> Function(LectureRecording) _languageFor;

  /// Told when a transcript has been saved, so the page can be re-read and
  /// re-indexed with what was said in it.
  final Future<void> Function(LectureRecording)? _onTranscribed;

  final List<LectureRecording> _queue = [];
  final Set<int> _cancelRequested = {};
  bool _pumping = false;

  static const String _tooOld =
      'This lecture was recorded before transcripts were turned on, so it '
      "can't be transcribed.";
  static const String _noSpeechModel =
      "The speech model isn't available on this device. Download it in "
      'Settings — it needs Android 11 or later.';

  /// Queues [recording] for transcription. A recording already queued, running
  /// or finished is left alone; one that failed is tried again.
  void enqueue(LectureRecording recording) {
    final existing = state[recording.id];
    if (existing != null && existing.phase != TranscriptionPhase.failed) return;
    if (!recording.isSpeechAudio) {
      _set(recording.id,
          const TranscriptionStatus(TranscriptionPhase.failed, message: _tooOld));
      return;
    }
    _set(recording.id, const TranscriptionStatus(TranscriptionPhase.queued));
    _queue.add(recording);
    _pump();
  }

  /// Stops [recordingId]: a queued one never starts, a running one stops at its
  /// next window and leaves no transcript.
  void cancel(int recordingId) {
    if (_queue.any((r) => r.id == recordingId)) {
      _queue.removeWhere((r) => r.id == recordingId);
      _remove(recordingId);
    } else if (state[recordingId]?.phase == TranscriptionPhase.running) {
      _cancelRequested.add(recordingId);
    }
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_queue.isNotEmpty && mounted) {
        await _run(_queue.removeAt(0));
      }
    } finally {
      _pumping = false;
    }
    // The model is only worth keeping open while there is more to do.
    try {
      await _speech.close();
    } catch (_) {}
  }

  Future<void> _run(LectureRecording recording) async {
    final id = recording.id;
    _set(id, const TranscriptionStatus(TranscriptionPhase.running));
    try {
      if (await _store.exists(recording)) {
        _set(id, const TranscriptionStatus(TranscriptionPhase.done));
        return;
      }
      final language = await _languageFor(recording);
      final transcript = await _transcriber.transcribe(
        '$_docs/${recording.relativePath}',
        language: language,
        onProgress: (f) =>
            _set(id, TranscriptionStatus(TranscriptionPhase.running, progress: f)),
        isCancelled: () => _cancelRequested.contains(id),
      );
      await _store.save(recording, transcript);
      _set(id, const TranscriptionStatus(TranscriptionPhase.done));
      try {
        await _onTranscribed?.call(recording);
      } catch (_) {
        // Indexing is a convenience on top of a transcript that now exists.
      }
    } on TranscriptionCancelled {
      _remove(id);
    } on SpeechUnavailableException {
      // Every recording behind it would fail the same way.
      const failed = TranscriptionStatus(TranscriptionPhase.failed,
          message: _noSpeechModel);
      _set(id, failed);
      for (final queued in _queue) {
        _set(queued.id, failed);
      }
      _queue.clear();
    } on FormatException {
      _set(
          id,
          const TranscriptionStatus(TranscriptionPhase.failed,
              message: "That recording's audio can't be read."));
    } catch (_) {
      _set(
          id,
          const TranscriptionStatus(TranscriptionPhase.failed,
              message: "Couldn't transcribe this lecture."));
    } finally {
      _cancelRequested.remove(id);
    }
  }

  void _set(int id, TranscriptionStatus status) {
    if (!mounted) return;
    state = {...state, id: status};
  }

  void _remove(int id) {
    if (!mounted) return;
    state = {...state}..remove(id);
  }
}

/// What to tell the student after the queue changes from [previous] to [next]:
/// a notice for each lecture recorded on the page ([onPage]) that has just
/// finished or failed. Progress ticks, and news about other pages' lectures, say
/// nothing.
List<String> transcriptionNotices({
  required Map<int, TranscriptionStatus>? previous,
  required Map<int, TranscriptionStatus> next,
  required Iterable<LectureRecording> onPage,
}) {
  final notices = <String>[];
  for (final recording in onPage) {
    final now = next[recording.id];
    if (now == null || now.phase == previous?[recording.id]?.phase) continue;
    if (now.phase == TranscriptionPhase.done) {
      notices.add('Lecture transcript ready');
    } else if (now.phase == TranscriptionPhase.failed) {
      notices.add(now.message ?? "Couldn't transcribe this lecture.");
    }
  }
  return notices;
}
