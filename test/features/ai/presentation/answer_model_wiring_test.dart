// The wiring that turns "the stored pick + the saved connections + the cloud
// switch" into the model that answers. The pure rule is tested in
// `domain/catalog/answer_route_test.dart`; this checks that the providers feed
// it the live values and act on the result.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/catalog/ai_model_entry.dart';
import 'package:margo/features/ai/domain/catalog/answer_route.dart';
import 'package:margo/features/ai/domain/catalog/user_connection.dart';
import 'package:margo/features/ai/presentation/ai_providers.dart';

class _FakeProvider implements AiProvider {
  final String name;
  final int window;
  final calls = <String>[];
  _FakeProvider(this.name, this.window);

  @override
  AiCapabilities get capabilities => AiCapabilities(
        modelId: name,
        displayName: name,
        contextWindowTokens: window,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    calls.add(prompt);
    yield 'from $name';
  }
}

const _connection = UserConnection(
  id: 'c1',
  label: 'My AI',
  presetId: 'custom',
  baseUrl: 'https://api.example.com/v1',
  models: [
    UserModel(
      modelId: 'big',
      displayName: 'Big',
      contextWindowTokens: 32000,
      supportsTools: true,
    ),
    UserModel(modelId: 'plain', displayName: 'Plain'),
  ],
);

