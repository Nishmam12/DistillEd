import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/features/writing_assistant.dart';
import 'package:inkflow/features/ai/domain/page_content.dart';
import 'package:inkflow/features/ai/presentation/writing_assistant_notifier.dart';

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

/// Scripts `review` directly so the notifier's behaviour is isolated from the
/// parsing/model path (covered in writing_assistant_test).
class _FakeAssistant extends WritingAssistant {
  final List<WritingSuggestion> result;
  final Object? error;
  int calls = 0;
  String? lastText;

  _FakeAssistant({this.result = const [], this.error})
      : super(provider: _NoopProvider());

  @override
  Future<List<WritingSuggestion>> review(String typedText) async {
    calls++;
    lastText = typedText;
    if (error != null) throw error!;
    return result;
  }
}

PageContent typed(String text) =>
    PageContent(recognizedInkText: '', typedText: text);

WritingSuggestion suggestion(String message) =>
    WritingSuggestion(kind: WritingSuggestionKind.clarity, message: message);

/// Lets the (synchronous-trigger, async-run) review settle.
Future<void> flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  WritingAssistantNotifier build(_FakeAssistant assistant,
          {PageWritingCache? cache, int pageId = 1}) =>
      WritingAssistantNotifier(
        assistant: assistant,
        cache: cache ?? PageWritingCache(),
        pageId: pageId,
      );

  test('review publishes the assistant suggestions', () async {
    final assistant = _FakeAssistant(result: [suggestion('Tighten this.')]);
    final n = build(assistant);

    n.review(typed('a fairly long piece of typed text to review here'));
    await flush();

    expect(n.state, hasLength(1));
    expect(n.state.first.message, 'Tighten this.');
    expect(assistant.calls, 1);
  });

  test('unchanged typed text is not re-reviewed', () async {
    final assistant = _FakeAssistant(result: [suggestion('x')]);
    final n = build(assistant);
    final content = typed('some typed text that stays exactly the same');

    n.review(content);
    await flush();
    n.review(typed('some typed text that stays exactly the same'));
    await flush();

    expect(assistant.calls, 1, reason: 'same signature → skip');
  });

  test('dismiss removes only the chosen suggestion', () async {
    final a = _FakeAssistant(result: [suggestion('one'), suggestion('two')]);
    final n = build(a);
    n.review(typed('enough typed words here to trigger a real review pass'));
    await flush();
    expect(n.state, hasLength(2));

    n.dismiss(n.state.first);

    expect(n.state, hasLength(1));
    expect(n.state.single.message, 'two');
  });

  test('a failing review degrades quietly to no suggestions', () async {
    final a = _FakeAssistant(error: const AiGenerationException('boom'));
    final n = build(a);

    n.review(typed('this typed passage will make the model call blow up'));
    await flush();

    expect(n.state, isEmpty, reason: 'advisory feature never surfaces an error');
  });

  test('cached suggestions seed the initial state and skip a re-review',
      () async {
    const sig = 'typed text used as the cache signature here';
    final cache = PageWritingCache()..save(5, sig, [suggestion('cached')]);
    final assistant = _FakeAssistant(result: [suggestion('fresh')]);
    final n = build(assistant, cache: cache, pageId: 5);

    expect(n.state.single.message, 'cached');

    n.review(typed(sig)); // same signature as the cache
    await flush();

    expect(assistant.calls, 0, reason: 'cache signature matches → no work');
    expect(n.state.single.message, 'cached');
  });
}
