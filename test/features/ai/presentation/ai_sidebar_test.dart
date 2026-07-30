import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/editor/state/selection_controller.dart';
import 'package:inkflow/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/context_engine/context_engine.dart';
import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';
import 'package:inkflow/features/ai/domain/features/explainer.dart';
import 'package:inkflow/features/ai/domain/page_content_extractor.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';
import 'package:inkflow/features/ai/presentation/context_engine_notifier.dart';
import 'package:inkflow/features/ai/presentation/explain_notifier.dart';
import 'package:inkflow/features/ai/presentation/sidebar/ai_sidebar.dart';

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

class _FakeInstaller implements ModelInstaller {
  @override
  Future<bool> isInstalled(String modelId) async => true;
  @override
  Future<void> install({
    required LlmModelSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<void> uninstall(String modelId) async {}
}

class _FakeStorage implements DeviceStorage {
  @override
  Future<int> freeBytes() async => 1 << 62;
}

/// Records `run` instead of contacting the model, and can start in any state so
/// the Explain view's rendering/actions can be exercised.
class _RecordingExplain extends ExplainNotifier {
  ExplainRequest? lastRun;

  _RecordingExplain({ExplainState? initial})
      : super(
          explainer: Explainer(provider: _NoopProvider()),
          downloads: ModelDownloadManager(
              installer: _FakeInstaller(), storage: _FakeStorage()),
        ) {
    if (initial != null) state = initial;
  }

  @override
  Future<void> run(ExplainRequest request, {bool cloudConfirmed = false}) async =>
      lastRun = request;
}

class _FixedContext extends ContextEngineNotifier {
  _FixedContext(AsyncValue<PageContext> initial)
      : super(
          engine: ContextEngine(provider: _NoopProvider()),
          extractor: PageContentExtractor(
            loadElements: (_) async => const [],
            recognition: HandwritingRecognitionService(),
          ),
          recognition: HandwritingRecognitionService(),
          cache: PageContextCache(),
          pageId: 7,
          languageCode: () => 'en',
        ) {
    state = initial;
  }
}

// ---- Tests ------------------------------------------------------------------

void main() {
  const key = (notebookId: 1, pageId: 7);

  Future<void> pump(
    WidgetTester tester, {
    List<String> selection = const [],
    PageContext context = PageContext.empty,
    _RecordingExplain? explain,
    ValueChanged<SummarizeScopeChoice>? onSummarize,
    ValueChanged<String>? onInsertNote,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          pageContextProvider(key)
              .overrideWith((ref) => _FixedContext(AsyncValue.data(context))),
          selectionProvider.overrideWith((ref) {
            final controller = SelectionController();
            if (selection.isNotEmpty) controller.selectMany(selection);
            return controller;
          }),
          explainNotifierProvider
              .overrideWith((ref) => explain ?? _RecordingExplain()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AiSidebar(
              pageKey: key,
              onClose: () {},
              onSummarize: onSummarize ?? (_) {},
              onInsertNote: onInsertNote ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('Summarize launcher', () {
    testWidgets('offers page/notebook scope; selection hidden with none',
        (tester) async {
      await pump(tester);

      await tester.tap(find.text('Summarize'));
      await tester.pumpAndSettle();

      expect(find.text('This page'), findsOneWidget);
      expect(find.text('Whole notebook'), findsOneWidget);
      expect(find.text('Selected items'), findsNothing);
    });

    testWidgets('choosing a scope invokes onSummarize', (tester) async {
      SummarizeScopeChoice? chosen;
      await pump(tester, onSummarize: (c) => chosen = c);

      await tester.tap(find.text('Summarize'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This page'));
      await tester.pumpAndSettle();

      expect(chosen, SummarizeScopeChoice.page);
    });
  });

  group('Explain launcher', () {
    testWidgets('is disabled (no menu) without a selection', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Explain'));
      await tester.pumpAndSettle();

      // The mode menu never opens.
      expect(find.text('Beginner'), findsNothing);
    });

    testWidgets('offers explanation modes when there is a selection',
        (tester) async {
      await pump(tester, selection: const ['a']);

      await tester.tap(find.text('Explain'));
      await tester.pumpAndSettle();

      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('Real-world'), findsOneWidget);
    });

    testWidgets('choosing a mode runs an explain request', (tester) async {
      final explain = _RecordingExplain();
      await pump(tester, selection: const ['a'], explain: explain);

      await tester.tap(find.text('Explain'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();

      expect(explain.lastRun, isNotNull);
      expect(explain.lastRun!.mode, ExplainMode.advanced);
    });
  });

  testWidgets('tapping a knowledge-gap flag triggers an explain request',
      (tester) async {
    final explain = _RecordingExplain();
    await pump(
      tester,
      explain: explain,
      context: const PageContext(
        currentTopic: 'Cellular respiration',
        knowledgeGaps: ['ATP synthase'],
        estimatedLevel: KnowledgeLevel.intermediate,
        confidence: 0.7,
      ),
    );

    await tester.tap(find.text('ATP synthase'));
    await tester.pump();

    expect(explain.lastRun, isNotNull);
    expect(await explain.lastRun!.resolveContent(), contains('ATP synthase'));
  });

  testWidgets('insert-as-note hands the explanation to the editor',
      (tester) async {
    String? inserted;
    await pump(
      tester,
      explain: _RecordingExplain(
          initial: const ExplainReady('the explanation', ExplainMode.beginner)),
      onInsertNote: (t) => inserted = t,
    );

    expect(find.text('Insert as note'), findsOneWidget);
    await tester.tap(find.text('Insert as note'));
    await tester.pump();

    expect(inserted, 'the explanation');
  });
}
