import 'package:flutter_gemma/flutter_gemma.dart'
    show CancelToken, DownloadError, DownloadException;
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/embeddings/embedder_adapter.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_download_manager.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_spec.dart';
import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/hf_access_check.dart';
import 'package:inkflow/features/ai/data/llm/hf_token_check.dart';
import 'package:inkflow/features/ai/data/llm/llm_exceptions.dart';

const _spec = EmbedderSpec(
  displayName: 'Fake Embedder',
  modelId: 'fake-v1',
  modelUrl: 'https://example.com/model.tflite',
  tokenizerUrl: 'https://example.com/sentencepiece.model',
  approxSizeBytes: 100 * 1024 * 1024,
  dimensions: 3,
  needsAuth: true,
);

class _FakeInstaller implements EmbedderInstaller {
  _FakeInstaller({
    this.installed = false,
    this.installThrows,
    this.partiallyInstalled = false,
  });

  bool installed;
  Object? installThrows;
  bool partiallyInstalled;

  String? sawToken;
  var installCount = 0;
  var uninstallCount = 0;
  final progressSteps = <int>[];

  /// The manager's progress sink, kept so a test can fire it late — the real
  /// plugin can deliver a tick after the manager has been disposed.
  void Function(int percent)? lastOnProgress;

  @override
  Future<bool> isInstalled(EmbedderSpec spec) async => installed;

  @override
  Future<bool> isPartiallyInstalled(EmbedderSpec spec) async =>
      partiallyInstalled;

  @override
  Future<void> install({
    required EmbedderSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    installCount++;
    sawToken = authToken;
    lastOnProgress = onProgress;
    if (installThrows != null) throw installThrows!;
    for (final p in progressSteps) {
      onProgress?.call(p);
    }
    installed = true;
  }

  @override
  Future<void> uninstall(EmbedderSpec spec) async {
    uninstallCount++;
    installed = false;
    partiallyInstalled = false;
  }
}

class _FakeStorage implements DeviceStorage {
  _FakeStorage(this._free);
  final int _free;
  @override
  Future<int> freeBytes() async => _free;
}

class _FakeAccess implements HuggingFaceAccess {
  _FakeAccess([this.result = HfAccess.ok]);
  final HfAccess result;
  String? sawToken;
  var checkCount = 0;

  @override
  Future<HfAccess> check(String url, {String? token}) async {
    checkCount++;
    sawToken = token;
    return result;
  }
}

class _FakeIdentity implements HuggingFaceIdentity {
  _FakeIdentity([this.info = const HfTokenInfo(status: HfTokenStatus.valid)]);
  final HfTokenInfo info;
  String? sawToken;
  var whoamiCount = 0;

