import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/context_engine/context_engine.dart';
import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';
import 'package:inkflow/features/ai/domain/page_content.dart';
import 'package:inkflow/features/ai/domain/page_content_extractor.dart';
import 'package:inkflow/features/ai/presentation/context_engine_notifier.dart';

// ---- Fakes ------------------------------------------------------------------

class RecordingRecognition extends HandwritingRecognitionService {
  int ensureCalls = 0;
  @override
  Future<void> ensureModelDownloaded(String languageCode) async {
    ensureCalls++;
  }
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

class FakeExtractor extends PageContentExtractor {
  int calls = 0;

  /// The `useVision` argument of each [extractPage] call, in order — lets a test
  /// assert the deep-read (Gemma) vs light (ML Kit) trigger policy.
  final visionFlags = <bool>[];

  /// The `varyVision` argument of each call — asserts the Re-read (sampled)
  /// vs first-read (deterministic) policy.
  final varyFlags = <bool>[];

  FakeExtractor()
      : super(
          loadElements: (_) async => const [],
          recognition: RecordingRecognition(),
        );

  @override
  Future<PageContent> extractPage(int pageId,
      {required String languageCode,
      bool useVision = false,
      bool varyVision = false}) async {
    calls++;
    visionFlags.add(useVision);
    varyFlags.add(varyVision);
    return const PageContent(
        recognizedInkText: 'recognized note text', typedText: '');
  }
}

class FakeEngine extends ContextEngine {
  int calls = 0;
  PageContext? lastPrevious;
  PageContext result;
  Object? throwOnAnalyze;

  FakeEngine({this.result = const PageContext(currentTopic: 'Topic A')})
      : super(provider: NoopAiProvider());

  @override
  Future<PageContext> analyze(PageContent content,
      {PageContext? previousContext}) async {
    calls++;
    lastPrevious = previousContext;
    final error = throwOnAnalyze;
    if (error != null) throw error;
    return result;
  }
}

// ---- Test scaffolding ---------------------------------------------------------

const ink = [
  FreehandElement(id: 's1', zOrder: 0, color: 0xFF000000, size: 4, points: [
    StrokePoint(x: 0, y: 0),
    StrokePoint(x: 10, y: 0),
  ]),
];

const moreInk = [
  ...ink,
  FreehandElement(id: 's2', zOrder: 1, color: 0xFF000000, size: 4, points: [
    StrokePoint(x: 0, y: 20),
    StrokePoint(x: 10, y: 20),
  ]),
];

/// Lets the short test debounce (5 ms) fire and the analysis settle.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  late FakeEngine engine;
  late FakeExtractor extractor;
  late RecordingRecognition recognition;
  late PageContextCache cache;

  setUp(() {
    engine = FakeEngine();
    extractor = FakeExtractor();
    recognition = RecordingRecognition();
    cache = PageContextCache();
  });

  ContextEngineNotifier notifier({int pageId = 1}) => ContextEngineNotifier(
        engine: engine,
        extractor: extractor,
        recognition: recognition,
        cache: cache,
        pageId: pageId,
        languageCode: () => 'en',
        debounce: const Duration(milliseconds: 5),
      );

  test('debounce coalesces rapid changes into one analysis', () async {
    final n = notifier();
    n.onSceneChanged(ink);
    n.onSceneChanged(ink);
    n.onSceneChanged(moreInk);
    await settle();

    expect(engine.calls, 1);
    expect(n.state.value?.currentTopic, 'Topic A');
    expect(recognition.ensureCalls, 1);
    n.dispose();
  });

  test('unchanged content is not re-analyzed', () async {
    final n = notifier();
    n.onSceneChanged(ink);
    await settle();
    n.onSceneChanged(List.of(ink)); // same content, different list instance
    await settle();

    expect(engine.calls, 1);
    n.dispose();
  });

  test('changed content re-analyzes; previous context is passed along',
      () async {
    final n = notifier();
    n.onSceneChanged(ink);
    await settle();
    n.onSceneChanged(moreInk);
    await settle();

    expect(engine.calls, 2);
    expect(engine.lastPrevious?.currentTopic, 'Topic A',
        reason: 'the cached context feeds the next run as a continuity hint');
    n.dispose();
  });

  test('a page cached earlier is served without engine or recognition calls',
      () async {
    cache.save(1, sceneContentSignature(ink),
        const PageContext(currentTopic: 'Cached topic'));

    final n = notifier();
    expect(n.state.value?.currentTopic, 'Cached topic',
        reason: 'cache seeds the initial state before any trigger');

    n.onSceneChanged(ink);
    await settle();

    expect(engine.calls, 0);
    expect(recognition.ensureCalls, 0);
    expect(n.state.value?.currentTopic, 'Cached topic');
    n.dispose();
  });

  test('a page with no readable content short-circuits to empty', () async {
    final n = notifier();
    n.onSceneChanged(const []);
    await settle();

    expect(n.state.value, PageContext.empty);
    expect(engine.calls, 0);
    expect(recognition.ensureCalls, 0,
        reason: 'no recognition-model download for pages with nothing to read');
    n.dispose();
  });

  test('an image-only page IS analyzed (its text is OCR-read downstream)',
      () async {
    // Regression: imported PDF pages and photos held only ImageElements, which
    // this gate did not count as readable — so the insights panel stayed blank
    // on imported pages even though the extractor OCRs them. The gate must let
    // the extractor run so that OCR can happen.
    const imageOnly = [
      ImageElement(
        id: 'img',
        zOrder: 0,
        geometryData: [0, 0, 100, 100],
        relativeImagePath: 'imports/page1.png',
      ),
    ];

    final n = notifier();
    n.onSceneChanged(imageOnly);
    await settle();

    expect(engine.calls, 1, reason: 'the image page must reach analysis');
    expect(n.state.value?.currentTopic, 'Topic A');
    n.dispose();
  });

