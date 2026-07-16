import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/summarize/domain/services/ai_router.dart';

class FakeReachability extends Reachability {
  final bool online;
  const FakeReachability(this.online);
  @override
  Future<bool> isOnline() async => online;
}

void main() {
  const short = 100;
  const long = AiRouter.localInputWordBudget + 1;

  AiRouter router({
    required bool online,
    required bool modelInstalled,
    void Function()? onModelCheck,
  }) =>
      AiRouter(
        reachability: FakeReachability(online),
        isLocalModelInstalled: () async {
          onModelCheck?.call();
          return modelInstalled;
        },
      );

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
      final d = await router(online: true, modelInstalled: true).decide(
          inputWordCount: AiRouter.localInputWordBudget, cloudEnabled: true);
      expect(d.route, AiRoute.local);
      expect(d.truncateForLocal, isFalse);
    });
  });
}
