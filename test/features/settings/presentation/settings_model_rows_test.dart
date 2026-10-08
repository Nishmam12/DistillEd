// The Settings rows for a model refresh themselves after a download, a delete or
// a clean-up. Each refresh once ran a Future-returning call inside setState,
// which Flutter refuses, so the row kept its old state and the student saw
// nothing change. Every model that is not installed also offers a Download
// button, so a model that did not fetch on first use can still be fetched by
// hand. These run the real screen against fakes for the managers.

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
  bool installed = false;
  Object? failWith;

  @override
  LlmModelSpec get spec => LlmModelSpec.active;

  @override
  Stream<int> get progress => const Stream<int>.empty();

  @override
  int? get currentPercent => null;

  @override
  bool get isDownloading => false;

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Future<void> download() async {
    final failure = failWith;
    if (failure != null) throw failure;
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

class _FakeHandwriting implements HandwritingRecognitionService {
  final downloaded = <String>{};

  @override
  Future<bool> isModelDownloaded(String languageCode) async =>
      downloaded.contains(languageCode);

  @override
  Future<void> ensureModelDownloaded(String languageCode) async {
    downloaded.add(languageCode);
  }

  @override
  Future<bool> deleteModel(String languageCode) async =>
      downloaded.remove(languageCode);

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

/// The row titles, as the screen shows them.
final _gemmaTitle = '${LlmModelSpec.active.displayName} (summarization)';
final _embedTitle = '${EmbedderSpec.active.displayName} (search)';
final _whisperTitle = SpeechModelSpec.active.displayName;
const _englishTitle = 'English handwriting model';

/// A row's Download button, found by the row's title.
Finder _downloadButton(String title) => find.byKey(ValueKey('download-$title'));

Future<void> _pumpSettings(
  WidgetTester tester, {
  required EmbedderDownloadManager embedder,
  required ModelStorageCleaner cleaner,
  SpeechModelInstaller? speech,
  ModelDownloadManager? llm,
  HandwritingRecognitionService? handwriting,
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
      modelDownloadManagerProvider.overrideWithValue(llm ?? _FakeLlm()),
      handwritingRecognitionServiceProvider
          .overrideWithValue(handwriting ?? _FakeHandwriting()),
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

    await tester.tap(_downloadButton(_embedTitle));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(embedder.installed, isTrue);
    expect(find.textContaining('· Downloaded'), findsOneWidget);
    expect(_downloadButton(_embedTitle), findsNothing);
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
    expect(_downloadButton(_embedTitle), findsOneWidget);
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

  testWidgets('every model that is not downloaded offers a Download button',
      (tester) async {
    await _pumpSettings(tester,
        embedder: _FakeEmbedder(installed: false),
        cleaner: _FakeCleaner(const []));

    for (final title in [
      _gemmaTitle,
      _embedTitle,
      _englishTitle,
      'Bangla handwriting model',
      'Banglish handwriting model',
      _whisperTitle,
    ]) {
      expect(_downloadButton(title), findsOneWidget, reason: title);
    }
  });

  testWidgets('Gemma downloads from its own button, and reads as downloaded',
      (tester) async {
    final llm = _FakeLlm();
    await _pumpSettings(tester,
        embedder: _FakeEmbedder(installed: true),
        cleaner: _FakeCleaner(const []),
        llm: llm);

    await tester.tap(_downloadButton(_gemmaTitle));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(llm.installed, isTrue);
    expect(find.textContaining('GB · Downloaded'), findsOneWidget);
    expect(_downloadButton(_gemmaTitle), findsNothing);
  });

  testWidgets('Whisper downloads from its own button, and reads as downloaded',
      (tester) async {
    final speech = _FakeSpeechInstaller();
    await _pumpSettings(tester,
        embedder: _FakeEmbedder(installed: true),
        cleaner: _FakeCleaner(const []),
        speech: speech);

    await tester.tap(_downloadButton(_whisperTitle));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(speech.installed, isTrue);
    expect(find.textContaining('~80 MB · Downloaded'), findsOneWidget);
    expect(_downloadButton(_whisperTitle), findsNothing);
  });

  testWidgets('a handwriting model downloads from its own button',
      (tester) async {
    final handwriting = _FakeHandwriting();
    await _pumpSettings(tester,
        embedder: _FakeEmbedder(installed: true),
        cleaner: _FakeCleaner(const []),
        handwriting: handwriting);

    await tester.tap(_downloadButton(_englishTitle));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(handwriting.downloaded, {'en'});
    expect(_downloadButton(_englishTitle), findsNothing);
    expect(find.textContaining('~20 MB · Downloaded'), findsOneWidget);
  });

  testWidgets('a failed download says so, and the button stays for another try',
      (tester) async {
    final llm = _FakeLlm()..failWith = StateError('no network');
    await _pumpSettings(tester,
        embedder: _FakeEmbedder(installed: true),
        cleaner: _FakeCleaner(const []),
        llm: llm);

    await tester.tap(_downloadButton(_gemmaTitle));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(llm.installed, isFalse);
    expect(find.textContaining("Couldn't download $_gemmaTitle"),
        findsOneWidget);
    expect(_downloadButton(_gemmaTitle), findsOneWidget);
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
