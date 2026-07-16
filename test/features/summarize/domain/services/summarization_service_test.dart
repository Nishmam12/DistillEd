import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:inkflow/features/ai/data/llm/cloud_llm_client.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/ai_router.dart';
import 'package:inkflow/features/ai/domain/page_content_extractor.dart';
import 'package:inkflow/features/summarize/data/cache/summary_cache.dart';
import 'package:inkflow/features/summarize/data/cache/summary_store.dart';
import 'package:inkflow/features/summarize/domain/services/summarization_service.dart';

// ---- Fakes ------------------------------------------------------------------

class FakeReachability extends Reachability {
  final bool online;
  const FakeReachability(this.online);
  @override
  Future<bool> isOnline() async => online;
}

class InMemorySummaryStore implements SummaryStore {
  final Map<int, SummaryCache> entries = {};
  @override
  Future<SummaryCache?> find(int notebookId) async => entries[notebookId];
  @override
  Future<void> save(SummaryCache entry) async =>
      entries[entry.notebookId] = entry;
}

/// Platform provider that answers with a fixed summary and records the calls.
class FakeAiProvider implements AiProvider {
  int calls = 0;
  String reply = 'a faithful local summary';
  final List<String> prompts = [];
  final List<String?> systemPrompts = [];
  String? lastPrompt;
  String? lastSystemPrompt;
  AiGenerationOptions? lastOptions;
  AiException? throwOnGenerate;

  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'fake-local',
        displayName: 'Fake local',
        contextWindowTokens: 4096,
        isLocal: true,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    final error = throwOnGenerate;
    if (error != null) throw error;
    calls++;
    prompts.add(prompt);
    systemPrompts.add(systemPrompt);
    lastPrompt = prompt;
    lastSystemPrompt = systemPrompt;
    lastOptions = options;
    yield reply;
  }

  @override
  Future<List<double>> embed(String text) async =>
      throw const AiUnsupportedOperationException('not needed here');
}

class RecordingCloudClient implements CloudLlmClient {
  int calls = 0;
  List<ChatMessage>? lastMessages;
  @override
  Future<String> chatCompletion({
    required List<ChatMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
  }) async {
    calls++;
    lastMessages = messages;
    return 'a cloud summary';
  }
}

