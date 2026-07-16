// Manages the on-device LLM download: free-space check, progress stream,
// cancellation, delete. Resumability and retry (exponential backoff, resume
// of partial files) come from flutter_gemma's downloader; downloads over
// 500 MB automatically run in an Android foreground service so they survive
// the app being backgrounded.

import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

import 'device_storage.dart';
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

  ModelDownloadManager({
    this.spec = LlmModelSpec.active,
    ModelInstaller? installer,
    DeviceStorage? storage,
  })  : _installer = installer ?? FlutterGemmaInstaller(),
        _storage = storage ?? DeviceStorage();

  final _progressController = StreamController<int>.broadcast();
  Future<void>? _inFlight;
  CancelToken? _cancelToken;

  /// Whole-percent (0–100) download progress. Broadcast — safe to re-listen.
  Stream<int> get progress => _progressController.stream;

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
    return _inFlight = _download(token).whenComplete(() {
      _inFlight = null;
      _cancelToken = null;
    });
  }

  Future<void> _download(CancelToken token) async {
    if (await _installer.isInstalled(spec.filename)) return;
    if (token.isCancelled) throw ModelDownloadCancelledException();

    final free = await _storage.freeBytes();
    final required = spec.approxSizeBytes + storageMarginBytes;
    if (free < required) {
      throw InsufficientStorageException(
          requiredBytes: required, availableBytes: free);
    }

    try {
      await _installer.install(
        spec: spec,
        onProgress: _progressController.add,
        cancelToken: token,
      );
    } catch (e) {
      if (token.isCancelled) throw ModelDownloadCancelledException();
      throw ModelDownloadException('Model download failed.', e);
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