  test('an image with no file behind it is not treated as readable', () async {
    const pathless = [
      ImageElement(id: 'x', zOrder: 0, geometryData: [0, 0, 1, 1],
          relativeImagePath: ''),
    ];

    final n = notifier();
    n.onSceneChanged(pathless);
    await settle();

    expect(engine.calls, 0);
    expect(n.state.value, PageContext.empty);
    n.dispose();
  });

  test('failure surfaces as error and is not retried for the same content',
      () async {
    engine.throwOnAnalyze = const AiModelNotReadyException('not downloaded');

    final n = notifier();
    n.onSceneChanged(ink);
    await settle();

    expect(n.state.hasError, isTrue);
    expect(n.state.error, isA<AiModelNotReadyException>());
    expect(engine.calls, 1);

    n.onSceneChanged(List.of(ink)); // same content again
    await settle();
    expect(engine.calls, 1, reason: 'a missing model must not be hammered');
    n.dispose();
  });

  test('refresh() forces a re-run even for unchanged content', () async {
    final n = notifier();
    n.onSceneChanged(ink);
    await settle();
    expect(engine.calls, 1);

    engine.result = const PageContext(currentTopic: 'Topic B');
    await n.refresh();
    await settle();

    expect(engine.calls, 2);
    expect(n.state.value?.currentTopic, 'Topic B');
    n.dispose();
  });

  test('Gemma vision reads on first open and on Re-read; edits stay light',
      () async {
    final n = notifier();

    n.onSceneChanged(ink);
    await settle();
    expect(extractor.visionFlags, [true],
        reason: 'the first read when the sidebar opens is the deep Gemma pass');

    n.onSceneChanged(moreInk); // an edit
    await settle();
    expect(extractor.visionFlags, [true, false],
        reason: 'intermediate edits use the light ML Kit path — no 2.4 GB '
            'model load on every writing pause');

    await n.refresh(); // Re-read
    await settle();
    expect(extractor.visionFlags, [true, false, true],
        reason: 'Re-read forces another deep Gemma pass');
    // The first deep read is deterministic; the Re-read samples a fresh reading
    // so it can actually change (the "re-read does nothing" fix).
    expect(extractor.varyFlags, [false, false, true],
        reason: 'only the Re-read of an already-read page varies its sampling');
    n.dispose();
  });

  group('onContent (Writing Assistant hook)', () {
    ContextEngineNotifier withHook(void Function(PageContent) onContent) =>
        ContextEngineNotifier(
          engine: engine,
          extractor: extractor,
          recognition: recognition,
          cache: cache,
          pageId: 1,
          languageCode: () => 'en',
          onContent: onContent,
          debounce: const Duration(milliseconds: 5),
        );

    test('fires with the extracted content after a successful analysis',
        () async {
      final received = <PageContent>[];
      final n = withHook(received.add);
      n.onSceneChanged(ink);
      await settle();

      expect(received, hasLength(1));
      expect(received.single.recognizedInkText, 'recognized note text');
      n.dispose();
    });

    test('fires with empty content when the page has nothing readable',
        () async {
      final received = <PageContent>[];
      final n = withHook(received.add);
      n.onSceneChanged(const []);
      await settle();

      expect(received.single, PageContent.empty);
      n.dispose();
    });

    test('does not fire when analysis fails', () async {
      engine.throwOnAnalyze = const AiModelNotReadyException('no model');
      final received = <PageContent>[];
      final n = withHook(received.add);
      n.onSceneChanged(ink);
      await settle();

      expect(received, isEmpty);
      n.dispose();
    });

    test('a throwing hook never breaks analysis', () async {
      final n = withHook((_) => throw StateError('boom'));
      n.onSceneChanged(ink);
      await settle();

      expect(n.state.value?.currentTopic, 'Topic A');
      n.dispose();
    });
  });

  group('sceneContentSignature', () {
    test('ignores erasers, empty text, and pure moves of ink', () {
      const moved = [
        FreehandElement(
            id: 's1',
            zOrder: 0,
            color: 0xFF000000,
            size: 4,
            points: [StrokePoint(x: 100, y: 100), StrokePoint(x: 110, y: 100)]),
      ];
      expect(sceneContentSignature(ink), sceneContentSignature(moved),
          reason: 'recognition is translation-invariant; moves do not '
              'invalidate');
      expect(sceneContentSignature(ink),
          isNot(sceneContentSignature(moreInk)));
    });

    test('text edits and text moves change the signature', () {
      const a = [
        TextElement(
            id: 't1',
            zOrder: 0,
            geometryData: [0, 0, 100, 20],
            text: 'hello',
            color: 0xFF000000),
      ];
      const edited = [
        TextElement(
            id: 't1',
            zOrder: 0,
            geometryData: [0, 0, 100, 20],
            text: 'hello world',
            color: 0xFF000000),
      ];
      const moved = [
        TextElement(
            id: 't1',
            zOrder: 0,
            geometryData: [0, 500, 100, 520],
            text: 'hello',
            color: 0xFF000000),
      ];
      expect(sceneContentSignature(a), isNot(sceneContentSignature(edited)));
      expect(sceneContentSignature(a), isNot(sceneContentSignature(moved)),
          reason: 'text position feeds reading order');
    });
  });
}