// ---- Test scaffolding ---------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('google_mlkit_digital_ink_recognizer');

  /// The text the mocked recognizer returns for the next page.
  String recognizedText = '';

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'vision#startDigitalInkRecognizer') {
        return [
          {'text': recognizedText, 'score': 1.0},
        ];
      }
      return 'success';
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// One page of real ink (elements come from the extractor's loader).
  const inkPage = [
    FreehandElement(id: 's', zOrder: 0, color: 0xFF000000, size: 4, points: [
      StrokePoint(x: 0, y: 0),
      StrokePoint(x: 10, y: 0),
    ]),
  ];

  const meaningful =
      'the meeting covered budget planning and the new hiring timeline for the design team';

  ({
    SummarizationService service,
    AiRouter router,
    FakeAiProvider local,
    RecordingCloudClient cloud,
    InMemorySummaryStore store,
  }) build({
    bool online = true,
    bool modelInstalled = true,
    CloudLlmClient? cloudOverride,
    List<SceneElement> page = inkPage,
  }) {
    final local = FakeAiProvider();
    final cloud = RecordingCloudClient();
    final store = InMemorySummaryStore();
    final router = AiRouter(
      localCapabilities: local.capabilities,
      reachability: FakeReachability(online),
      isLocalModelInstalled: () async => modelInstalled,
    );
    final service = SummarizationService(
      extractor: PageContentExtractor(
        loadElements: (_) async => page,
        recognition: HandwritingRecognitionService(),
      ),
      router: router,
      local: local,
      cloud: cloudOverride ?? cloud,
      store: store,
    );
    return (
      service: service,
      router: router,
      local: local,
      cloud: cloud,
      store: store,
    );
  }

  group('SummarizationService', () {
    test('local path: extract → gate → local provider → cache save', () async {
      recognizedText = meaningful;
      final env = build();
      final stages = <SummarizeStage>[];

      final result = await env.service.summarize(
        notebookId: 7,
        pageIds: const [11],
        languageCode: 'en',
        cloudEnabled: false,
        onStage: stages.add,
      );

      expect(result.summary, 'a faithful local summary');
      expect(result.fromCache, isFalse);
      expect(result.recognizedText, meaningful);
      expect(result.modelUsed, 'gemma4-e2b-local');
      expect(stages, [SummarizeStage.recognizing, SummarizeStage.summarizing]);
      expect(env.local.lastPrompt, contains(meaningful));
      expect(env.local.lastSystemPrompt, contains('3 to 6 sentences'));
      expect(env.local.lastOptions?.temperature, 0.2);
      expect(env.local.lastOptions?.maxTokens, 512);

      final saved = env.store.entries[7]!;
      expect(saved.textHash, hashRecognizedText(meaningful));
      expect(saved.summary, 'a faithful local summary');
    });

    test('typed text on the page contributes to the summarized text',
        () async {
      recognizedText = meaningful;
      final env = build(page: [
        ...inkPage,
        const TextElement(
          id: 't',
          zOrder: 1,
          geometryData: [0, 100, 200, 120],
          text: 'typed action items below the ink',
          color: 0xFF000000,
        ),
      ]);

      final result = await env.service.summarize(
        notebookId: 9,
        pageIds: const [11],
        languageCode: 'en',
        cloudEnabled: false,
      );

      expect(result.recognizedText, contains(meaningful));
      expect(result.recognizedText, contains('typed action items'));
      expect(env.local.lastPrompt, contains('typed action items'));
    });

    test('unchanged note → instant cached summary, no LLM call', () async {
      recognizedText = meaningful;
      final env = build();

      await env.service.summarize(
          notebookId: 7,
          pageIds: const [11],
          languageCode: 'en',
          cloudEnabled: false);
      expect(env.local.calls, 1);

      final second = await env.service.summarize(
          notebookId: 7,
          pageIds: const [11],
          languageCode: 'en',
          cloudEnabled: false);

      expect(second.fromCache, isTrue);
      expect(second.summary, 'a faithful local summary');
      expect(env.local.calls, 1, reason: 'cache hit must skip the model');
    });

    test('changed note recomputes and overwrites the cache entry', () async {
      recognizedText = meaningful;
      final env = build();
      await env.service.summarize(
          notebookId: 7,
          pageIds: const [11],
          languageCode: 'en',
          cloudEnabled: false);

      recognizedText = '$meaningful with several brand new action items added';
      final result = await env.service.summarize(
          notebookId: 7,
          pageIds: const [11],
          languageCode: 'en',
          cloudEnabled: false);

      expect(result.fromCache, isFalse);
      expect(env.local.calls, 2);
      expect(
          env.store.entries[7]!.textHash, hashRecognizedText(recognizedText));
    });

    test('gate failure throws NotMeaningfulException before any LLM',
        () async {
      recognizedText = '7 42 --';
      final env = build();

      await expectLater(
        env.service.summarize(
            notebookId: 7,
            pageIds: const [11],
            languageCode: 'en',
            cloudEnabled: true),
        throwsA(isA<NotMeaningfulException>()),
      );
      expect(env.local.calls, 0);
      expect(env.cloud.calls, 0);
      expect(env.store.entries, isEmpty);
    });

    test('long note + cloud enabled routes to the cloud client', () async {
      final env = build();
      recognizedText =
          List.filled(env.router.localInputWordBudget + 50, 'word').join(' ');

      final result = await env.service.summarize(
          notebookId: 3,
          pageIds: const [11],
          languageCode: 'en',
          cloudEnabled: true);

      expect(result.summary, 'a cloud summary');
      expect(result.modelUsed, 'cloud');
      expect(env.cloud.calls, 1);
      expect(env.local.calls, 0);
      expect(env.cloud.lastMessages!.first.role, 'system');
      expect(env.cloud.lastMessages!.last.content, contains('word word'));
    });

    test('cloud stub failure chunk-and-reduces the long input locally',
        () async {
      final env = build(cloudOverride: StubCloudLlmClient());
      final budget = env.router.localInputWordBudget;
      recognizedText = List.filled(budget + 50, 'word').join(' ');

      final result = await env.service.summarize(
          notebookId: 3,
          pageIds: const [11],
          languageCode: 'en',
          cloudEnabled: true);

      expect(result.cloudFellBack, isTrue);
      expect(result.chunked, isTrue);
      expect(result.summary, 'a faithful local summary');
      expect(result.modelUsed, 'gemma4-e2b-local');
      // Every section prompt fit the budget — nothing was cut away, and the
      // whole note was read across 2 sections + 1 reduce pass.
      for (final prompt in env.local.prompts) {
        expect(RegExp(r'\bword\b').allMatches(prompt).length,
            lessThanOrEqualTo(budget));
      }
      expect(env.local.calls, 3);
    });

    test('over-budget local route chunk-and-reduces instead of truncating',
        () async {
      final env = build();
      final budget = env.router.localInputWordBudget;
      recognizedText = List.filled(budget + 30, 'word').join(' ');

      // Cloud off + over budget → routes local; must chunk, not truncate.
      final result = await env.service.summarize(
          notebookId: 8,
          pageIds: const [11],
          languageCode: 'en',
          cloudEnabled: false);

      expect(result.chunked, isTrue);
      expect(result.cloudFellBack, isFalse);
      expect(result.summary, 'a faithful local summary');
      expect(env.local.calls, greaterThan(1));
      for (final prompt in env.local.prompts) {
        expect(RegExp(r'\bword\b').allMatches(prompt).length,
            lessThanOrEqualTo(budget));
      }
    });

    test('page scope summarizes one page and never writes the cache', () async {
      recognizedText = meaningful;
      final env = build();

      final result = await env.service.summarizeScope(
        notebookId: 5,
        scope: const PageScope(11),
        languageCode: 'en',
        cloudEnabled: false,
      );

      expect(result.summary, 'a faithful local summary');
      expect(result.recognizedText, meaningful);
      expect(env.store.entries, isEmpty,
          reason: 'only notebook scope is cached');
    });

    test('selection scope reads only the selected elements', () async {
      recognizedText = meaningful;
      final env = build(page: [
        ...inkPage, // id 's'
        const TextElement(
          id: 't',
          zOrder: 1,
          geometryData: [0, 100, 200, 120],
          text: 'unrelated typed note that should be excluded',
          color: 0xFF000000,
        ),
      ]);

      final result = await env.service.summarizeScope(
        notebookId: 5,
        scope: const SelectionScope(pageId: 11, elementIds: {'s'}),
        languageCode: 'en',
        cloudEnabled: false,
      );

      expect(result.recognizedText, meaningful);
      expect(result.recognizedText, isNot(contains('unrelated typed note')));
      expect(env.store.entries, isEmpty);
    });

    test('empty selection fails the gate before any model call', () async {
      recognizedText = meaningful;
      final env = build();

      await expectLater(
        env.service.summarizeScope(
          notebookId: 5,
          scope: const SelectionScope(pageId: 11, elementIds: {}),
          languageCode: 'en',
          cloudEnabled: false,
        ),
        throwsA(isA<NotMeaningfulException>()),
      );
      expect(env.local.calls, 0);
    });

    test('offline without the model → LocalModelRequiredException(offline)',
        () async {
      recognizedText = meaningful;
      final env = build(online: false, modelInstalled: false);

      await expectLater(
        env.service.summarize(
            notebookId: 1,
            pageIds: const [11],
            languageCode: 'en',
            cloudEnabled: false),
        throwsA(isA<LocalModelRequiredException>()
            .having((e) => e.offline, 'offline', isTrue)),
      );
    });

    test('online without the model → download-then-local signal', () async {
      recognizedText = meaningful;
      final env = build(online: true, modelInstalled: false);

      await expectLater(
        env.service.summarize(
            notebookId: 1,
            pageIds: const [11],
            languageCode: 'en',
            cloudEnabled: false),
        throwsA(isA<LocalModelRequiredException>()
            .having((e) => e.offline, 'offline', isFalse)),
      );
    });

    test(
        'model deleted between routing and generation surfaces the '
        'download-offer state', () async {
      recognizedText = meaningful;
      final env = build();
      env.local.throwOnGenerate =
          const AiModelNotReadyException('model vanished');

      await expectLater(
        env.service.summarize(
            notebookId: 1,
            pageIds: const [11],
            languageCode: 'en',
            cloudEnabled: false),
        throwsA(isA<LocalModelRequiredException>()
            .having((e) => e.offline, 'offline', isFalse)),
      );
    });
  });

  group('word helpers', () {
    test('countWords', () {
      expect(SummarizationService.countWords(''), 0);
      expect(SummarizationService.countWords('  '), 0);
      expect(SummarizationService.countWords('one two\nthree'), 3);
    });

    test('truncateToWords keeps text under the budget intact', () {
      expect(SummarizationService.truncateToWords('a b c', 5), 'a b c');
      expect(SummarizationService.truncateToWords('a b c d e f', 3), 'a b c');
    });
  });
}
