import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/ai_router.dart';
import 'package:margo/features/ai/domain/context_engine/context_engine.dart';
import 'package:margo/features/ai/domain/context_engine/page_context.dart';
import 'package:margo/features/ai/domain/features/explainer.dart';
import 'package:margo/features/ai/domain/features/flashcard_generator.dart';
import 'package:margo/features/ai/domain/features/notes_qa.dart';
import 'package:margo/features/ai/domain/features/quiz_generator.dart';
import 'package:margo/features/ai/domain/features/writing_assistant.dart';
import 'package:margo/features/ai/domain/tutor_voice.dart';
import 'package:margo/features/summarize/domain/services/summarization_service.dart';

const _lite = AiCapabilities(
  modelId: 'lite',
  displayName: 'lite',
  contextWindowTokens: kCompactPromptWindowTokens,
  isLocal: true,
);

/// Records the system prompt and reply size a feature asks the lite model for.
class _Recorder implements AiProvider {
  final asked = <(String, int)>[];

  @override
  AiCapabilities get capabilities => _lite;

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    asked.add((systemPrompt ?? '', options?.maxTokens ?? 0));
    yield '{}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('on the 2,048-token lite window every feature gets a real passage and '
      'prompt + passage + reply fit the window', () async {
    final rec = _Recorder();
    final note = List.filled(5000, 'word').join(' ');
    for (final mode in ExplainMode.values) {
      await Explainer(provider: rec)
          .explain(ExplainInput(content: note, mode: mode))
          .drain<void>();
    }
    await QuizGenerator(provider: rec)
        .generate(text: note, level: KnowledgeLevel.intermediate);
    await FlashcardGenerator(provider: rec).generate(
      context: PageContext.empty,
      pageText: note,
      notebookId: 1,
      pageId: 1,
    );
    await WritingAssistant(provider: rec).review(note);

    final features = <(String, int)>[
      ...rec.asked,
      (NotesQa.systemPrompt, 512),
      (ContextEngine.schemaInstruction, ContextEngine.extractOptions.maxTokens!),
      (SummarizationService.noteInstruction, 512),
      (SummarizationService.reduceInstruction, 512),
    ];
    expect(features.length, greaterThan(10));

    const window = kCompactPromptWindowTokens;
    for (final (system, reply) in features) {
      final words = AiRouter.inputWordBudgetFor(_lite,
          systemPrompt: system, responseTokens: reply);
      expect(words, greaterThanOrEqualTo(300), reason: system.substring(0, 60));

      final sent = compactForWindow(system, window);
      final replyCap = AiRouter.replyCapFor(window);
      final total = sent.length / AiRouter.charsPerToken +
          AiRouter.scaffoldingReserveTokens +
          words * AiRouter.tokensPerWord +
          (reply < replyCap ? reply : replyCap);
      expect(total, lessThanOrEqualTo(window), reason: system.substring(0, 60));
    }
  });

  test('only a small window gets the compact voice', () {
    expect(compactForWindow(kTutorVoiceWithMath, 4096), kTutorVoiceWithMath);
    expect(compactForWindow(kTutorVoiceWithMath, 2048),
        '$kTutorVoiceCompact\n\n$kMathMarkupCompact');
  });
}
