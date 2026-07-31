// The download must outlive the screen that started it. These tests pin the
// behaviours that make that true: a notifier read fresh mid-download reports
// the real percent instead of offering the button again, and a run started by
// some other AI surface still reaches a terminal state here.

import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart'
    show CancelToken, ModelFileType, ModelType;
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_exceptions.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/presentation/model_download_notifier.dart';

const _spec = LlmModelSpec(
  displayName: 'Fake Gemma',
  filename: 'fake.litertlm',
  downloadUrl: 'https://example.com/fake.litertlm',
  approxSizeBytes: 100 * 1024 * 1024,
  modelType: ModelType.gemma4,
  fileType: ModelFileType.litertlm,
  maxTokens: 1024,
);

class _FakeInstaller implements ModelInstaller {
  bool installed = false;
  Completer<void>? _pending;
  void Function(int percent)? _onProgress;
  CancelToken? _cancelToken;

  void tick(int percent) => _onProgress?.call(percent);

  void finish() {
    installed = true;
    _pending?.complete();
  }

  void fail(Object error) => _pending?.completeError(error);

  /// Mirrors the plugin: a cancelled token surfaces as a thrown install.
  void honourCancel() {
    if (_cancelToken?.isCancelled ?? false) {
      _pending?.completeError(StateError('cancelled'));
    }
  }

  @override
  Future<bool> isInstalled(String modelId) async => installed;

  @override
  Future<void> install({
    required LlmModelSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) {
    _onProgress = onProgress;
    _cancelToken = cancelToken;
    return (_pending = Completer<void>()).future;
  }

  @override
  Future<void> uninstall(String modelId) async => installed = false;
}

class _FakeStorage implements DeviceStorage {
  @override
  Future<int> freeBytes() async => 1 << 40;
}

ModelDownloadManager _manager(_FakeInstaller installer) => ModelDownloadManager(
      spec: _spec,
      installer: installer,
      storage: _FakeStorage(),
    );

/// Lets the manager's internal awaits and the progress stream settle.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('starts idle', () {
    final notifier = LlmDownloadNotifier(_manager(_FakeInstaller()));
    expect(notifier.state, isA<LlmDownloadIdle>());
  });

  test('start walks idle → running → installed', () async {
    final installer = _FakeInstaller();
    final notifier = LlmDownloadNotifier(_manager(installer));

    final started = notifier.start();
    expect(notifier.state, isA<LlmDownloadRunning>());

    await _settle();
    installer.tick(37);
    await _settle();
    expect((notifier.state as LlmDownloadRunning).percent, 37);

    installer.finish();
    await started;
    expect(notifier.state, isA<LlmDownloadInstalled>());
  });

  test('a notifier created mid-download reports the live percent, not zero',
      () async {
    // The bug this whole change exists for: close the AI sidebar at 60%,
    // reopen it, and the panel used to offer "Download model" again.
    final installer = _FakeInstaller();
    final manager = _manager(installer);

    final download = manager.download();
    await _settle();
    installer.tick(60);
    await _settle();

    final reopened = LlmDownloadNotifier(manager);
    expect(reopened.state, isA<LlmDownloadRunning>());
    expect((reopened.state as LlmDownloadRunning).percent, 60);

    // …and it still sees the run through to completion.
    installer.finish();
    await download;
    await _settle();
    expect(reopened.state, isA<LlmDownloadInstalled>());
  });

  test('adopts a download started by another surface', () async {
    // Explain/Ask/Quiz share the one manager. Without adoption this notifier
    // would mirror progress up to 100 and then sit there forever.
    final installer = _FakeInstaller();
    final manager = _manager(installer);
    final notifier = LlmDownloadNotifier(manager);

    final elsewhere = manager.download();
    await _settle();
    installer.tick(12);
    await _settle();
    expect((notifier.state as LlmDownloadRunning).percent, 12);

    installer.finish();
    await elsewhere;
    await _settle();
    expect(notifier.state, isA<LlmDownloadInstalled>());
  });

  test('a typed failure surfaces its own message verbatim', () async {
    // Auth, licence, rate-limit and storage messages are written for the user
    // and name the actual fix; flattening them to "check your connection" sent
    // people to fix their wifi over an unaccepted HuggingFace licence.
    final installer = _FakeInstaller();
    final notifier = LlmDownloadNotifier(_manager(installer));

    final started = notifier.start();
    await _settle();
    installer.fail(InsufficientStorageException(
        requiredBytes: 2 * 1024 * 1024 * 1024, availableBytes: 100 * 1024 * 1024));
    await started;

    expect(notifier.state, isA<LlmDownloadFailed>());
    expect((notifier.state as LlmDownloadFailed).message, contains('MB free'));
  });

  test('an unclassified plugin error still names the model', () async {
    // The manager translates everything it catches, so even a bare StateError
    // arrives here already typed — the notifier's own generic fallback is a
    // backstop, not the normal path.
    final installer = _FakeInstaller();
    final notifier = LlmDownloadNotifier(_manager(installer));

    final started = notifier.start();
    await _settle();
    installer.fail(StateError('socket died'));
    await started;

    expect((notifier.state as LlmDownloadFailed).message,
        contains('Could not download Fake Gemma'));
  });

  test('cancel returns to idle', () async {
    final installer = _FakeInstaller();
    final manager = _manager(installer);
    final notifier = LlmDownloadNotifier(manager);

    final started = notifier.start();
    await _settle();
    installer.tick(20);
    await _settle();

    notifier.cancel();
    installer.honourCancel();
    await started;

    expect(notifier.state, isA<LlmDownloadIdle>());
  });

  test('clearFailure re-offers the download', () async {
    final installer = _FakeInstaller();
    final notifier = LlmDownloadNotifier(_manager(installer));

    final started = notifier.start();
    await _settle();
    installer.fail(StateError('boom'));
    await started;
    expect(notifier.state, isA<LlmDownloadFailed>());

    notifier.clearFailure();
    expect(notifier.state, isA<LlmDownloadIdle>());
  });

  test('start is a no-op while a run is already in flight', () async {
    final installer = _FakeInstaller();
    final notifier = LlmDownloadNotifier(_manager(installer));

    final first = notifier.start();
    await _settle();
    installer.tick(45);
    await _settle();

    // Tapping the button again must not snap the bar back to 0%.
    await notifier.start();
    expect((notifier.state as LlmDownloadRunning).percent, 45);

    installer.finish();
    await first;
  });
}
