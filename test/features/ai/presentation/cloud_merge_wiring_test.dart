import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/domain/catalog/ai_model_entry.dart';
import 'package:margo/features/ai/domain/catalog/answer_route.dart';
import 'package:margo/features/ai/presentation/ai_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [secretStoreProvider.overrideWithValue(InMemorySecretStore())],
    );
    container.read(settingsProvider);
    container.read(userConnectionsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final settings = container.read(settingsProvider.notifier);
    await settings.setCloudProvider(
      presetId: 'openrouter',
      baseUrl: 'https://openrouter.ai/api/v1',
      model: 'example/model',
      contextTokens: 128000,
    );
    await settings.setCloudApiKey('test-key');
  });

  tearDown(() => container.dispose());

  test('the default provider is also available in the answer picker', () {
    final entries = container
        .read(modelCatalogueProvider)
        .where((entry) => entry.source == ModelSource.userKey);
    expect(entries, hasLength(1));
    expect(entries.single.host, 'openrouter.ai');
    expect(entries.single.contextWindowTokens, 128000);
  });

  test(
    'cloud-first answers with the configured default after consent',
    () async {
      await container
          .read(settingsProvider.notifier)
          .setAiMode(AiProcessingMode.cloudFirst);
      final route = container.read(answerRouteProvider)();
      expect(route, isA<CloudDirect>());
      final model = (route as CloudDirect).model;
      expect(
        container.read(cloudProviderForProvider)(model),
        same(container.read(cloudAiProvider)),
      );
      final confirm = container.read(confirmAnswerSendProvider)();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(cloudSendGateProvider)?.host, 'openrouter.ai');
      container.read(cloudSendGateProvider.notifier).answer(false);
      expect(await confirm, isFalse);
    },
  );

  test(
    'an explicit on-device pick overrides the default cloud connection',
    () async {
      final settings = container.read(settingsProvider.notifier);
      await settings.setAiMode(AiProcessingMode.cloudFirst);
      await settings.setAnswerModelId(kAnswerLocal);
      expect(container.read(answerRouteProvider)(), isA<LocalOnly>());
    },
  );

  test(
    'removing the default key removes it from the picker and route',
    () async {
      final settings = container.read(settingsProvider.notifier);
      await settings.setAiMode(AiProcessingMode.cloudFirst);
      await settings.setCloudApiKey('');
      expect(
        container
            .read(modelCatalogueProvider)
            .where((entry) => entry.source == ModelSource.userKey),
        isEmpty,
      );
      expect(container.read(answerRouteProvider)(), isA<LocalFirst>());
    },
  );
}
