// Explain's routed provider when the student has picked a cloud model: the
// pick wins over "does it fit on the device", which is the only thing the
// router asked before there was a picker.

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/ai_router.dart' show Reachability;
import 'package:margo/features/ai/domain/routing/intelligent_router.dart';

class _Offline extends Reachability {
  const _Offline();
  @override
  Future<bool> isOnline() async => false;
}

class _FakeProvider implements AiProvider {
  final String name;
  final int window;
  final prompts = <String>[];
  _FakeProvider(this.name, this.window);

  @override
  AiCapabilities get capabilities => AiCapabilities(
        modelId: name,
        displayName: name,
        contextWindowTokens: window,
        isLocal: name == 'local',
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    prompts.add(prompt);
    yield 'from $name';
  }
}

void main() {
  late _FakeProvider local;
  late _FakeProvider gateway;
  late _FakeProvider picked;
  AiProvider? forced;

  RoutedAiProvider build() => RoutedAiProvider(
        task: TaskType.explain,
        router: IntelligentRouter(
          localCapabilities: local.capabilities,
          // Offline, so the router's own rules can never choose the cloud:
          // any cloud call below is the pick's doing.
          reachability: const _Offline(),
        ),
        local: local,
        cloudMid: gateway,
        cloudFrontier: gateway,
        privacy: () => CloudPrivacy.askEachTime,
        forcedCloud: () => forced,
      );

  setUp(() {
    local = _FakeProvider('local', 4096);
    gateway = _FakeProvider('gateway', 256000);
    picked = _FakeProvider('picked', 32000);
    forced = null;
  });

  test('a short passage goes to the picked model, not the device', () async {
    forced = picked;

    expect(await build().generate(prompt: 'a short passage').join(),
        'from picked');
    expect(local.prompts, isEmpty);
    expect(gateway.prompts, isEmpty);
  });

  test('the passage is not cut down to the on-device budget first', () async {
    forced = picked;
    final long = List.filled(4000, 'word').join(' ');

    await build().generate(prompt: long).drain<void>();

    expect(picked.prompts.single, long);
  });

  test('says a cloud call is coming, so the caller can ask first', () async {
    forced = picked;

    expect(await build().peekRoute('a short passage'), isNotNull);
  });

  test('budgets for the picked model\'s window', () {
    forced = picked;

    expect(build().capabilities.contextWindowTokens, 32000);
  });

  test('with nothing picked it routes exactly as before', () async {
    final provider = build();

    expect(await provider.peekRoute('a short passage'), isNull);
    expect(await provider.generate(prompt: 'a short passage').join(),
        'from local');
    expect(provider.capabilities.contextWindowTokens, 256000);
  });

  test('a pick made between two questions takes effect on the second',
      () async {
    final provider = build();
    expect(await provider.generate(prompt: 'one').join(), 'from local');

    forced = picked;
    expect(await provider.generate(prompt: 'two').join(), 'from picked');
  });
}
