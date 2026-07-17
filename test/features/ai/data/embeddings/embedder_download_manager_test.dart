import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/embeddings/embedder_adapter.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_download_manager.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_spec.dart';
import 'package:inkflow/features/ai/data/llm/device_storage.dart';
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
  _FakeInstaller({this.installed = false, this.installThrows});

  bool installed;
  Object? installThrows;

  String? sawToken;
  var installCount = 0;
  var uninstallCount = 0;
  final progressSteps = <int>[];

  @override
  Future<bool> isInstalled(EmbedderSpec spec) async => installed;

  @override
  Future<void> install({
    required EmbedderSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    installCount++;
    sawToken = authToken;
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
  }
}

class _FakeStorage implements DeviceStorage {
  _FakeStorage(this._free);
  final int _free;
  @override
  Future<int> freeBytes() async => _free;
}

EmbedderDownloadManager _build(
  _FakeInstaller installer, {
  String? token = 'hf_test',
  int freeBytes = 1024 * 1024 * 1024,
}) =>
    EmbedderDownloadManager(
      spec: _spec,
      authToken: () => token,
      installer: installer,
      storage: _FakeStorage(freeBytes),
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
}
