// The app-wide state of the on-device LLM download:
//   idle → running(percent) → installed
//            ↘ failed(message) → (retry) …
//            ↘ (cancel) → idle
//
// This exists because the download is app-lifetime work driven from a screen
// the user is expected to leave. [ModelDownloadManager] is already root-scoped
// and single-flight, so an in-flight run was never actually aborted by closing
// the AI sidebar — but the progress lived in the sidebar's widget State, so
// reopening the panel showed the "Download model" button again as though
// nothing had happened, and a download that finished while the panel was closed
// dropped its completion side effect on a `mounted` check. Every other AI
// surface (Explain, Quiz, Flashcards, Ask, Summarize) already keeps download
// progress in a session-scoped notifier; this is the same treatment for the one
// path that starts the download.
//
// It mirrors the manager rather than owning it, and ADOPTS runs it did not
// start: the manager is shared, so a download kicked off from Explain or Ask
// must still drive this state to a terminal value. Without that, a run started
// elsewhere would stick at running(100) here forever.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/llm/llm_exceptions.dart';
import '../data/llm/model_download_manager.dart';

sealed class LlmDownloadState {
  const LlmDownloadState();
}

/// Nothing running: never started, cancelled, or a failure the user dismissed.
class LlmDownloadIdle extends LlmDownloadState {
  const LlmDownloadIdle();
}

class LlmDownloadRunning extends LlmDownloadState {
  final int percent; // 0–100
  const LlmDownloadRunning(this.percent);
}

/// The model is on disk — the download completed during this session.
///
/// Not a general "is installed" answer: a fresh launch with the model already
/// present starts at [LlmDownloadIdle], because nothing here probes the disk.
/// Ask [ModelDownloadManager.isInstalled] for that.
class LlmDownloadInstalled extends LlmDownloadState {
  const LlmDownloadInstalled();
}

class LlmDownloadFailed extends LlmDownloadState {
  final String message;
  const LlmDownloadFailed(this.message);
}

class LlmDownloadNotifier extends StateNotifier<LlmDownloadState> {
  final ModelDownloadManager _downloads;

  /// Whether this notifier is already awaiting the manager's future, so
  /// [_adopt] can't stack a second waiter per progress tick.
  bool _awaiting = false;

  LlmDownloadNotifier(this._downloads) : super(const LlmDownloadIdle()) {
    // Listened for the whole app lifetime, not just for the duration of
    // [start]: a download the user kicked off from another surface drives this
    // state too, so the sidebar reopens onto live progress whoever started it.
    _downloads.progress.listen((p) {
      if (!mounted) return;
      state = LlmDownloadRunning(p);
      _adopt();
    });
    // A manager already mid-download when this notifier is first read (the
    // panel was closed and reopened) would otherwise sit at idle until the
    // next whole-percent tick — tens of seconds on a 2.4 GB transfer.
    final current = _downloads.currentPercent;
    if (_downloads.isDownloading) {
      state = LlmDownloadRunning(current ?? 0);
      _adopt();
    }
  }

  /// Starts the download, or joins the one already running.
  ///
  /// Safe to call from anywhere, repeatedly: the manager is single-flight, so a
  /// second call returns the same future rather than starting a second 2.4 GB
  /// transfer.
  Future<void> start() {
    if (_awaiting) return Future.value();
    state = LlmDownloadRunning(_downloads.currentPercent ?? 0);
    return _await();
  }

  /// Cancels an in-flight download. The manager's cancel makes its future throw
  /// [ModelDownloadCancelledException], which [_await] turns into idle — so
  /// this deliberately does not set the state itself.
  void cancel() => _downloads.cancelDownload();

  /// Dismisses a failure so the view offers the download again.
  void clearFailure() {
    if (state is LlmDownloadFailed) state = const LlmDownloadIdle();
  }

  /// Joins a run this notifier did not start, so it still reaches a terminal
  /// state. No-op when nothing is running or we are already waiting.
  void _adopt() {
    if (_awaiting || !_downloads.isDownloading) return;
    unawaited(_await());
  }

  Future<void> _await() async {
    _awaiting = true;
    try {
      await _downloads.download();
      state = const LlmDownloadInstalled();
    } on ModelDownloadCancelledException {
      state = const LlmDownloadIdle();
    } on LlmException catch (e) {
      // Typed failures already carry a message written for the user — auth,
      // licence, rate limit, storage. Flattening them into "check your
      // connection" sent people to fix their wifi over a HuggingFace licence
      // they had never accepted, with nothing on screen pointing at the real
      // cause. Settings shows these verbatim; so does the sidebar.
      state = LlmDownloadFailed(e.message);
    } catch (_) {
      // Backstop, not the normal path: the manager already translates every
      // failure it catches into the [LlmException] family above. This only
      // catches something thrown outside that translation, and must still put
      // words on screen rather than leave the panel stuck on a progress bar.
      state = const LlmDownloadFailed(
          'Download failed. Check your connection and try again.');
    } finally {
      _awaiting = false;
    }
    // No `mounted` gate on those transitions, unlike the per-surface notifiers:
    // this one is root-scoped and outlives every screen, which is the point.
  }
}
