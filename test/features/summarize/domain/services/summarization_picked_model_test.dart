// Summarize when the student has picked a cloud model to answer with.
//
// Summarize had no cloud path that could ask first, which is why its cloud
// route was left as a stub. This is that path: the picked model summarizes,
// after one question, and only when there is really something to send.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:margo/features/ai/data/llm/cloud_llm_client.dart';
import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/ai_router.dart';
import 'package:margo/features/ai/domain/page_content_extractor.dart';
import 'package:margo/features/ai/domain/quality/ai_quality_guard.dart';
import 'package:margo/features/summarize/data/cache/summary_cache.dart';
import 'package:margo/features/summarize/data/cache/summary_store.dart';
import 'package:margo/features/ai/data/llm/model_download_manager.dart';
import 'package:margo/features/summarize/domain/services/summarization_service.dart';
import 'package:margo/features/summarize/presentation/summarize_notifier.dart';

class _Online extends Reachability {
  const _Online();
  @override
  Future<bool> isOnline() async => true;
}

/// Skips the handwriting-model download check, which needs the real plugin.
class _ReadyRecognition extends HandwritingRecognitionService {
  @override
  Future<void> ensureModelDownloaded(String languageCode) async {}
}

class _Store implements SummaryStore {
  final entries = <int, SummaryCache>{};
  @override
  Future<SummaryCache?> find(int notebookId) async => entries[notebookId];
  @override
  Future<void> save(SummaryCache entry) async =>
      entries[entry.notebookId] = entry;
}

class _FakeProvider implements AiProvider {
  final String name;
  final bool isLocal;
  AiException? fails;
  final prompts = <String>[];
  _FakeProvider(this.name, {this.isLocal = false});

  @override
  AiCapabilities get capabilities => AiCapabilities(
        modelId: name,
        displayName: name,
        contextWindowTokens: 4096,
        isLocal: isLocal,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    final error = fails;
    if (error != null) throw error;
    prompts.add(prompt);
    yield 'a summary from $name';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('google_mlkit_digital_ink_recognizer');
  String recognizedText = '';

  const inkPage = [
    FreehandElement(id: 's', zOrder: 0, color: 0xFF000000, size: 4, points: [
      StrokePoint(x: 0, y: 0),
      StrokePoint(x: 10, y: 0),
    ]),
  ];
  const meaningful = 'the meeting covered budget planning and the new hiring '
      'timeline for the design team';

  late _FakeProvider local;
  late _FakeProvider picked;
  late _Store store;
  late int asked;
  late bool allow;
  AiProvider? direct;

  SummarizationService build({bool modelInstalled = true}) =>
      SummarizationService(
        extractor: PageContentExtractor(
          loadElements: (_) async => inkPage,
          recognition: HandwritingRecognitionService(),
        ),
        router: AiRouter(
          localCapabilities: local.capabilities,
          reachability: const _Online(),
          isLocalModelInstalled: () async => modelInstalled,
        ),
        local: local,
        cloud: StubCloudLlmClient(),
        store: store,
        directCloud: () => direct,
      );

  Future<SummarizationResult> summarize(SummarizationService service) =>
      service.summarize(
        notebookId: 7,
        pageIds: const [11],
        languageCode: 'en',
        cloudEnabled: true,
        confirmSend: () async {
          asked++;
          return allow;
        },
      );

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
    recognizedText = meaningful;
    local = _FakeProvider('local', isLocal: true);
    picked = _FakeProvider('My AI · Big');
    store = _Store();
    asked = 0;
    allow = true;
    direct = picked;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('the picked model writes the summary and is named on it', () async {
    final result = await summarize(build());

    expect(result.summary, 'a summary from My AI · Big');
    expect(result.modelUsed, 'My AI · Big');
    expect(result.tier, AnswerTier.cloud);
    expect(local.prompts, isEmpty);
  });

  test('it works on a device that never downloaded the on-device model',
      () async {
    final result = await summarize(build(modelInstalled: false));

    expect(result.summary, 'a summary from My AI · Big');
  });

  test('the student is asked once for a note read in several sections',
      () async {
    recognizedText = List.filled(6000, 'word').join(' ');

    final result = await summarize(build());

    expect(result.chunked, isTrue);
    expect(picked.prompts.length, greaterThan(2));
    expect(asked, 1);
  });

  test('a no sends nothing and is not reported as a failure to summarize',
      () async {
    allow = false;

    await expectLater(
      summarize(build()),
      throwsA(isA<SummarizeCancelledException>()),
    );
    expect(picked.prompts, isEmpty);
    expect(local.prompts, isEmpty);
    expect(store.entries, isEmpty);
  });

  test('a summary already made for this exact text is shown without asking',
      () async {
    final service = build();
    await summarize(service);
    expect(asked, 1);

    final again = await summarize(service);

    expect(again.fromCache, isTrue);
    expect(asked, 1);
    expect(picked.prompts, hasLength(1));
  });

  test('a page with nothing readable on it is not asked about', () async {
    recognizedText = '';

    await expectLater(
      summarize(build()),
      throwsA(isA<NotMeaningfulException>()),
    );
    expect(asked, 0);
  });

  test('a picked model that fails is reported, with no on-device summary in '
      'its place', () async {
    picked.fails =
        const AiUnavailableException("Couldn't reach api.example.com.");

    await expectLater(
      summarize(build()),
      throwsA(
        isA<SummarizeException>().having(
          (e) => e.message,
          'message',
          contains('api.example.com'),
        ),
      ),
    );
    expect(local.prompts, isEmpty);
  });

  test('the summary sheet is told plainly that nothing was sent', () async {
    allow = false;
    final notifier = SummarizeNotifier(
      service: build(),
      downloads: ModelDownloadManager(),
      recognition: _ReadyRecognition(),
      confirmSend: () async {
        asked++;
        return allow;
      },
    );

    await notifier.run(SummarizeRequest(
      notebookId: 7,
      resolveScope: () async => const PageScope(11),
      languageCode: 'en',
      cloudEnabled: true,
    ));

    expect(asked, 1);
    expect(
      (notifier.state as SummarizeError).message,
      contains('Nothing was sent'),
    );
    expect(picked.prompts, isEmpty);
    expect(local.prompts, isEmpty);
  });

  test('with nothing picked the on-device model summarizes, unasked',
      () async {
    direct = null;

    final result = await summarize(build());

    expect(result.summary, 'a summary from local');
    expect(result.tier, AnswerTier.local);
    expect(asked, 0);
    expect(picked.prompts, isEmpty);
  });
}
