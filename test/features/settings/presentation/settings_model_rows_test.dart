// The Settings rows for a model refresh themselves after a download, a delete or
// a clean-up. Each refresh once ran a Future-returning call inside setState,
// which Flutter refuses, so the row kept its old state and the student saw
// nothing change. These run the real screen against fakes for the managers.

import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_download_manager.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_spec.dart';
import 'package:inkflow/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/data/llm/model_storage_cleaner.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';
import 'package:inkflow/features/audio/data/edge_ai_speech.dart';
import 'package:inkflow/features/audio/presentation/transcription_providers.dart';
import 'package:inkflow/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeEmbedder implements EmbedderDownloadManager {
  _FakeEmbedder({required this.installed});

  bool installed;

  @override
  EmbedderSpec get spec => EmbedderSpec.active;

  @override
  Stream<int> get progress => const Stream<int>.empty();

  @override
  bool get isDownloading => false;

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Future<bool> isPartiallyInstalled() async => false;

  @override
  Future<void> download() async {
    installed = true;
  }

  @override
  void cancelDownload() {}

  @override
  Future<void> delete() async {
    installed = false;
  }

  @override
  void dispose() {}
}

class _FakeLlm implements ModelDownloadManager {
  @override
  LlmModelSpec get spec => LlmModelSpec.active;

  @override
  Stream<int> get progress => const Stream<int>.empty();

  @override
  int? get currentPercent => null;

  @override
  bool get isDownloading => false;

  @override
  Future<bool> isInstalled() async => false;

  @override
  Future<void> download() async {}

  @override
  void cancelDownload() {}

  @override
  Future<void> delete() async {}

  @override
  void dispose() {}
}

class _FakeHandwriting implements HandwritingRecognitionService {
  @override
  Future<bool> isModelDownloaded(String languageCode) async => false;

  @override
  Future<bool> deleteModel(String languageCode) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCleaner implements ModelStorageCleaner {
  _FakeCleaner(this.orphans);

  List<OrphanedModelFile> orphans;
  bool cleaned = false;

  @override
  Future<List<OrphanedModelFile>> findOrphans() async => orphans;

  @override
  Future<int> cleanup() async {
    cleaned = true;
    final freed = orphans.fold<int>(0, (sum, o) => sum + o.sizeBytes);
    orphans = const [];
    return freed;
  }
}

class _FakeSpeechInstaller implements SpeechModelInstaller {
  bool installed = false;

  @override
  Future<bool> isInstalled(SpeechModelSpec spec) async => installed;

  @override
  Future<void> install(
    SpeechModelSpec spec, {
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    installed = true;
  }

  @override
  Future<void> uninstall(SpeechModelSpec spec) async {
    installed = false;
  }
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required EmbedderDownloadManager embedder,
  required ModelStorageCleaner cleaner,
  SpeechModelInstaller? speech,
}) async {
  SharedPreferences.setMockInitialValues({});
  // Tall enough that the whole AI section is on screen, with no scrolling.
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      huggingFaceTokenProvider.overrideWithValue('hf_test'),
      embedderDownloadManagerProvider.overrideWithValue(embedder),
      modelDownloadManagerProvider.overrideWithValue(_FakeLlm()),
      handwritingRecognitionServiceProvider
          .overrideWithValue(_FakeHandwriting()),
      modelStorageCleanerProvider.overrideWithValue(cleaner),
      speechModelInstallerProvider
          .overrideWithValue(speech ?? _FakeSpeechInstaller()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const SettingsScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('EmbeddingGemma reads as downloaded once its download finishes',
      (tester) async {
    final embedder = _FakeEmbedder(installed: false);
    await _pumpSettings(tester,
        embedder: embedder, cleaner: _FakeCleaner(const []));

    await tester.tap(find.widgetWithText(TextButton, 'Download'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(embedder.installed, isTrue);
    expect(find.textContaining('· Downloaded'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Download'), findsNothing);
  });

  testWidgets('deleting EmbeddingGemma reads as not downloaded, offering Download',
      (tester) async {
    final embedder = _FakeEmbedder(installed: true);
    await _pumpSettings(tester,
        embedder: embedder, cleaner: _FakeCleaner(const []));

    await tester.tap(find.byTooltip('Delete model'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(embedder.installed, isFalse);
    expect(find.widgetWithText(TextButton, 'Download'), findsOneWidget);
  });

  testWidgets('Whisper reads as downloaded on the screen once its download finishes',
      (tester) async {
    final speech = _FakeSpeechInstaller();
    await _pumpSettings(tester,
        embedder: _FakeEmbedder(installed: true),
        cleaner: _FakeCleaner(const []),
        speech: speech);
    expect(find.textContaining('~80 MB · Downloaded'), findsNothing);

    // The switch starts the download through the same provider.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    await container.read(speechModelProvider.notifier).download();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(speech.installed, isTrue);
    expect(find.textContaining('~80 MB · Downloaded'), findsOneWidget);
  });

  testWidgets('freeing leftover files clears the row, without an error',
      (tester) async {
    final cleaner = _FakeCleaner([
      const OrphanedModelFile(
          filename: 'partial.tflite', sizeBytes: 5 * 1024 * 1024),
    ]);
    await _pumpSettings(tester,
        embedder: _FakeEmbedder(installed: true), cleaner: cleaner);
    expect(find.text('Leftover download files'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Free up'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(cleaner.cleaned, isTrue);
    expect(find.text('Leftover download files'), findsNothing);
  });
}
