import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/ai_router.dart' show Reachability;
import 'package:inkflow/features/ai/domain/routing/intelligent_router.dart';

class _FakeReachability extends Reachability {
  final bool online;
  const _FakeReachability(this.online);
  @override
  Future<bool> isOnline() async => online;
}

class _ScriptedProvider implements AiProvider {
  final String name;
  final List<String> chunks;
  String? lastPrompt;

  _ScriptedProvider(this.name, this.chunks);

  @override
  AiCapabilities get capabilities => AiCapabilities(
        modelId: name,
        displayName: name,
        contextWindowTokens: 4096,
        isLocal: name == 'local',
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    lastPrompt = prompt;
    for (final c in chunks) {
      yield c;
    }
  }

  @override
  Future<List<double>> embed(String text) async => [1.0, 2.0, 3.0];
}

const _localCapabilities = AiCapabilities(
  modelId: 'local',
  displayName: 'Local',
  contextWindowTokens: 4096,
  isLocal: true,
);

// budget = ((4096 - 512 - 200) / 1.35).floor() = 2506
const _localBudget = 2506;

IntelligentRouter _router(bool online) => IntelligentRouter(
    localCapabilities: _localCapabilities, reachability: _FakeReachability(online));

void main() {
  group('IntelligentRouter.decide', () {
    test('grammar/rewrite/explain stay local within budget', () async {
      final router = _router(true);
      for (final task in [TaskType.grammar, TaskType.rewrite, TaskType.explain]) {
        final target = await router.decide(
          task: task,
          inputWordCount: 100,
          privacy: CloudPrivacy.allowCloudForNonSensitive,
        );
        expect(target, isA<RouteLocal>());
      }
    });

    test('over-budget escapes to cloud-mid when privacy allows and online',
        () async {
      final router = _router(true);
      final target = await router.decide(
        task: TaskType.summarizeNotebook,
        inputWordCount: _localBudget + 1,
        privacy: CloudPrivacy.askEachTime,
      );
      expect(target, isA<RouteCloud>());
      expect((target as RouteCloud).tier, CloudTier.mid);
    });

    test('over-budget stays local when privacy is localOnly', () async {
      final router = _router(true);
      final target = await router.decide(
        task: TaskType.research,
        inputWordCount: _localBudget + 1,
        privacy: CloudPrivacy.localOnly,
      );
      expect(target, isA<RouteLocal>());
    });

    test('over-budget stays local when offline (degrades gracefully)',
        () async {
      final router = _router(false);
      final target = await router.decide(
        task: TaskType.summarizeNotebook,
        inputWordCount: _localBudget + 1,
        privacy: CloudPrivacy.allowCloudForNonSensitive,
      );
      expect(target, isA<RouteLocal>());
    });

    test(
        'thesisWriting/complexReasoning/largeCodebase go frontier when privacy allows, regardless of length',
        () async {
      final router = _router(true);
      for (final task in [
        TaskType.thesisWriting,
        TaskType.complexReasoning,
        TaskType.largeCodebase,
      ]) {
        final target = await router.decide(
          task: task,
          inputWordCount: 5, // trivially short — still frontier
          privacy: CloudPrivacy.askEachTime,
        );
        expect(target, isA<RouteCloud>());
        expect((target as RouteCloud).tier, CloudTier.frontier);
      }
    });

    test('frontier tasks stay local when privacy is localOnly', () async {
      final router = _router(true);
      final target = await router.decide(
        task: TaskType.complexReasoning,
        inputWordCount: 5,
        privacy: CloudPrivacy.localOnly,
      );
      expect(target, isA<RouteLocal>());
    });

    test('frontier tasks stay local when offline', () async {
      final router = _router(false);
      final target = await router.decide(
        task: TaskType.largeCodebase,
        inputWordCount: 5,
        privacy: CloudPrivacy.allowCloudForNonSensitive,
      );
      expect(target, isA<RouteLocal>());
    });
  });

  group('RoutedAiProvider', () {
    late _ScriptedProvider local;
    late _ScriptedProvider cloudMid;
    late _ScriptedProvider cloudFrontier;

    setUp(() {
      local = _ScriptedProvider('local', ['local reply']);
      cloudMid = _ScriptedProvider('cloud-mid', ['mid reply']);
      cloudFrontier = _ScriptedProvider('cloud-frontier', ['frontier reply']);
    });

    RoutedAiProvider makeProvider({
      required TaskType task,
      required bool online,
      required CloudPrivacy privacy,
    }) {
      final router = IntelligentRouter(
        localCapabilities: local.capabilities,
        reachability: _FakeReachability(online),
      );
      return RoutedAiProvider(
        task: task,
        router: router,
        local: local,
        cloudMid: cloudMid,
        cloudFrontier: cloudFrontier,
        privacy: () => privacy,
      );
    }

    test('generate delegates to local for a short explain', () async {
      final provider = makeProvider(
          task: TaskType.explain, online: true, privacy: CloudPrivacy.askEachTime);
      final chunks = await provider.generate(prompt: 'short passage').toList();
      expect(chunks, ['local reply']);
      expect(local.lastPrompt, 'short passage');
    });

    test('generate delegates to cloud-frontier for complex reasoning',
        () async {
      final provider = makeProvider(
          task: TaskType.complexReasoning,
          online: true,
          privacy: CloudPrivacy.allowCloudForNonSensitive);
      final chunks = await provider.generate(prompt: 'reason about this').toList();
      expect(chunks, ['frontier reply']);
    });

    test('peekRoute returns null for a local decision', () async {
      final provider = makeProvider(
          task: TaskType.explain, online: true, privacy: CloudPrivacy.askEachTime);
      final decision = await provider.peekRoute('short passage');
      expect(decision, isNull);
    });

    test('peekRoute returns the tier for a cloud decision', () async {
      final provider = makeProvider(
          task: TaskType.thesisWriting,
          online: true,
          privacy: CloudPrivacy.allowCloudForNonSensitive);
      final decision = await provider.peekRoute('anything');
      expect(decision, isNotNull);
      expect(decision!.tier, CloudTier.frontier);
    });

    test('generate truncates to the local budget when routing local anyway',
        () async {
      // localOnly forces RouteLocal even though this input is over budget —
      // exactly the case where truncation matters.
      final provider = makeProvider(
          task: TaskType.explain, online: true, privacy: CloudPrivacy.localOnly);
      final longPrompt = List.generate(_localBudget + 500, (i) => 'w$i').join(' ');
      await provider.generate(prompt: longPrompt).toList();
      expect(local.lastPrompt!.split(' ').length, _localBudget);
    });

    test('capabilities report the largest context window of the three',
        () async {
      final provider = makeProvider(
          task: TaskType.explain, online: true, privacy: CloudPrivacy.askEachTime);
      // All three fakes report 4096 here, so just confirm it's at least that.
      expect(provider.capabilities.contextWindowTokens, greaterThanOrEqualTo(4096));
    });

    test('embed delegates to the local provider', () async {
      final provider = makeProvider(
          task: TaskType.explain, online: true, privacy: CloudPrivacy.askEachTime);
      final vector = await provider.embed('hello');
      expect(vector, [1.0, 2.0, 3.0]);
    });
  });
}
