import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/ai_router.dart';
import 'package:inkflow/features/ai/domain/features/explainer.dart';

/// Records what it was asked and replays a scripted set of chunks.
class _ScriptedProvider implements AiProvider {
  final List<String> chunks;
  String? lastPrompt;
  String? lastSystemPrompt;
  AiGenerationOptions? lastOptions;

  _ScriptedProvider(this.chunks);

  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'scripted',
        displayName: 'Scripted',
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
    lastPrompt = prompt;
    lastSystemPrompt = systemPrompt;
    lastOptions = options;
    for (final c in chunks) {
      yield c;
    }
  }

  @override
  Future<List<double>> embed(String text) async =>
      throw const AiUnsupportedOperationException('not needed');
}

void main() {
  group('Explainer', () {
    test('streams the provider chunks unchanged, in order', () async {
      final provider = _ScriptedProvider(['Photo', 'synth', 'esis.']);
      final explainer = Explainer(provider: provider);

      final chunks = await explainer
          .explain(const ExplainInput(
              content: 'what is photosynthesis',
              mode: ExplainMode.beginner))
          .toList();

      expect(chunks, ['Photo', 'synth', 'esis.']);
      expect(chunks.join(), 'Photosynthesis.');
    });

    test('passage is carried in the prompt; system prompt reflects the mode',
        () async {
      final provider = _ScriptedProvider(['ok']);
      final explainer = Explainer(provider: provider);

      await explainer
          .explain(const ExplainInput(
              content: 'mitochondria are the powerhouse',
              mode: ExplainMode.advanced))
          .drain<void>();

      expect(provider.lastPrompt, contains('mitochondria are the powerhouse'));
      expect(provider.lastSystemPrompt, Explainer.systemPromptFor(ExplainMode.advanced));
      expect(provider.lastSystemPrompt, isNot(contains('beginner')));
    });

    test('uses the summarization-style generation preset', () async {
      final provider = _ScriptedProvider(['ok']);
      await Explainer(provider: provider)
          .explain(const ExplainInput(content: 'x y z', mode: ExplainMode.child))
          .drain<void>();

      expect(provider.lastOptions?.temperature, 0.4);
      expect(provider.lastOptions?.topP, 0.95);
      expect(provider.lastOptions?.maxTokens, 512);
    });

    test('content over the context window is truncated to the local budget',
        () async {
      final provider = _ScriptedProvider(['ok']);
      final budget = AiRouter.inputWordBudgetFor(provider.capabilities);
      final longContent = List.filled(budget + 200, 'word').join(' ');

      await Explainer(provider: provider)
          .explain(ExplainInput(content: longContent, mode: ExplainMode.beginner))
          .drain<void>();

      final words = RegExp(r'\bword\b').allMatches(provider.lastPrompt!).length;
      expect(words, budget);
    });

    test('every mode has a distinct, non-empty system prompt', () {
      final prompts =
          ExplainMode.values.map(Explainer.systemPromptFor).toList();
      expect(prompts.toSet().length, ExplainMode.values.length);
      expect(prompts.every((p) => p.trim().isNotEmpty), isTrue);
    });
  });
}
