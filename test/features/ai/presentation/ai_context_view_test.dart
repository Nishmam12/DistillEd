import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/context_engine/context_engine.dart';
import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';
import 'package:inkflow/features/ai/domain/features/writing_assistant.dart';
import 'package:inkflow/features/ai/domain/page_content_extractor.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';
import 'package:inkflow/features/ai/presentation/context_engine_notifier.dart';
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

  Future<void> pump(WidgetTester tester, AsyncValue<PageContext> state) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          pageContextProvider(key).overrideWith((ref) => _FixedNotifier(state)),
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
