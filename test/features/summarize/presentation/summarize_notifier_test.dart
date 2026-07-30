import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/summarize/data/cache/summary_cache.dart';
import 'package:inkflow/features/summarize/data/cache/summary_store.dart';
import 'package:inkflow/features/ai/data/llm/cloud_llm_client.dart';
import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/ai_router.dart';
import 'package:inkflow/features/ai/domain/meaningfulness_gate.dart';
import 'package:inkflow/features/ai/domain/page_content_extractor.dart';
import 'package:inkflow/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:inkflow/features/summarize/domain/services/summarization_service.dart';
import 'package:inkflow/features/summarize/presentation/summarize_notifier.dart';

// ---- Fakes ------------------------------------------------------------------

class SilentRecognition extends HandwritingRecognitionService {
  @override
  Future<void> ensureModelDownloaded(String languageCode) async {}
}

class InMemoryStore implements SummaryStore {
  final Map<int, SummaryCache> entries = {};
  @override
  Future<SummaryCache?> find(int notebookId) async => entries[notebookId];
  @override
  Future<void> save(SummaryCache entry) async =>
      entries[entry.notebookId] = entry;
}

class NoopAiProvider implements AiProvider {
  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'noop',
        displayName: 'noop',
        contextWindowTokens: 4096,
        isLocal: true,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<double>> embed(String text) => throw UnimplementedError();
}

/// SummarizationService whose summarize() is fully scripted per call.
class ScriptedService extends SummarizationService {
  final List<
      Future<SummarizationResult> Function(
          void Function(SummarizeStage)? onStage)> script;
  int calls = 0;

  ScriptedService(this.script)
      : super(
          extractor: PageContentExtractor(
            loadElements: (_) async => const [],
            recognition: SilentRecognition(),
          ),
          router: AiRouter(
            localCapabilities: NoopAiProvider().capabilities,
            isLocalModelInstalled: () async => true,
          ),
          local: NoopAiProvider(),
          cloud: StubCloudLlmClient(),
          store: InMemoryStore(),
        );

  @override
  Future<SummarizationResult> summarizeScope({
    required int notebookId,
    required SummarizeScope scope,
    required String languageCode,
    required bool cloudEnabled,
    void Function(SummarizeStage stage)? onStage,
  }) {
    return script[calls++](onStage);
  }
}

class FakeInstaller implements ModelInstaller {
  bool installed = false;
  bool cancelMidway = false;

  @override
  Future<bool> isInstalled(String modelId) async => installed;

  @override
  Future<void> install({
    required LlmModelSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    for (final p in [25, 75, 100]) {
      await Future<void>.delayed(Duration.zero);
      if (cancelToken?.isCancelled ?? false) throw Exception('interrupted');
      onProgress?.call(p);
    }
    installed = true;
  }

  @override
  Future<void> uninstall(String modelId) async => installed = false;
}

class FakeStorage implements DeviceStorage {
  @override
  Future<int> freeBytes() async => 1 << 62;
}

// ---- Tests ------------------------------------------------------------------

void main() {
  const request = SummarizeRequest(
    notebookId: 1,
    resolveScope: _notebookScope,
    languageCode: 'en',
    cloudEnabled: false,
  );

  const okResult = SummarizationResult(
    summary: 'done',
    recognizedText: 'the text',
    modelUsed: 'gemma4-e2b-local',
  );

  SummarizeNotifier notifier(ScriptedService service,
      {ModelDownloadManager? downloads}) {
    return SummarizeNotifier(
      service: service,
      downloads: downloads ??
          ModelDownloadManager(
              installer: FakeInstaller(), storage: FakeStorage()),
      recognition: SilentRecognition(),
    );
  }

  test('success flow walks recognizing → summarizing → success', () async {
    final service = ScriptedService([
      (onStage) async {
        onStage?.call(SummarizeStage.recognizing);
        onStage?.call(SummarizeStage.summarizing);
        return okResult;
      },
    ]);
    final n = notifier(service);
    final states = <SummarizeState>[];
    n.addListener(states.add, fireImmediately: false);

    await n.run(request);

    expect(states.first, isA<SummarizeRecognizing>());
    expect(states.any((s) => s is SummarizeSummarizing), isTrue);
    final success = states.last as SummarizeSuccess;
    expect(success.summary, 'done');
    expect(success.recognizedText, 'the text');
  });

  test('gate failure lands in a non-retryable error', () async {
    final service = ScriptedService([
      (_) async => throw NotMeaningfulException(GateFailure.lowAlphaRatio),
    ]);
    final n = notifier(service);

    await n.run(request);

    final error = n.state as SummarizeError;
    expect(error.retryable, isFalse);
    expect(error.offerModelDownload, isFalse);
    expect(error.message, contains("Couldn't read"));
  });

  test('missing model online offers download; downloadModelAndRetry succeeds',
      () async {
    final service = ScriptedService([
      (_) async => throw LocalModelRequiredException(offline: false),
      (_) async => okResult, // after the download, the retry succeeds
    ]);
    final n = notifier(service);
    final states = <SummarizeState>[];
    n.addListener(states.add, fireImmediately: false);

    await n.run(request);
    expect((n.state as SummarizeError).offerModelDownload, isTrue);

    await n.downloadModelAndRetry();

    expect(states.whereType<SummarizeDownloadingModel>(), isNotEmpty,
        reason: 'progress states must surface during the download');
    expect(n.state, isA<SummarizeSuccess>());
    expect(service.calls, 2);
  });

  test('offline + missing model is an error WITHOUT a download offer',
      () async {
    final service = ScriptedService([
      (_) async => throw LocalModelRequiredException(offline: true),
    ]);
    final n = notifier(service);

    await n.run(request);

    final error = n.state as SummarizeError;
    expect(error.offerModelDownload, isFalse);
    expect(error.message, contains('offline'));
  });

  test('retry re-runs the stored request', () async {
    final service = ScriptedService([
      (_) async => throw RecognitionException('transient failure'),
      (_) async => okResult,
    ]);
    final n = notifier(service);

    await n.run(request);
    expect(n.state, isA<SummarizeError>());

    await n.retry();
    expect(n.state, isA<SummarizeSuccess>());
  });
}

Future<SummarizeScope> _notebookScope() async => const NotebookScope([]);
