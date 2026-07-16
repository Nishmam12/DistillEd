import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_exceptions.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';

// ---- Fakes ------------------------------------------------------------------

class FakeInstaller implements ModelInstaller {
  bool installed = false;
  int installCalls = 0;
  bool failInstall = false;
  Duration installDelay = Duration.zero;

  @override
  Future<bool> isInstalled(String modelId) async => installed;

  @override
  Future<void> install({
    required LlmModelSpec spec,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    installCalls++;
    for (final p in [10, 50, 100]) {
      await Future<void>.delayed(installDelay);
      if (cancelToken?.isCancelled ?? false) {
        throw Exception('download interrupted');
      }
      onProgress?.call(p);
    }
    if (failInstall) throw Exception('server error 500');
    installed = true;
  }

  @override
  Future<void> uninstall(String modelId) async => installed = false;
}

class FakeStorage implements DeviceStorage {
  int free;
  FakeStorage(this.free);
  @override
  Future<int> freeBytes() async => free;
}

// ---- Tests ------------------------------------------------------------------

void main() {
  const spec = LlmModelSpec.gemma4E2B;

  group('ModelDownloadManager', () {
    test('refuses to download without enough free space', () async {
      final manager = ModelDownloadManager(
        spec: spec,
        installer: FakeInstaller(),
        storage: FakeStorage(spec.approxSizeBytes ~/ 2), // way too little
      );

      expect(manager.download(), throwsA(isA<InsufficientStorageException>()));
    });

    test('downloads with progress events when space is available', () async {
      final installer = FakeInstaller();
      final manager = ModelDownloadManager(
        spec: spec,
        installer: installer,
        storage: FakeStorage(spec.approxSizeBytes * 2),
      );

      final events = <int>[];
      final sub = manager.progress.listen(events.add);
      await manager.download();
      await Future<void>.delayed(Duration.zero);

      expect(installer.installed, isTrue);
      expect(events, [10, 50, 100]);
      await sub.cancel();
    });

    test('already-installed model skips download entirely', () async {
      final installer = FakeInstaller()..installed = true;
      final manager = ModelDownloadManager(
        spec: spec,
        installer: installer,
        storage: FakeStorage(0), // even with no space: nothing to download
      );

      await manager.download();
      expect(installer.installCalls, 0);
    });

    test('concurrent download() calls join the same in-flight future',
        () async {
      final installer = FakeInstaller()
        ..installDelay = const Duration(milliseconds: 10);
      final manager = ModelDownloadManager(
        spec: spec,
        installer: installer,
        storage: FakeStorage(spec.approxSizeBytes * 2),
      );

      await Future.wait([manager.download(), manager.download()]);
      expect(installer.installCalls, 1);
    });

    test('cancel surfaces as DownloadCancelledException', () async {
      final installer = FakeInstaller()
        ..installDelay = const Duration(milliseconds: 50);
      final manager = ModelDownloadManager(
        spec: spec,
        installer: installer,
        storage: FakeStorage(spec.approxSizeBytes * 2),
      );

      final future = manager.download();
      manager.cancelDownload();
      expect(future, throwsA(isA<ModelDownloadCancelledException>()));
    });

    test('failure surfaces as ModelDownloadException', () async {
      final installer = FakeInstaller()..failInstall = true;
      final manager = ModelDownloadManager(
        spec: spec,
        installer: installer,
        storage: FakeStorage(spec.approxSizeBytes * 2),
      );

      expect(manager.download(), throwsA(isA<ModelDownloadException>()));
    });
  });

}
