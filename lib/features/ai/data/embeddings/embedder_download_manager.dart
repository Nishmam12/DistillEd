// Manages the on-device EMBEDDING model download — the sibling of
// `model_download_manager.dart`, kept separate because the two differ where it
// matters: this model is GATED (needs the user's HuggingFace token) and is not
// "fetched on first use" (175 MB shouldn't leave over mobile data without an
// explicit tap), so its download is a deliberate, user-triggered act.

import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

import '../llm/device_storage.dart';
import '../llm/llm_exceptions.dart';
import 'embedder_adapter.dart';
import 'embedder_spec.dart';

class EmbedderDownloadManager {
  /// Headroom over the model size so the download can't fill the disk to the
  /// brim (temp file + rename need slack).
  static const int storageMarginBytes = 100 * 1024 * 1024;

  final EmbedderSpec spec;
  final EmbedderInstaller _installer;
  final DeviceStorage _storage;

  /// Reads the current HuggingFace token at download time.
  ///
  /// A callback, not a stored string, on purpose: the token is a per-user
  /// setting the user may paste, change, or clear at any moment, and the
  /// download must use whatever is set WHEN it runs — not whatever was set when
  /// this manager happened to be constructed.
  final String? Function() _authToken;

  EmbedderDownloadManager({
    required String? Function() authToken,
    this.spec = EmbedderSpec.active,
    EmbedderInstaller? installer,
    DeviceStorage? storage,
  })  : _authToken = authToken,
        _installer = installer ?? FlutterGemmaEmbedderInstaller(),
        _storage = storage ?? DeviceStorage();

  final _progressController = StreamController<int>.broadcast();
  Future<void>? _inFlight;
  CancelToken? _cancelToken;

  /// Whole-percent (0–100) download progress. Broadcast — safe to re-listen.
  Stream<int> get progress => _progressController.stream;

  bool get isDownloading => _inFlight != null;

  Future<bool> isInstalled() => _installer.isInstalled(spec);

  /// Starts (or joins) the download. Throws [EmbedderTokenRequiredException]
  /// when no token is set for this gated model, [InsufficientStorageException]
  /// before starting when disk space is short, [ModelDownloadCancelledException]
  /// on cancel, or [ModelDownloadException] on failure. Calling while a
  /// download is running returns the same future.
  Future<void> download() {
    if (_inFlight != null) return _inFlight!;
    final token = _cancelToken = CancelToken();
    return _inFlight = _download(token).whenComplete(() {
      _inFlight = null;
      _cancelToken = null;
    });
  }

  Future<void> _download(CancelToken token) async {
    if (await _installer.isInstalled(spec)) return;
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
        authToken: _authToken(),
        onProgress: _progressController.add,
        cancelToken: token,
      );
    } on EmbedderTokenRequiredException {
      rethrow; // actionable as-is; don't bury it in a generic download error
    } catch (e) {
      if (token.isCancelled) throw ModelDownloadCancelledException();
      throw ModelDownloadException('Embedding model download failed.', e);
    }
  }

  /// Cancels the in-flight download (no-op when none is running).
  void cancelDownload() =>
      _cancelToken?.cancel('User cancelled embedding model download');

  Future<void> delete() => _installer.uninstall(spec);

  void dispose() {
    cancelDownload();
    _progressController.close();
  }
}
