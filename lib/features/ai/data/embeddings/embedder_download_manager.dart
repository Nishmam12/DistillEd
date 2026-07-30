// Manages the on-device EMBEDDING model download — the sibling of
// `model_download_manager.dart`, kept separate because the two differ where it
// matters: this model is GATED (needs the user's HuggingFace token) and is not
// "fetched on first use" (175 MB shouldn't leave over mobile data without an
// explicit tap), so its download is a deliberate, user-triggered act.

import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

import '../llm/device_storage.dart';
import '../llm/download_failure.dart';
import '../llm/hf_access_check.dart';
import '../llm/hf_token_check.dart';
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

  /// Preflight token probe — see [HuggingFaceAccess].
  final HuggingFaceAccess _access;

  /// Second opinion used only when [_access] refuses — see [HuggingFaceIdentity].
  final HuggingFaceIdentity _identity;

  EmbedderDownloadManager({
    required String? Function() authToken,
    this.spec = EmbedderSpec.active,
    EmbedderInstaller? installer,
    DeviceStorage? storage,
    HuggingFaceAccess? access,
    HuggingFaceIdentity? identity,
  })  : _authToken = authToken,
        _installer = installer ?? FlutterGemmaEmbedderInstaller(),
        _storage = storage ?? DeviceStorage(),
        _access = access ?? DioHuggingFaceAccess(),
        _identity = identity ?? DioHuggingFaceIdentity();

  final _progressController = StreamController<int>.broadcast();
  Future<void>? _inFlight;
  CancelToken? _cancelToken;

  /// Last percent published, so duplicate ticks from the plugin don't wake the
  /// UI. The two install legs report 0–100 each and are rescaled into one bar;
  /// clamping to the max seen also stops the bar ever running backwards.
  int _lastPercent = -1;

  /// Whole-percent (0–100) download progress. Broadcast — safe to re-listen.
  Stream<int> get progress => _progressController.stream;

  /// Publishes [percent] if it is new, forward-moving, and the stream is still
  /// open. Guarding on [StreamController.isClosed] matters because a cancelled
  /// download can still deliver one last progress callback after [dispose],
  /// and adding to a closed controller throws.
  void _emit(int percent) {
    final clamped = percent.clamp(0, 100);
    if (clamped <= _lastPercent || _progressController.isClosed) return;
    _lastPercent = clamped;
    _progressController.add(clamped);
  }

  bool get isDownloading => _inFlight != null;

  Future<bool> isInstalled() => _installer.isInstalled(spec);

  /// True when a previous attempt left exactly one of the two files behind.
  /// The UI uses this to offer a way to reclaim the space — see
  /// [EmbedderInstaller.isPartiallyInstalled].
  Future<bool> isPartiallyInstalled() => _installer.isPartiallyInstalled(spec);

  /// Starts (or joins) the download. Throws [EmbedderTokenRequiredException]
  /// when no token is set for this gated model, [InsufficientStorageException]
  /// before starting when disk space is short, [ModelDownloadCancelledException]
  /// on cancel, or [ModelDownloadException] on failure. Calling while a
  /// download is running returns the same future.
  Future<void> download() {
    if (_inFlight != null) return _inFlight!;
    final token = _cancelToken = CancelToken();
    _lastPercent = -1; // a retry restarts the bar from zero
    return _inFlight = _download(token).whenComplete(() {
      _inFlight = null;
      _cancelToken = null;
    });
  }

  Future<void> _download(CancelToken cancelToken) async {
    if (await _installer.isInstalled(spec)) return;
    if (cancelToken.isCancelled) throw ModelDownloadCancelledException();

    final authToken = _authToken()?.trim();
    final hadToken = authToken != null && authToken.isNotEmpty;
    if (spec.needsAuth && !hadToken) throw EmbedderTokenRequiredException(spec);

    final free = await _storage.freeBytes();
    final required = spec.approxSizeBytes + storageMarginBytes;
    if (free < required) {
      throw InsufficientStorageException(
          requiredBytes: required, availableBytes: free);
    }
    if (cancelToken.isCancelled) throw ModelDownloadCancelledException();

    await _verifyAccess(authToken, hadToken: hadToken);
    if (cancelToken.isCancelled) throw ModelDownloadCancelledException();

    try {
      await _installer.install(
        spec: spec,
        authToken: authToken,
        onProgress: _emit,
        cancelToken: cancelToken,
      );
    } catch (e) {
      if (cancelToken.isCancelled) throw ModelDownloadCancelledException();
      final failure = translateDownloadFailure(e,
          modelName: spec.displayName, hadToken: hadToken);
      // An auth bounce mid-download has exactly the same two possible causes
      // as one at preflight, but `translateDownloadFailure` cannot tell them
      // apart — the plugin hands it an error variant, not HuggingFace's
      // headers. Re-run the real diagnosis so the user isn't told their token
      // is dead when the licence is what's missing. (Rare: the preflight
      // normally catches this first.)
      if (failure is ModelAuthException && hadToken) {
        throw await _diagnoseRefusal(authToken,
            hadToken: true, gateBlamed: spec.needsAuth);
      }
      throw failure;
    }
  }

  /// Fails fast when HuggingFace will refuse this token anyway — and says
  /// WHICH of the two possible reasons applies.
  ///
  /// Two files totalling ~175 MB are about to be pulled; discovering a
  /// non-accepted licence at 60% wastes minutes and mobile data, and the error
  /// that surfaces then is no more informative than the one available now.
  /// [HfAccess.unknown] deliberately falls through to the download — see
  /// `hf_access_check.dart` on why this probe may only ever veto, never block.
  Future<void> _verifyAccess(String? authToken, {required bool hadToken}) async {
    final access = await _access.check(spec.modelUrl, token: authToken);
    switch (access) {
      case HfAccess.gated:
      case HfAccess.unauthorized:
        throw await _diagnoseRefusal(authToken,
            hadToken: hadToken, gateBlamed: access == HfAccess.gated);
      case HfAccess.notFound:
        throw ModelDownloadException(
            '${spec.displayName} is no longer available at its download URL. '
            'This needs an app update — please report it.');
      case HfAccess.ok:
      case HfAccess.unknown:
        return;
    }
  }

  /// Works out which auth failure this actually is, so the user is told the one
  /// thing that will fix it.
  ///
  /// HuggingFace will not say: a gated repo answers the same way for a missing
  /// token, a dead token, and a live token whose owner never accepted the
  /// licence (verified 2026-07-30 — identical `401 + GatedRepo` for all of
  /// them). So we ask a different question instead, one that involves no repo:
  /// does this token authenticate at `/api/whoami-v2`? If it does, the
  /// credential is sound and the gate is the blocker.
  ///
  /// Runs only on an already-failed path, so the extra round trip costs a
  /// successful download nothing.
  ///
  /// [gateBlamed] is whether HuggingFace pointed at the gate rather than at the
  /// credential — it only decides the tie-break when whoami itself cannot
  /// answer.
  Future<LlmException> _diagnoseRefusal(String? authToken,
      {required bool hadToken, required bool gateBlamed}) async {
    if (!hadToken) {
      return ModelAuthException(spec.displayName, hadToken: false);
    }

    final info = await _identity.whoami(authToken!);
    return switch (info.status) {
      // The credential is dead. Says nothing about the licence, and telling
      // someone to go accept one would waste their time.
      HfTokenStatus.invalid =>
        ModelAuthException(spec.displayName, hadToken: true),

      // Authenticates but cannot read gated repos — accepting the licence
      // would not help, so this gets its own instruction.
      HfTokenStatus.valid when info.isFineGrained =>
        ModelTokenScopeException(spec.displayName,
            modelPageUrl: spec.modelPageUrl),

      HfTokenStatus.valid => ModelLicenceNotAcceptedException(spec.displayName,
          modelPageUrl: spec.modelPageUrl, username: info.username),

      // whoami itself gave no answer (offline, timeout). Fall back to whatever
      // HuggingFace already told us: an explicit `GatedRepo` header is real
      // evidence about the gate, so lead with the licence — without a username
      // to name, the message stays appropriately non-committal. Anything else
      // is unattributed, so blame the credential rather than send the user off
      // to accept a licence that may be beside the point.
      HfTokenStatus.unknown => gateBlamed
          ? ModelLicenceNotAcceptedException(spec.displayName,
              modelPageUrl: spec.modelPageUrl)
          : ModelAuthException(spec.displayName, hadToken: true),
    };
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
