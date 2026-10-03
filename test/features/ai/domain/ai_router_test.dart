import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/domain/ai_capabilities.dart';
import 'package:margo/features/ai/domain/ai_router.dart';

class FakeReachability extends Reachability {
  final bool online;
  const FakeReachability(this.online);
  @override
  Future<bool> isOnline() async => online;
}

/// Counts how often the network is asked about — each ask is a DNS lookup that
/// can take two seconds on a bad connection.
class CountingReachability extends Reachability {
  final bool online;
  int probes = 0;
  CountingReachability(this.online);
  @override
  Future<bool> isOnline() async {
    probes++;
    return online;
  }
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

    test('a system prompt is paid for out of the budget, never past the window',
        () {
      const lite = AiCapabilities(
        modelId: 'lite',
        displayName: 'lite',
        contextWindowTokens: 2048,
        isLocal: true,
      );
      // ~1,400 tokens of tutor prompt, as Explain sends.
      final prompt = 'x' * 4900;
      final withPrompt =
          AiRouter.inputWordBudgetFor(localCaps, systemPrompt: prompt);

      expect(withPrompt, ((4096 - 512 - 200 - 1400) / 1.35).floor());
      expect(withPrompt, lessThan(budget));
      // A prompt bigger than the window leaves no passage, never a negative
      // (or overflowing) one.
      expect(AiRouter.inputWordBudgetFor(lite, systemPrompt: prompt), 0);
      // A long reply request is capped at 3/8 of the window.
      expect(AiRouter.inputWordBudgetFor(lite, responseTokens: 4096),
          ((2048 - 768 - 200) / 1.35).floor());
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

  group('AiRouter system prompt budget', () {
    test('a long system prompt shrinks the note budget', () {
      final base = AiRouter.inputWordBudgetFor(localCaps);
      final tight =
          AiRouter.inputWordBudgetFor(localCaps, systemPrompt: 'x' * 1400);
      expect(tight, lessThan(base));
    });

    test('the budget is never negative', () {
      expect(
          AiRouter.inputWordBudgetFor(localCaps, systemPrompt: 'x' * 1000000),
          0);
    });
  });

  group('AiRouter network probe', () {
    AiRouter withProbe(CountingReachability r, {bool modelInstalled = true}) =>
        AiRouter(
          localCapabilities: localCaps,
          reachability: r,
          isLocalModelInstalled: () async => modelInstalled,
        );

    test('a local answer with cloud off never touches the network', () async {
      final reach = CountingReachability(true);
      final d = await withProbe(reach)
          .decide(inputWordCount: short, cloudEnabled: false);

      expect(d.route, AiRoute.local);
      expect(reach.probes, 0,
          reason: 'a DNS lookup before every call, for a route not taken');
    });

    test('cloud on but the note fits: still no probe', () async {
      final reach = CountingReachability(true);
      final d = await withProbe(reach)
          .decide(inputWordCount: short, cloudEnabled: true);

      expect(d.route, AiRoute.local);
      expect(reach.probes, 0);
    });

    test('over budget with cloud on asks whether the cloud is reachable',
        () async {
      final reach = CountingReachability(true);
      final d = await withProbe(reach)
          .decide(inputWordCount: long, cloudEnabled: true);

      expect(d.route, AiRoute.cloud);
      expect(reach.probes, 1);
    });

    test('cloud-first asks, and falls back to local when offline', () async {
      final reach = CountingReachability(false);
      final d = await withProbe(reach).decide(
          inputWordCount: short, cloudEnabled: true, preferCloud: true);

      expect(d.route, AiRoute.local);
      expect(reach.probes, 1);
    });

    test('a missing model asks, to choose download or error', () async {
      final online = CountingReachability(true);
      expect(
          (await withProbe(online, modelInstalled: false)
                  .decide(inputWordCount: short, cloudEnabled: false))
              .route,
          AiRoute.downloadThenLocal);
      expect(online.probes, 1);

      final offline = CountingReachability(false);
      expect(
          (await withProbe(offline, modelInstalled: false)
                  .decide(inputWordCount: short, cloudEnabled: false))
              .route,
          AiRoute.errorOfflineNoModel);
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

  group('AiRouter — a degraded local model', () {
    // The model fell back to the CPU: several times slower, so for someone who
    // has opted in the network is the faster route even for a short note.
    AiRouter degraded({required bool online}) => AiRouter(
          localCapabilities: localCaps,
          reachability: FakeReachability(online),
          isLocalModelInstalled: () async => true,
          isLocalDegraded: () => true,
        );

    test('online + opted in → cloud, even for short text', () async {
      final d = await degraded(online: true)
          .decide(inputWordCount: short, cloudEnabled: true);
      expect(d.route, AiRoute.cloud);
    });

    test('NOT opted in → stays local — slow never overrides privacy', () async {
      final d = await degraded(online: true)
          .decide(inputWordCount: short, cloudEnabled: false);
      expect(d.route, AiRoute.local);
    });

    test('offline → stays local', () async {
      final d = await degraded(online: false)
          .decide(inputWordCount: short, cloudEnabled: true);
      expect(d.route, AiRoute.local);
    });
  });
}
