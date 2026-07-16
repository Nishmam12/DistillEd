import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_capabilities.dart';
import 'package:inkflow/features/ai/domain/ai_router.dart';

class FakeReachability extends Reachability {
  final bool online;
  const FakeReachability(this.online);
  @override
  Future<bool> isOnline() async => online;
}

/// Matches the local Gemma 4 E2B setup (4096-token context).
const localCaps = AiCapabilities(
  modelId: 'test-local',
  displayName: 'Test local',
  contextWindowTokens: 4096,
  isLocal: true,
);

void main() {
  AiRouter router({
    required bool online,
    required bool modelInstalled,
    void Function()? onModelCheck,
  }) =>
      AiRouter(
        localCapabilities: localCaps,
        reachability: FakeReachability(online),
        isLocalModelInstalled: () async {
          onModelCheck?.call();
          return modelInstalled;
        },
      );

  final budget =
      router(online: true, modelInstalled: true).localInputWordBudget;
  const short = 100;
  final long = budget + 1;

  group('AiRouter budget', () {
    test('derives the word budget from the local context window', () {
      // (4096 − 512 response reserve − 200 scaffolding) / 1.35 tokens-per-word
      expect(budget, ((4096 - 512 - 200) / 1.35).floor());
    });

    test('a larger context window raises the budget automatically', () {
      final bigger = AiRouter(
        localCapabilities: const AiCapabilities(
          modelId: 'big',
          displayName: 'big',
          contextWindowTokens: 8192,
          isLocal: true,
        ),
        isLocalModelInstalled: () async => true,
      );
      expect(bigger.localInputWordBudget, greaterThan(budget));
    });
  });

  group('AiRouter decision table', () {
    test('offline + model installed → local', () async {
      final d = await router(online: false, modelInstalled: true)
          .decide(inputWordCount: short, cloudEnabled: true);
      expect(d.route, AiRoute.local);
      expect(d.truncateForLocal, isFalse);
    });

    test('offline + model missing → actionable error state', () async {
      final d = await router(online: false, modelInstalled: false)
          .decide(inputWordCount: short, cloudEnabled: true);
      expect(d.route, AiRoute.errorOfflineNoModel);
    });

    test('offline + long text stays local with truncation flag', () async {
      final d = await router(online: false, modelInstalled: true)
          .decide(inputWordCount: long, cloudEnabled: true);
      expect(d.route, AiRoute.local);
      expect(d.truncateForLocal, isTrue);
    });

    test('online + cloud enabled + over budget → cloud', () async {
      final d = await router(online: true, modelInstalled: true)
          .decide(inputWordCount: long, cloudEnabled: true);
      expect(d.route, AiRoute.cloud);
    });

    test('cloud route does not depend on the local model being installed',
        () async {
      var checked = false;
      final d = await router(
        online: true,
        modelInstalled: false,
        onModelCheck: () => checked = true,
      ).decide(inputWordCount: long, cloudEnabled: true);
      expect(d.route, AiRoute.cloud);
      expect(checked, isFalse,
          reason: 'no local-model probe needed on the cloud path');
    });

    test('online + cloud enabled + short text → local (privacy default)',
        () async {
      final d = await router(online: true, modelInstalled: true)
          .decide(inputWordCount: short, cloudEnabled: true);
      expect(d.route, AiRoute.local);
    });

    test('online + cloud DISABLED + long text → local + truncate', () async {
      final d = await router(online: true, modelInstalled: true)
          .decide(inputWordCount: long, cloudEnabled: false);
      expect(d.route, AiRoute.local);
      expect(d.truncateForLocal, isTrue);
    });

    test('online + model missing → download then local', () async {
      final d = await router(online: true, modelInstalled: false)
          .decide(inputWordCount: short, cloudEnabled: false);
      expect(d.route, AiRoute.downloadThenLocal);
    });

    test('exactly at the budget boundary routes local without truncation',
        () async {
      final d = await router(online: true, modelInstalled: true)
          .decide(inputWordCount: budget, cloudEnabled: true);
      expect(d.route, AiRoute.local);
      expect(d.truncateForLocal, isFalse);
    });
  });
}
