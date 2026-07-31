// Covers the part of the manager the UI leans on to survive a screen change:
// [ModelDownloadManager.currentPercent]. The progress stream is broadcast and
// replays nothing, so a sidebar reopened mid-download reads this instead — if
// it lies, the panel renders 0% on a transfer that is actually most of the way
// through, and looks stalled for tens of seconds.

import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart'
    show CancelToken, ModelFileType, ModelType;
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_exceptions.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';

const _spec = LlmModelSpec(
  displayName: 'Fake Gemma',
  filename: 'fake.litertlm',
  downloadUrl: 'https://example.com/fake.litertlm',
  approxSizeBytes: 100 * 1024 * 1024,
  modelType: ModelType.gemma4,
  fileType: ModelFileType.litertlm,
  maxTokens: 1024,
);

/// Holds the download open until [finish]/[fail] is called, so a test can look
/// at the manager mid-flight and drive progress by hand — the real plugin's
/// ticks arrive over minutes.
class _FakeInstaller implements ModelInstaller {
  bool installed = false;
  var installCount = 0;

  Completer<void>? _pending;
  void Function(int percent)? _onProgress;

  /// True once [install] has been entered and is waiting.
  bool get isRunning => _pending != null && !_pending!.isCompleted;

  void tick(int percent) => _onProgress?.call(percent);

  void finish() {
    installed = true;
    _pending?.complete();
  }

  void fail(Object error) => _pending?.completeError(error);

  @override
  Future<bool> isInstalled(String modelId) async => installed;

  @override
  Future<void> install({
    required LlmModelSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) {
    installCount++;
    _onProgress = onProgress;
    return (_pending = Completer<void>()).future;
  }

  @override
  Future<void> uninstall(String modelId) async => installed = false;
}

class _FakeStorage implements DeviceStorage {
  _FakeStorage(this._free);
  final int _free;
  @override
  Future<int> freeBytes() async => _free;
}

ModelDownloadManager _manager(_FakeInstaller installer) => ModelDownloadManager(
      spec: _spec,
      installer: installer,
      storage: _FakeStorage(1 << 40),
    );

/// Lets the manager's internal awaits (isInstalled, freeBytes) settle.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('currentPercent is null before the first tick', () {
    final manager = _manager(_FakeInstaller());
    expect(manager.currentPercent, isNull);
    manager.dispose();
  });

  test('currentPercent exposes live progress mid-download', () async {
    // The reopen-the-sidebar case: the transfer is at 60% and the broadcast
    // stream owes a late subscriber nothing.
    final installer = _FakeInstaller();
    final manager = _manager(installer);

    final download = manager.download();
    await _settle();
    installer.tick(60);

    expect(manager.currentPercent, 60);
    expect(manager.isDownloading, isTrue);

    installer.finish();
    await download;
    manager.dispose();
  });

  test('currentPercent ignores backward and duplicate ticks', () async {
    // The plugin can re-report a percent, or step back after an internal
    // retry; the bar must never appear to run in reverse.
    final installer = _FakeInstaller();
    final manager = _manager(installer);

    final seen = <int>[];
    final sub = manager.progress.listen(seen.add);

    final download = manager.download();
    await _settle();
    for (final p in [40, 40, 12, 41]) {
      installer.tick(p);
    }
    installer.finish();
    await download;
    await _settle(); // broadcast delivery is async — let the last tick land
    await sub.cancel();

    expect(seen, [40, 41]);
    expect(manager.currentPercent, 41);
    manager.dispose();
  });

  test('a retry restarts the bar rather than resuming the old percent',
      () async {
    final installer = _FakeInstaller();
    final manager = _manager(installer);

    final first = manager.download();
    await _settle();
    installer.tick(70);
    installer.fail(StateError('connection dropped'));
    await expectLater(first, throwsA(isA<LlmException>()));

    // HuggingFace resume is disabled, so a failed attempt genuinely starts
    // over — reporting the old 70% would be a lie.
    final second = manager.download();
    await _settle();
    expect(manager.currentPercent, isNull);

    installer.tick(5);
    expect(manager.currentPercent, 5);

    installer.finish();
    await second;
    manager.dispose();
  });

  test('download joins the in-flight run instead of starting a second one',
      () async {
    // Two surfaces asking at once must not start two 2.4 GB transfers.
    final installer = _FakeInstaller();
    final manager = _manager(installer);

    final first = manager.download();
    await _settle();
    final second = manager.download();

    expect(manager.isDownloading, isTrue);
    installer.finish();
    await Future.wait([first, second]);

    expect(installer.installCount, 1);
    manager.dispose();
  });
}
