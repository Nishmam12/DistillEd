import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/editor/domain/models/stroke.dart';
import 'package:inkflow/features/editor/domain/models/stroke_point.dart';
import 'package:inkflow/features/summarize/data/cache/summary_cache.dart';
import 'package:inkflow/features/summarize/data/cache/summary_store.dart';
import 'package:inkflow/features/summarize/data/llm/cloud_llm_client.dart';
import 'package:inkflow/features/summarize/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/summarize/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/summarize/data/llm/local_llm_service.dart';
import 'package:inkflow/features/summarize/domain/services/ai_router.dart';
import 'package:inkflow/features/summarize/domain/services/handwriting_recognition_service.dart';
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

/// Local runtime whose sessions echo a fixed summary and count invocations.
class FakeLocalRuntime implements LlmRuntime {
  int calls = 0;
  String reply = 'a faithful local summary';
  String? lastPrompt;

  @override
  Future<LlmSession> open({
    required LlmModelSpec spec,
    required double temperature,
    required int topK,
    required double topP,
    int? maxOutputTokens,
  }) async {
    calls++;
    return _EchoSession(this);
  }
}

class _EchoSession implements LlmSession {
  final FakeLocalRuntime runtime;
  _EchoSession(this.runtime);
  @override
  Future<String> respond(String prompt) async {
    runtime.lastPrompt = prompt;
    return runtime.reply;
  }

  @override
  Future<void> close() async {}
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

  /// The text the mocked recognizer returns for the next notebook page.
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

  const page = [
    Stroke(id: 's', color: 0xFF000000, size: 4, points: [
      StrokePoint(x: 0, y: 0),
      StrokePoint(x: 10, y: 0),
    ]),
  ];

  const meaningful =
      'the meeting covered budget planning and the new hiring timeline for the design team';

  ({
    SummarizationService service,
    FakeLocalRuntime runtime,
    RecordingCloudClient cloud,
    InMemorySummaryStore store,
  }) build({bool online = true, bool modelInstalled = true}) {
    final runtime = FakeLocalRuntime();
    final cloud = RecordingCloudClient();
    final store = InMemorySummaryStore();
    final service = SummarizationService(
      recognition: HandwritingRecognitionService(),
      router: AiRouter(
        reachability: FakeReachability(online),
        isLocalModelInstalled: () async => modelInstalled,
      ),
      localLlm: LocalLlmService(runtime: runtime),
      cloud: cloud,
      store: store,
    );
    return (service: service, runtime: runtime, cloud: cloud, store: store);
  }

  group('SummarizationService', () {
    test('local path: recognize → gate → local LLM → cache save', () async {
      recognizedText = meaningful;
      final env = build();
      final stages = <SummarizeStage>[];

      final result = await env.service.summarize(
        notebookId: 7,
        pagesStrokes: const [page],
        languageCode: 'en',
        cloudEnabled: false,
        onStage: stages.add,
      );

      expect(result.summary, 'a faithful local summary');
      expect(result.fromCache, isFalse);
      expect(result.recognizedText, meaningful);
      expect(result.modelUsed, 'gemma4-e2b-local');
      expect(stages,
          [SummarizeStage.recognizing, SummarizeStage.summarizing]);
      expect(env.runtime.lastPrompt, contains(meaningful));
      expect(env.runtime.lastPrompt, contains('3 to 6 sentences'));

      final saved = env.store.entries[7]!;
      expect(saved.textHash, hashRecognizedText(meaningful));
      expect(saved.summary, 'a faithful local summary');
    });

    test('unchanged note → instant cached summary, no LLM call', () async {
      recognizedText = meaningful;
      final env = build();

      await env.service.summarize(
          notebookId: 7,
          pagesStrokes: const [page],
          languageCode: 'en',
          cloudEnabled: false);
      expect(env.runtime.calls, 1);

      final second = await env.service.summarize(
          notebookId: 7,
          pagesStrokes: const [page],
          languageCode: 'en',
          cloudEnabled: false);

      expect(second.fromCache, isTrue);
      expect(second.summary, 'a faithful local summary');
      expect(env.runtime.calls, 1, reason: 'cache hit must skip the model');
    });

    test('changed note recomputes and overwrites the cache entry', () async {
      recognizedText = meaningful;
      final env = build();
      await env.service.summarize(
          notebookId: 7,
          pagesStrokes: const [page],
          languageCode: 'en',
          cloudEnabled: false);

      recognizedText = '$meaningful with several brand new action items added';
      final result = await env.service.summarize(
          notebookId: 7,
          pagesStrokes: const [page],
          languageCode: 'en',
          cloudEnabled: false);

      expect(result.fromCache, isFalse);
      expect(env.runtime.calls, 2);
      expect(env.store.entries[7]!.textHash,
          hashRecognizedText(recognizedText));
    });

    test('gate failure throws NotMeaningfulException before any LLM',
        () async {
      recognizedText = '7 42 --';
      final env = build();

      await expectLater(
        env.service.summarize(
            notebookId: 7,
            pagesStrokes: const [page],
            languageCode: 'en',
            cloudEnabled: true),
        throwsA(isA<NotMeaningfulException>()),
      );
      expect(env.runtime.calls, 0);
      expect(env.cloud.calls, 0);
      expect(env.store.entries, isEmpty);
    });

    test('long note + cloud enabled routes to the cloud client', () async {
      recognizedText =
          List.filled(AiRouter.localInputWordBudget + 50, 'word').join(' ');
      final env = build();

      final result = await env.service.summarize(
          notebookId: 3,
          pagesStrokes: const [page],
          languageCode: 'en',
          cloudEnabled: true);

      expect(result.summary, 'a cloud summary');
      expect(result.modelUsed, 'cloud');
      expect(env.cloud.calls, 1);
      expect(env.runtime.calls, 0);
      expect(env.cloud.lastMessages!.first.role, 'system');
      expect(env.cloud.lastMessages!.last.content, contains('word word'));
    });

    test('cloud stub failure falls back to truncated local generation',
        () async {
      recognizedText =
          List.filled(AiRouter.localInputWordBudget + 50, 'word').join(' ');
      final runtime = FakeLocalRuntime();
      final store = InMemorySummaryStore();
      final service = SummarizationService(
        recognition: HandwritingRecognitionService(),
        router: AiRouter(
          reachability: const FakeReachability(true),
          isLocalModelInstalled: () async => true,
        ),
        localLlm: LocalLlmService(runtime: runtime),
        cloud: StubCloudLlmClient(), // the real no-op stub
        store: store,
      );

      final result = await service.summarize(
          notebookId: 3,
          pagesStrokes: const [page],
          languageCode: 'en',
          cloudEnabled: true);

      expect(result.cloudFellBack, isTrue);
      expect(result.truncated, isTrue);
      expect(result.summary, 'a faithful local summary');
      expect(result.modelUsed, 'gemma4-e2b-local');
      // Prompt was cut to the budget.
      final wordsInPrompt = RegExp(r'\bword\b').allMatches(runtime.lastPrompt!);
      expect(wordsInPrompt.length, AiRouter.localInputWordBudget);
    });

    test('offline without the model → LocalModelRequiredException(offline)',
        () async {
      recognizedText = meaningful;
      final env = build(online: false, modelInstalled: false);

      await expectLater(
        env.service.summarize(
            notebookId: 1,
            pagesStrokes: const [page],
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
            pagesStrokes: const [page],
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
