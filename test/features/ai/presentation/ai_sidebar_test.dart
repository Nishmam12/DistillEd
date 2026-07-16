import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/editor/state/selection_controller.dart';
import 'package:inkflow/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/context_engine/context_engine.dart';
import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';
import 'package:inkflow/features/ai/domain/page_content_extractor.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';
import 'package:inkflow/features/ai/presentation/context_engine_notifier.dart';
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

/// Pins the context view to a fixed state so the sidebar renders without the
/// engine running — the focus here is the Summarize launcher.
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
    required List<String> selection,
    required ValueChanged<SummarizeScopeChoice> onSummarize,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          pageContextProvider(key).overrideWith(
              (ref) => _FixedNotifier(const AsyncValue.data(PageContext.empty))),
          selectionProvider.overrideWith((ref) {
            final controller = SelectionController();
            if (selection.isNotEmpty) controller.selectMany(selection);
            return controller;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AiSidebar(
              pageKey: key,
              onClose: () {},
              onSummarize: onSummarize,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('offers page and notebook scope; selection hidden with none',
      (tester) async {
    await pump(tester, selection: const [], onSummarize: (_) {});

    await tester.tap(find.text('Summarize'));
    await tester.pumpAndSettle();

    expect(find.text('This page'), findsOneWidget);
    expect(find.text('Whole notebook'), findsOneWidget);
    expect(find.text('Selected items'), findsNothing);
  });

  testWidgets('selection scope appears when the editor has a selection',
      (tester) async {
    await pump(tester, selection: const ['a', 'b'], onSummarize: (_) {});

    await tester.tap(find.text('Summarize'));
    await tester.pumpAndSettle();

    expect(find.text('Selected items'), findsOneWidget);
  });

  testWidgets('choosing a scope invokes onSummarize with it', (tester) async {
    SummarizeScopeChoice? chosen;
    await pump(tester, selection: const [], onSummarize: (c) => chosen = c);

    await tester.tap(find.text('Summarize'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This page'));
    await tester.pumpAndSettle();

    expect(chosen, SummarizeScopeChoice.page);
  });
}
