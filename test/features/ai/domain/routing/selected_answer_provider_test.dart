import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/catalog/ai_model_entry.dart';
import 'package:margo/features/ai/domain/catalog/answer_route.dart';
import 'package:margo/features/ai/domain/routing/selected_answer_provider.dart';

class _FakeProvider implements AiProvider {
  final String name;
  final int window;
  final bool isLocal;
  final AiException? fails;
  final calls = <({String prompt, String? system, int history})>[];
  AiGenerationOptions? lastOptions;

  _FakeProvider(this.name, this.window, {this.isLocal = false, this.fails});

  @override
  AiCapabilities get capabilities => AiCapabilities(
        modelId: name,
        displayName: name,
        contextWindowTokens: window,
        isLocal: isLocal,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    calls.add((prompt: prompt, system: systemPrompt, history: history?.length ?? 0));
    lastOptions = options;
    if (fails != null) throw fails!;
    yield 'from $name';
  }
}

const _mine = AiModelEntry(
  id: 'user:c1:big',
  displayName: 'My AI · Big',
  source: ModelSource.userKey,
  contextWindowTokens: 32000,
);

void main() {
  late _FakeProvider local;
  late _FakeProvider cloud;
  late AnswerRoute route;
  late SelectedAnswerProvider provider;
  final askedFor = <String>[];

  setUp(() {
    local = _FakeProvider('local', 4096, isLocal: true);
    cloud = _FakeProvider('cloud', 32000);
    route = const LocalFirst(null);
    askedFor.clear();
    provider = SelectedAnswerProvider(
      local: local,
      route: () => route,
      cloudFor: (entry) {
        askedFor.add(entry.id);
        return cloud;
      },
    );
  });

  test('the on-device model answers when nothing is picked', () async {
    expect(await provider.generate(prompt: 'q').join(), 'from local');
    expect(cloud.calls, isEmpty);
  });

  test('the on-device model answers when the route is on-device only',
      () async {
    route = const LocalOnly();

    expect(await provider.generate(prompt: 'q').join(), 'from local');
    expect(cloud.calls, isEmpty);
  });

  test('the picked model answers, and the on-device model is not asked',
      () async {
    route = const CloudDirect(_mine);

    expect(await provider.generate(prompt: 'q').join(), 'from cloud');
    expect(local.calls, isEmpty);
    expect(askedFor, ['user:c1:big']);
  });

  test('everything about the request reaches the picked model unchanged',
      () async {
    route = const CloudDirect(_mine);
    const options = AiGenerationOptions(temperature: 0.2, maxTokens: 512);

    await provider.generate(
      prompt: 'q',
      systemPrompt: 'be a teacher',
      history: const [AiMessage.user('earlier')],
      options: options,
    ).drain<void>();

    expect(cloud.calls.single, (prompt: 'q', system: 'be a teacher', history: 1));
    expect(cloud.lastOptions, options);
  });

  test('a new pick takes effect on the very next question', () async {
    expect(await provider.generate(prompt: 'one').join(), 'from local');

    route = const CloudDirect(_mine);
    expect(await provider.generate(prompt: 'two').join(), 'from cloud');

    route = const LocalOnly();
    expect(await provider.generate(prompt: 'three').join(), 'from local');
  });

  test('reports the window of whichever model will answer', () {
    expect(provider.capabilities.contextWindowTokens, 4096);
    expect(provider.capabilities.isLocal, isTrue);

    route = const CloudDirect(_mine);
    expect(provider.capabilities.contextWindowTokens, 32000);
    expect(provider.capabilities.isLocal, isFalse);
  });

  test('a picked model that fails is reported, never quietly swapped for the '
      'on-device model', () async {
    cloud = _FakeProvider(
      'cloud',
      32000,
      fails: const AiUnavailableException("Couldn't reach api.example.com."),
    );
    route = const CloudDirect(_mine);

    await expectLater(
      provider.generate(prompt: 'q').toList(),
      throwsA(isA<AiUnavailableException>()),
    );
    expect(local.calls, isEmpty);
  });
}