  @override
  Future<HfTokenInfo> whoami(String token) async {
    whoamiCount++;
    sawToken = token;
    return info;
  }
}

EmbedderDownloadManager _build(
  _FakeInstaller installer, {
  String? token = 'hf_test',
  int freeBytes = 1024 * 1024 * 1024,
  HuggingFaceAccess? access,
  HuggingFaceIdentity? identity,
}) =>
    EmbedderDownloadManager(
      spec: _spec,
      authToken: () => token,
      installer: installer,
      storage: _FakeStorage(freeBytes),
      access: access ?? _FakeAccess(),
      identity: identity ?? _FakeIdentity(),
    );

void main() {
  test('download passes the CURRENT token to the installer', () async {
    final installer = _FakeInstaller();
    await _build(installer, token: 'hf_live').download();

    expect(installer.sawToken, 'hf_live');
    expect(installer.installed, isTrue);
  });

  test('the token is read at download time, not construction time', () async {
    final installer = _FakeInstaller();
    var token = '';
    final manager = EmbedderDownloadManager(
      spec: _spec,
      authToken: () => token, // e.g. the user pastes it after opening Settings
      installer: installer,
      storage: _FakeStorage(1024 * 1024 * 1024),
      access: _FakeAccess(),
    );

    token = 'hf_pasted_later';
    await manager.download();
    expect(installer.sawToken, 'hf_pasted_later');
  });

  test('a token-required failure propagates unwrapped, still actionable',
      () async {
    final installer =
        _FakeInstaller(installThrows: EmbedderTokenRequiredException(_spec));

    await expectLater(
      _build(installer, token: null).download(),
      throwsA(isA<EmbedderTokenRequiredException>()),
    );
  });

  test('too little disk space fails before any download starts', () async {
    final installer = _FakeInstaller();
    await expectLater(
      _build(installer, freeBytes: 1024).download(),
      throwsA(isA<InsufficientStorageException>()),
    );
    expect(installer.installCount, 0);
  });

  test('an already-installed model is a no-op', () async {
    final installer = _FakeInstaller(installed: true);
    await _build(installer).download();
    expect(installer.installCount, 0);
  });

  test('progress is forwarded on the stream', () async {
    final installer = _FakeInstaller()..progressSteps.addAll([0, 50, 100]);
    final manager = _build(installer);

    final seen = <int>[];
    final sub = manager.progress.listen(seen.add);
    await manager.download();
    // The broadcast controller delivers asynchronously; let those events land
    // before cancelling (cancel discards anything still queued).
    await pumpEventQueue();
    await sub.cancel();

    expect(seen, [0, 50, 100]);
  });

  test('a generic failure is wrapped as ModelDownloadException', () async {
    final installer = _FakeInstaller(installThrows: StateError('network'));
    await expectLater(
      _build(installer).download(),
      throwsA(isA<ModelDownloadException>()),
    );
  });

  test('concurrent download() calls share one in-flight download', () async {
    final installer = _FakeInstaller();
    final manager = _build(installer);

    await Future.wait([manager.download(), manager.download()]);
    expect(installer.installCount, 1);
  });

  test('delete uninstalls both files', () async {
    final installer = _FakeInstaller(installed: true);
    await _build(installer).delete();
    expect(installer.uninstallCount, 1);
    expect(installer.installed, isFalse);
  });

  group('half-finished installs', () {
    // flutter_gemma installs the model and tokenizer as two independent,
    // separately-recorded steps with no transaction and no cleanup on the
    // embedding path, so a failure on the second leg strands the first.
    test('a stranded file is reported as partial, not as absent', () async {
      final manager = _build(_FakeInstaller(partiallyInstalled: true));
      expect(await manager.isInstalled(), isFalse);
      expect(await manager.isPartiallyInstalled(), isTrue);
    });

    test('a clean slate is neither installed nor partial', () async {
      final manager = _build(_FakeInstaller());
      expect(await manager.isInstalled(), isFalse);
      expect(await manager.isPartiallyInstalled(), isFalse);
    });

    test('deleting a partial install reclaims the space', () async {
      final installer = _FakeInstaller(partiallyInstalled: true);
      final manager = _build(installer);

      await manager.delete();

      expect(installer.uninstallCount, 1);
      expect(await manager.isPartiallyInstalled(), isFalse);
    });
  });

  group('preflight access check', () {
    test('a blank token fails before any network call at all', () async {
      final installer = _FakeInstaller();
      final access = _FakeAccess();

      await expectLater(
        _build(installer, token: '  ', access: access).download(),
        throwsA(isA<EmbedderTokenRequiredException>()),
      );
      expect(access.checkCount, 0);
      expect(installer.installCount, 0);
    });

    test('the probe is sent the same token the download would use', () async {
      final access = _FakeAccess();
      await _build(_FakeInstaller(), token: 'hf_live', access: access)
          .download();
      expect(access.sawToken, 'hf_live');
    });

    test('an unreachable probe does NOT block the download (fail-open)',
        () async {
      final installer = _FakeInstaller();
      await _build(installer, access: _FakeAccess(HfAccess.unknown)).download();
      expect(installer.installCount, 1);
      expect(installer.installed, isTrue);
    });
  });

  // HuggingFace answers a gated repo identically whether the token is missing,
  // dead, or merely un-licensed (verified 2026-07-30: byte-identical
  // `401 + X-Error-Code: GatedRepo` for no token and for a garbage token). The
  // manager therefore asks a second, repo-independent question — whoami — and
  // these tests pin the resulting diagnosis, because getting it wrong sends
  // the user to fix something that was never broken.
  group('diagnosing a refusal', () {
    // Every case here shares this invariant, and it is the one that matters
    // most: no amount of diagnosis may start a 185 MB transfer.
    void expectNothingDownloaded(_FakeInstaller installer) =>
        expect(installer.installCount, 0,
            reason: 'must not start the download');

    test('gated + a token that whoami accepts ⇒ the LICENCE is the problem',
        () async {
      final installer = _FakeInstaller();
      await expectLater(
        _build(installer,
                access: _FakeAccess(HfAccess.gated),
                identity: _FakeIdentity(const HfTokenInfo(
                    status: HfTokenStatus.valid,
                    username: 'afnan',
                    role: 'read')))
            .download(),
        throwsA(isA<ModelLicenceNotAcceptedException>()
            .having((e) => e.username, 'username', 'afnan')
            .having((e) => e.modelPageUrl, 'modelPageUrl', isNotEmpty)
            // Naming the account is what convinces the user their token is
            // fine and stops them re-pasting it.
            .having((e) => e.message, 'message', contains('afnan'))),
      );
      expectNothingDownloaded(installer);
    });

    test('gated + a token whoami rejects ⇒ the TOKEN is the problem', () async {
      final installer = _FakeInstaller();
      await expectLater(
        _build(installer,
                access: _FakeAccess(HfAccess.gated),
                identity: _FakeIdentity(
                    const HfTokenInfo(status: HfTokenStatus.invalid)))
            .download(),
        throwsA(isA<ModelAuthException>()
            .having((e) => e.hadToken, 'hadToken', isTrue)
            // Must NOT send them off to accept a licence — that would not fix
            // a revoked token.
            .having((e) => e.message, 'message', isNot(contains('licence')))),
      );
      expectNothingDownloaded(installer);
    });

    test('gated + a fine-grained token ⇒ the SCOPE is the problem', () async {
      final installer = _FakeInstaller();
      await expectLater(
        _build(installer,
                access: _FakeAccess(HfAccess.gated),
                identity: _FakeIdentity(const HfTokenInfo(
                    status: HfTokenStatus.valid,
                    username: 'afnan',
                    role: 'fineGrained')))
            .download(),
        // Accepting the licence would not help this user, so they must not be
        // told to: a fine-grained token without gated-repo access fails again
        // identically afterwards.
        throwsA(isA<ModelTokenScopeException>()
            .having((e) => e.message, 'message', contains('fine-grained'))),
      );
      expectNothingDownloaded(installer);
    });

    test('gated + whoami unreachable ⇒ trust the GatedRepo header', () async {
      final installer = _FakeInstaller();
      await expectLater(
        _build(installer,
                access: _FakeAccess(HfAccess.gated),
                identity: _FakeIdentity(const HfTokenInfo.unknown()))
            .download(),
        // Offline, so the token is unverified — but HuggingFace explicitly
        // blamed the gate, which is real evidence. Lead with the licence, and
        // without a username to cite.
        throwsA(isA<ModelLicenceNotAcceptedException>()
            .having((e) => e.username, 'username', isNull)),
      );
      expectNothingDownloaded(installer);
    });

    test('a refusal HuggingFace did NOT blame on the gate ⇒ blame the token',
        () async {
      final installer = _FakeInstaller();
      await expectLater(
        _build(installer,
                access: _FakeAccess(HfAccess.unauthorized),
                identity: _FakeIdentity(const HfTokenInfo.unknown()))
            .download(),
        throwsA(isA<ModelAuthException>()),
      );
      expectNothingDownloaded(installer);
    });

    test('whoami sees the same token the download would use', () async {
      final identity = _FakeIdentity();
      await expectLater(
        _build(_FakeInstaller(),
                token: 'hf_live',
                access: _FakeAccess(HfAccess.gated),
                identity: identity)
            .download(),
        throwsA(isA<LlmException>()),
      );
      expect(identity.sawToken, 'hf_live');
    });

    test('a successful preflight never spends a whoami round trip', () async {
      final identity = _FakeIdentity();
      await _build(_FakeInstaller(), identity: identity).download();
      expect(identity.whoamiCount, 0,
          reason: 'diagnosis must not cost the happy path anything');
    });
  });

  group('failure translation', () {
    test('a 403 mid-download is diagnosed, not guessed', () async {
      final installer = _FakeInstaller(
          installThrows: const DownloadException(DownloadError.forbidden()));

      // The plugin hands us an error variant with no HuggingFace headers
      // attached, so this arrives as an undifferentiated auth failure. It must
      // still go through whoami rather than default to blaming the token —
      // otherwise a mid-download bounce reintroduces exactly the misleading
      // message this whole path exists to remove.
      await expectLater(
        _build(installer,
                identity: _FakeIdentity(const HfTokenInfo(
                    status: HfTokenStatus.valid, username: 'afnan')))
            .download(),
        throwsA(isA<ModelLicenceNotAcceptedException>()
            .having((e) => e.message, 'message', contains('licence'))),
      );
    });

    test('a 403 mid-download with a dead token still blames the token',
        () async {
      final installer = _FakeInstaller(
          installThrows: const DownloadException(DownloadError.forbidden()));

      await expectLater(
        _build(installer,
                identity: _FakeIdentity(
                    const HfTokenInfo(status: HfTokenStatus.invalid)))
            .download(),
        throwsA(isA<ModelAuthException>()),
      );
    });

    test('a 429 becomes a rate-limit error', () async {
      final installer = _FakeInstaller(
          installThrows: const DownloadException(DownloadError.rateLimited()));
      await expectLater(
        _build(installer).download(),
        throwsA(isA<ModelRateLimitedException>()),
      );
    });

    test('a network drop becomes a connectivity error', () async {
      final installer = _FakeInstaller(
          installThrows:
              const DownloadException(DownloadError.network('closed')));
      await expectLater(
        _build(installer).download(),
        throwsA(isA<ModelNetworkException>()),
      );
    });

    test("the plugin's own cancel signal maps to our cancelled exception",
        () async {
      final installer = _FakeInstaller(
          installThrows: const DownloadException(DownloadError.canceled()));
      await expectLater(
        _build(installer).download(),
        throwsA(isA<ModelDownloadCancelledException>()),
      );
    });
  });

  group('progress hygiene', () {
    test('duplicate and backward ticks never reach the UI', () async {
      // The two install legs each report 0-100 and are rescaled into one bar,
      // so repeats and regressions are normal input here.
      final installer = _FakeInstaller()
        ..progressSteps.addAll([0, 5, 5, 5, 40, 12, 40, 97, 100]);
      final manager = _build(installer);

      final seen = <int>[];
      final sub = manager.progress.listen(seen.add);
      await manager.download();
      await pumpEventQueue();
      await sub.cancel();

      expect(seen, [0, 5, 40, 97, 100]);
    });

    test('a progress callback arriving after dispose does not throw', () async {
      final installer = _FakeInstaller();
      final manager = _build(installer);
      await manager.download();

      // Adding to a closed StreamController throws, and a cancelled download
      // can still deliver one last tick after dispose.
      manager.dispose();
      expect(() => installer.lastOnProgress!(50), returnsNormally);
    });
  });
}