const _bigId = 'user:c1:big';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeProvider local;
  late _FakeProvider cloud;
  late ProviderContainer container;
  final cloudAskedFor = <String>[];

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    local = _FakeProvider('local', 4096);
    cloud = _FakeProvider('cloud', 32000);
    cloudAskedFor.clear();
    container = ProviderContainer(overrides: [
      secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      localAiProvider.overrideWithValue(local),
      cloudProviderForProvider.overrideWithValue((entry) {
        cloudAskedFor.add(entry.id);
        return cloud;
      }),
    ]);
    addTearDown(container.dispose);
    container.read(settingsProvider);
    container.read(userConnectionsProvider);
    await settle();
  });

  Future<void> addConnectionAndPick(String entryId) async {
    final saved = await container
        .read(userConnectionsProvider.notifier)
        .save(_connection, apiKey: 'sk-test-1234567890abcdef');
    expect(saved, isTrue);
    await container.read(settingsProvider.notifier).setCloudAiEnabled(true);
    await container.read(settingsProvider.notifier).setAnswerModelId(entryId);
  }

  AnswerRoute route() => container.read(answerRouteProvider)();

  group('the model list', () {
    test('lists Margo\'s own models, none of which can be picked yet', () {
      final margo = container
          .read(modelCatalogueProvider)
          .where((e) => e.source == ModelSource.margo);

      expect(margo, isNotEmpty);
      expect(margo.where((e) => e.pickable), isEmpty);
    });

    test('gains a row for each model of a saved connection', () async {
      await addConnectionAndPick(kAnswerAuto);

      final mine = container
          .read(modelCatalogueProvider)
          .where((e) => e.source == ModelSource.userKey)
          .map((e) => e.id);

      expect(mine, [_bigId, 'user:c1:plain']);
    });

    test('loses them when the connection is deleted', () async {
      await addConnectionAndPick(kAnswerAuto);

      await container.read(userConnectionsProvider.notifier).delete('c1');

      expect(
        container
            .read(modelCatalogueProvider)
            .where((e) => e.source == ModelSource.userKey),
        isEmpty,
      );
    });
  });

  group('who answers', () {
    test('out of the box it is the on-device model and nothing else', () {
      expect(route(), isA<LocalOnly>());
    });

    test('with cloud on and nothing picked it is on-device first, with no '
        'cloud to fall back to yet', () async {
      await container.read(settingsProvider.notifier).setCloudAiEnabled(true);

      expect((route() as LocalFirst).escalation, isNull);
    });

    test('a picked model answers', () async {
      await addConnectionAndPick(_bigId);

      expect((route() as CloudDirect).model.id, _bigId);
      expect(
        await container.read(answerAiProvider).generate(prompt: 'q').join(),
        'from cloud',
      );
      expect(cloudAskedFor, contains(_bigId));
      expect(local.calls, isEmpty);
    });

    test('the answering provider reports the picked model\'s window', () async {
      expect(
        container.read(answerAiProvider).capabilities.contextWindowTokens,
        4096,
      );

      await addConnectionAndPick(_bigId);

      expect(
        container.read(answerAiProvider).capabilities.contextWindowTokens,
        32000,
      );
    });

    test('switching cloud AI off sends the next question to the device, with '
        'the pick still stored', () async {
      await addConnectionAndPick(_bigId);

      await container.read(settingsProvider.notifier).setCloudAiEnabled(false);

      expect(route(), isA<LocalOnly>());
      expect(
        await container.read(answerAiProvider).generate(prompt: 'q').join(),
        'from local',
      );
      expect(cloud.calls, isEmpty);
    });

    test('deleting the picked model\'s connection falls back to auto',
        () async {
      await addConnectionAndPick(_bigId);

      await container.read(userConnectionsProvider.notifier).delete('c1');

      expect(route(), isA<LocalFirst>());
    });
  });

  group('Explain', () {
    final longPassage = List.filled(4000, 'word').join(' ');

    test('a short passage goes to the picked model', () async {
      await addConnectionAndPick(_bigId);
      final explain = container.read(explainAiProviderProvider);

      expect(await explain.generate(prompt: 'entropy').join(), 'from cloud');
      expect(local.calls, isEmpty);
    });

    test('with the on-device model picked, a passage too long for it still '
        'stays on the device', () async {
      await addConnectionAndPick(kAnswerLocal);
      final explain = container.read(explainAiProviderProvider);

      expect(await explain.peekRoute(longPassage), isNull);
      expect(await explain.generate(prompt: longPassage).join(), 'from local');
      expect(cloud.calls, isEmpty);
    });

    test('with cloud AI off, the picked model is not used', () async {
      await addConnectionAndPick(_bigId);
      await container.read(settingsProvider.notifier).setCloudAiEnabled(false);
      final explain = container.read(explainAiProviderProvider);

      expect(await explain.generate(prompt: 'entropy').join(), 'from local');
      expect(cloud.calls, isEmpty);
    });
  });

  group('tools', () {
    test('a picked model that supports tools is offered for them', () async {
      await addConnectionAndPick(_bigId);
      expect(container.read(answerSupportsToolsProvider)(), isTrue);
    });

    test('a picked model that does not is not', () async {
      await addConnectionAndPick('user:c1:plain');
      expect(container.read(answerSupportsToolsProvider)(), isFalse);
    });
  });

  group('picking a model changes nothing about how pages are read', () {
    test('the page-reading predicates give the same answers', () async {
      await container
          .read(settingsProvider.notifier)
          .setAiMode(AiProcessingMode.auto);
      final before = container.read(settingsProvider);
      final uploadBefore = mayUploadImages(before);
      final analyzeBefore = mayAnalyzeInCloud(before);

      await addConnectionAndPick(_bigId);

      final after = container.read(settingsProvider);
      expect(after.aiMode, AiProcessingMode.auto);
      expect(after.aiMode.prefersCloud, isFalse);
      expect(mayUploadImages(after), uploadBefore);
      expect(mayAnalyzeInCloud(after), analyzeBefore);
    });
  });

  group('asking before a send', () {
    test('a newly added model is asked about, and a yes is remembered',
        () async {
      await addConnectionAndPick(_bigId);
      await container
          .read(settingsProvider.notifier)
          .setCloudPrivacy(CloudPrivacy.allowCloudForNonSensitive);
      final model = (route() as CloudDirect).model;
      final gate = container.read(cloudSendGateProvider.notifier);

      final answer = gate.confirm(model);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(cloudSendGateProvider)?.host, 'api.example.com');
      gate.answer(true);
      expect(await answer, isTrue);
      await settle();

      expect(container.read(settingsProvider).hasSeenFirstCloudCall, isTrue);
      expect(
        container.read(userConnectionsProvider).single.consentShown,
        isTrue,
      );
      expect(await gate.confirm(model), isTrue, reason: 'not asked twice');
    });
  });
}
