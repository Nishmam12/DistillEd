// Manages the on-device LLM download: free-space check, progress stream,
// cancellation, delete. Retry (exponential backoff) comes from flutter_gemma's
// downloader.
//
// The download survives the app being backgrounded because
// [FlutterGemmaInstaller] passes `foreground: true`, which is what actually
// activates Android's foreground service — the plugin's size-based auto-detect
// does NOT (see the comment at that call site). It does NOT survive the process
// being killed: resume is disabled for HuggingFace URLs, so an interrupted
// transfer restarts from zero.
//
// Nothing here is scoped to a screen. The manager is app-lifetime and
// single-flight, so closing the AI sidebar or leaving the note cannot abort a
// run in progress; [LlmDownloadNotifier] mirrors it for the UI.

import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

import 'device_storage.dart';
import 'download_failure.dart';
import 'gemma_adapter.dart';
import 'llm_exceptions.dart';
import 'llm_model_spec.dart';

class ModelDownloadManager {
  /// Headroom over the model size so the download can't fill the disk to the
  /// brim (temp file + rename need slack).
  static const int storageMarginBytes = 200 * 1024 * 1024;

  final LlmModelSpec spec;
  final ModelInstaller _installer;
  final DeviceStorage _storage;

  /// Reads the current HuggingFace token at download time, mirroring
  /// [EmbedderDownloadManager].
  ///
  /// This model's repo is UNGATED, so the token is not required and its absence
  /// is never an error. It is sent anyway when the user happens to have one:
  /// HuggingFace rate-limits anonymous traffic far more aggressively than
  /// authenticated traffic, and this is a ~2.4 GB transfer that a 429 partway
  /// through would restart from zero (the plugin disables resume on
  /// HuggingFace, whose CDN serves weak ETags).
  final String? Function() _authToken;

  ModelDownloadManager({
    this.spec = LlmModelSpec.active,
    String? Function()? authToken,
    ModelInstaller? installer,
    DeviceStorage? storage,
  })  : _authToken = authToken ?? (() => null),
        _installer = installer ?? FlutterGemmaInstaller(),
        _storage = storage ?? DeviceStorage();

  final _progressController = StreamController<int>.broadcast();
  Future<void>? _inFlight;
  CancelToken? _cancelToken;

  /// Last percent published — see [EmbedderDownloadManager] for why duplicate
  /// and backward ticks are filtered rather than forwarded to the UI.
  int _lastPercent = -1;

  /// Whole-percent (0–100) download progress. Broadcast — safe to re-listen.
  Stream<int> get progress => _progressController.stream;

  /// The most recent percent published, or null when this run hasn't ticked yet.
  ///
  /// A broadcast stream replays nothing, so anything that starts listening
  /// mid-download — the AI sidebar reopened at 60% — would render 0% until the
  /// next whole-percent tick, which on a 2.4 GB transfer can be tens of seconds
  /// of looking stalled. Seed from this instead.
  int? get currentPercent => _lastPercent < 0 ? null : _lastPercent;

  /// Publishes [percent] if it is new, forward-moving, and the stream is open.
  /// A cancelled download can deliver one last callback after [dispose], and
  /// adding to a closed controller throws.
  void _emit(int percent) {
    final clamped = percent.clamp(0, 100);
    if (clamped <= _lastPercent || _progressController.isClosed) return;
    _lastPercent = clamped;
    _progressController.add(clamped);
  }

  bool get isDownloading => _inFlight != null;

  Future<bool> isInstalled() => _installer.isInstalled(spec.filename);

  /// Starts (or joins) the model download. Throws
  /// [InsufficientStorageException] before starting when disk space is short,
  /// [ModelDownloadCancelledException] on cancel, [ModelDownloadException] on
  /// failure. Calling while a download is running returns the same future.
  Future<void> download() {
    if (_inFlight != null) return _inFlight!;
    // Token is created synchronously so a cancel that lands in the first
    // milliseconds (before any await completes) is never lost.
    final token = _cancelToken = CancelToken();
    _lastPercent = -1; // a retry restarts the bar from zero
    return _inFlight = _download(token).whenComplete(() {
      _inFlight = null;
      _cancelToken = null;
    });
  }

  Future<void> _download(CancelToken cancelToken) async {
    if (await _installer.isInstalled(spec.filename)) return;
    if (cancelToken.isCancelled) throw ModelDownloadCancelledException();

    final free = await _storage.freeBytes();
    final required = spec.approxSizeBytes + storageMarginBytes;
    if (free < required) {
      throw InsufficientStorageException(
          requiredBytes: required, availableBytes: free);
    }
    if (cancelToken.isCancelled) throw ModelDownloadCancelledException();

    // Settings token first, falling back to whatever the spec pins. Reading it
    // here rather than at construction means a token pasted while the app is
    // open applies to the very next download attempt.
    final authToken = _authToken()?.trim();
    final effectiveToken =
        (authToken != null && authToken.isNotEmpty) ? authToken : spec.authToken;

    try {
      await _installer.install(
        spec: spec,
        authToken: effectiveToken,
        onProgress: _emit,
        cancelToken: cancelToken,
      );
    } catch (e) {
      if (cancelToken.isCancelled) throw ModelDownloadCancelledException();
      throw translateDownloadFailure(e,
          modelName: spec.displayName,
          hadToken: effectiveToken != null && effectiveToken.isNotEmpty);
    }
  }

  /// Cancels the in-flight download (no-op when none is running).
  void cancelDownload() =>
      _cancelToken?.cancel('User cancelled model download');

  Future<void> delete() => _installer.uninstall(spec.filename);

  void dispose() {
    cancelDownload();
    _progressController.close();
  }
}
