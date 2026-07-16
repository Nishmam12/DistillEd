import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/summarize/data/llm/device_storage.dart';
import 'package:inkflow/features/summarize/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/summarize/data/llm/llm_exceptions.dart';
import 'package:inkflow/features/summarize/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/summarize/data/llm/local_llm_service.dart';
import 'package:inkflow/features/summarize/data/llm/model_download_manager.dart';

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

class FakeSession implements LlmSession {
  final Future<String> Function() _respond;
  bool closed = false;
  FakeSession(this._respond);

  @override
  Future<String> respond(String prompt) => _respond();

  @override
  Future<void> close() async => closed = true;
}

class FakeRuntime implements LlmRuntime {
  final Future<String> Function() respond;
  int openSessions = 0;
  int maxConcurrentSessions = 0;
  final sessions = <FakeSession>[];

  FakeRuntime(this.respond);

  @override
  Future<LlmSession> open({
    required LlmModelSpec spec,
    required double temperature,
    required int topK,
    required double topP,
    int? maxOutputTokens,
  }) async {
    openSessions++;
    if (openSessions > maxConcurrentSessions) {
      maxConcurrentSessions = openSessions;
    }
    late FakeSession session;
    session = FakeSession(() async {
      final r = await respond();
      return r;
    });
    sessions.add(session);
    return _CountingSession(session, () => openSessions--);
  }
}

class _CountingSession implements LlmSession {
  final FakeSession _inner;
  final void Function() _onClose;
  _CountingSession(this._inner, this._onClose);

  @override
  Future<String> respond(String prompt) => _inner.respond(prompt);

  @override
  Future<void> close() async {
    await _inner.close();
    _onClose();
  }
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

  group('LocalLlmService', () {
    test('returns trimmed generation and closes the session', () async {
      final runtime = FakeRuntime(() async => '  a fine summary \n');
      final service = LocalLlmService(spec: spec, runtime: runtime);

      final result = await service.generateOnce(prompt: 'summarize this');

      expect(result, 'a fine summary');
      expect(runtime.sessions.single.closed, isTrue,
          reason: 'model must be unloaded after generation');
      expect(runtime.openSessions, 0);
    });

    test('concurrent calls serialize — never two models in memory', () async {
      final runtime = FakeRuntime(
          () => Future.delayed(const Duration(milliseconds: 20), () => 'ok'));
      final service = LocalLlmService(spec: spec, runtime: runtime);

      final results = await Future.wait([
        service.generateOnce(prompt: 'one'),
        service.generateOnce(prompt: 'two'),
        service.generateOnce(prompt: 'three'),
      ]);

      expect(results, ['ok', 'ok', 'ok']);
      expect(runtime.maxConcurrentSessions, 1,
          reason: 'the mutex must keep at most one model loaded');
    });

    test('timeout throws LlmTimeoutException and still unloads', () async {
      final never = Completer<String>();
      final runtime = FakeRuntime(() => never.future);
      final service = LocalLlmService(spec: spec, runtime: runtime);

      await expectLater(
        service.generateOnce(
          prompt: 'hang',
          timeout: const Duration(milliseconds: 30),
        ),
        throwsA(isA<LlmTimeoutException>()),
      );
      expect(runtime.sessions.single.closed, isTrue);
      expect(runtime.openSessions, 0);
    });

    test('a failed call does not deadlock later calls', () async {
      var first = true;
      final runtime = FakeRuntime(() async {
        if (first) {
          first = false;
          throw StateError('engine crash');
        }
        return 'recovered';
      });
      final service = LocalLlmService(spec: spec, runtime: runtime);

      await expectLater(
        service.generateOnce(prompt: 'boom'),
        throwsA(isA<LlmGenerationException>()),
      );
      // The mutex must have been released by the failure.
      expect(await service.generateOnce(prompt: 'again'), 'recovered');
      expect(runtime.sessions.every((s) => s.closed), isTrue);
    });

    test('LlmNotReadyException from the runtime passes through untouched',
        () async {
      final runtime = _NotReadyRuntime();
      final service = LocalLlmService(spec: spec, runtime: runtime);

      expect(
        service.generateOnce(prompt: 'x'),
        throwsA(isA<LlmNotReadyException>()),
      );
    });
  });
}

class _NotReadyRuntime implements LlmRuntime {
  @override
  Future<LlmSession> open({
    required LlmModelSpec spec,
    required double temperature,
    required int topK,
    required double topP,
    int? maxOutputTokens,
  }) async {
    throw LlmNotReadyException();
  }
}
