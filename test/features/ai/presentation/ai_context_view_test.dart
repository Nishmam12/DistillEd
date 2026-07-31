import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/context_engine/context_engine.dart';
import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';
import 'package:inkflow/features/ai/domain/features/writing_assistant.dart';
import 'package:inkflow/features/ai/domain/page_content_extractor.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';
import 'package:inkflow/features/ai/presentation/context_engine_notifier.dart';
import 'package:inkflow/features/ai/presentation/model_download_notifier.dart';
import 'package:inkflow/features/ai/presentation/writing_assistant_notifier.dart';
import 'package:inkflow/features/ai/presentation/sidebar/ai_context_view.dart';

// ---- Fakes ------------------------------------------------------------------

class _NoopProvider implements AiProvider {
  @override
  AiCapabilities get capabilities => const AiCapabilities(
      modelId: 'noop',
      displayName: 'noop',
      contextWindowTokens: 4096,
      isLocal: true);
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

/// A notifier pinned to a fixed state — no timers, no analysis — so the view's
/// rendering of each state can be asserted in isolation.
class _FixedNotifier extends ContextEngineNotifier {
  _FixedNotifier(AsyncValue<PageContext> initial)
      : super(
          engine: ContextEngine(provider: _NoopProvider()),
          extractor: PageContentExtractor(
            loadElements: (_) async => const [],
            recognition: HandwritingRecognitionService(),
          ),
          recognition: HandwritingRecognitionService(),
          cache: PageContextCache(),
          pageId: 1,
          languageCode: () => 'en',
        ) {
    state = initial;
  }
}

/// A no-op installer/storage pair so a real [ModelDownloadManager] can be
/// constructed in a widget test without touching the plugin.
class _NoopInstaller implements ModelInstaller {
  @override
  Future<bool> isInstalled(String modelId) async => false;
  @override
  Future<void> install({
    required LlmModelSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) =>
      Completer<void>().future; // never settles
  @override
  Future<void> uninstall(String modelId) async {}
}

class _NoopStorage implements DeviceStorage {
  @override
  Future<int> freeBytes() async => 1 << 40;
}

/// Download notifier pinned to a fixed state, standing in for a download that
/// was started elsewhere — or before this panel was reopened.
class _FixedDownload extends LlmDownloadNotifier {
  _FixedDownload(LlmDownloadState initial)
      : super(ModelDownloadManager(
          installer: _NoopInstaller(),
          storage: _NoopStorage(),
        )) {
    state = initial;
  }
}

/// Writing notifier pinned to a fixed suggestion list (dismiss still works via
/// the inherited notifier).
class _FixedWriting extends WritingAssistantNotifier {
  _FixedWriting(List<WritingSuggestion> initial)
      : super(
          assistant: WritingAssistant(provider: _NoopProvider()),
          cache: PageWritingCache(),
          pageId: 1,
        ) {
    state = initial;
  }
}

// ---- Tests ------------------------------------------------------------------

void main() {
  const key = (notebookId: 1, pageId: 1);

  Future<void> pump(
    WidgetTester tester,
    AsyncValue<PageContext> state, {
    LlmDownloadState? download,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          pageContextProvider(key).overrideWith((ref) => _FixedNotifier(state)),
          if (download != null)
            llmDownloadProvider.overrideWith((ref) => _FixedDownload(download)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiContextView(pageKey: key)),
        ),
      ),
    );
  }

  testWidgets('rich context renders topic, level, concepts, gaps, definitions',
      (tester) async {
    await pump(
      tester,
      const AsyncValue.data(PageContext(
        currentTopic: 'Photosynthesis',
        subtopics: ['light reactions'],
        keyConcepts: ['chlorophyll', 'ATP'],
        knowledgeGaps: ['NADPH used but never defined'],
        definitions: {'ATP': 'the cell energy currency'},
        estimatedLevel: KnowledgeLevel.intermediate,
        confidence: 0.8,
      )),
    );

    expect(find.text('Photosynthesis'), findsOneWidget);
    expect(find.text('Intermediate'), findsOneWidget);
    expect(find.text('chlorophyll'), findsOneWidget);
    expect(find.text('ATP'), findsOneWidget);
    expect(find.text('NADPH used but never defined'), findsOneWidget);
    expect(find.textContaining('the cell energy currency'), findsOneWidget);
  });

  testWidgets('empty context shows the gentle start-writing prompt',
      (tester) async {
    await pump(tester, const AsyncValue<PageContext>.data(PageContext.empty));

    expect(find.text('Start writing'), findsOneWidget);
    expect(find.textContaining('key concepts'), findsOneWidget);
  });

  testWidgets('loading with no prior context shows the reading state',
      (tester) async {
    await pump(tester, const AsyncValue.loading());

    expect(find.text('Reading your page…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('model-not-ready error offers the one-time download',
      (tester) async {
    await pump(
      tester,
      const AsyncValue<PageContext>.error(
          AiModelNotReadyException('no model'), StackTrace.empty),
    );

    expect(find.text('Turn on AI insights'), findsOneWidget);
    expect(find.textContaining('Download model'), findsOneWidget);
    // Privacy reassurance is part of the shell's promise.
    expect(find.textContaining('nothing leaves your device'), findsOneWidget);
  });

  testWidgets('a download running elsewhere shows live progress, not the button',
      (tester) async {
    // Reopening the panel mid-download used to build a fresh widget State and
    // offer "Download model" again, as though nothing were happening. The
    // state now lives in an app-lifetime provider, so the panel picks the run
    // back up wherever it got to.
    await pump(
      tester,
      const AsyncValue<PageContext>.error(
          AiModelNotReadyException('no model'), StackTrace.empty),
      download: const LlmDownloadRunning(43),
    );

    expect(find.text('43%'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.textContaining('keeps going if you leave'), findsOneWidget);
    expect(find.textContaining('Download model'), findsNothing);
  });

  testWidgets('a failed download shows its own message and offers a retry',
      (tester) async {
    await pump(
      tester,
      const AsyncValue<PageContext>.error(
          AiModelNotReadyException('no model'), StackTrace.empty),
      download: const LlmDownloadFailed('Need 2600 MB free, only 100 MB available.'),
    );

    // The typed message survives verbatim rather than becoming "check your
    // connection" — the storage problem is not a network problem.
    expect(find.textContaining('only 100 MB available'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a generic failure offers a gentle retry, not a red error',
      (tester) async {
    await pump(
      tester,
      AsyncValue.error(Exception('transient'), StackTrace.empty),
    );

    expect(find.text("Couldn't read the page just now"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('writing suggestions render below the context and dismiss',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pageContextProvider(key).overrideWith((ref) => _FixedNotifier(
              const AsyncValue.data(PageContext(
                  currentTopic: 'Essay draft',
                  estimatedLevel: KnowledgeLevel.intermediate,
                  confidence: 0.6)))),
          writingSuggestionsProvider(key).overrideWith((ref) => _FixedWriting([
                const WritingSuggestion(
                  kind: WritingSuggestionKind.repetition,
                  message: 'You lean on "very" a lot here.',
                ),
              ])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiContextView(pageKey: key)),
        ),
      ),
    );

    expect(find.text('WRITING SUGGESTIONS'), findsOneWidget);
    expect(find.text('You lean on "very" a lot here.'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();

    expect(find.text('You lean on "very" a lot here.'), findsNothing);
  });
}
