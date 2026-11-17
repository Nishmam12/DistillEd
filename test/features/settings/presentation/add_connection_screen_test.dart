// The "Add an AI" screen: a student types their own key, checks it, picks the
// models they want, and saves. What matters most here is that a key that does
// not work is never saved, and that a saved key ends up in the keystore.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/data/catalog/user_connection_store.dart';
import 'package:margo/features/ai/data/providers/model_connection_tester.dart';
import 'package:margo/features/ai/presentation/ai_providers.dart';
import 'package:margo/features/settings/presentation/screens/settings_screen.dart';

const _key = 'sk-test-1234567890abcdef';

class _FakeTester extends ModelConnectionTester {
  ConnectionTestResult listResult = const ConnectionOk(['alpha', 'beta']);
  ConnectionTestResult probeResult = const ConnectionOk(['typed-model']);
  final listed = <({String baseUrl, String apiKey})>[];
  final probed = <String>[];

  @override
  Future<ConnectionTestResult> listModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    listed.add((baseUrl: baseUrl, apiKey: apiKey));
    return listResult;
  }

  @override
  Future<ConnectionTestResult> probe({
    required String baseUrl,
    required String apiKey,
    required String modelId,
    required String label,
  }) async {
    probed.add(modelId);
    return probeResult;
  }
}

void main() {
  late _FakeTester tester;
  late InMemorySecretStore secrets;
  late ProviderContainer container;

  Future<void> pump(WidgetTester widgets) async {
    SharedPreferences.setMockInitialValues({});
    secrets = InMemorySecretStore();
    container = ProviderContainer(overrides: [
      secretStoreProvider.overrideWithValue(secrets),
      modelConnectionTesterProvider.overrideWithValue(tester),
    ]);
    addTearDown(container.dispose);
    widgets.view.physicalSize = const Size(1200, 2400);
    widgets.view.devicePixelRatio = 1.0;
    addTearDown(widgets.view.reset);
    await widgets.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AddConnectionScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await widgets.tap(find.text('open'));
    await widgets.pumpAndSettle();
  }

  Future<void> enterKeyAndTest(WidgetTester widgets) async {
    await widgets.enterText(find.byKey(const Key('conn-key')), _key);
    await widgets.tap(find.byKey(const Key('conn-test')));
    await widgets.pumpAndSettle();
  }

  setUp(() => tester = _FakeTester());

  testWidgets('a checked key lists its models; ticking one and saving stores '
      'the connection and puts the key in the keystore', (widgets) async {
    tester.listResult = const ConnectionOk(
      ['alpha', 'beta'],
      contextWindows: {'beta': 128000},
      toolModels: {'beta'},
    );
    await pump(widgets);

    await enterKeyAndTest(widgets);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);

    await widgets.tap(find.text('beta'));
    await widgets.pump();
    await widgets.tap(find.byKey(const Key('conn-save')));
    await widgets.pumpAndSettle();

    final saved = container.read(userConnectionsProvider).single;
    expect(saved.models.single.modelId, 'beta');
    expect(saved.models.single.contextWindowTokens, 128000);
    expect(saved.models.single.supportsTools, isTrue);
    expect(saved.baseUrl, 'https://openrouter.ai/api/v1');
    expect(secrets.values[UserConnectionStore.secretKeyFor(saved.id)], _key);
    expect(find.byKey(const Key('conn-save')), findsNothing,
        reason: 'the screen closes after saving');
  });

  testWidgets('the key is checked against the chosen provider\'s address',
      (widgets) async {
    await pump(widgets);

    await enterKeyAndTest(widgets);

    expect(tester.listed.single,
        (baseUrl: 'https://openrouter.ai/api/v1', apiKey: _key));
  });

  testWidgets('nothing can be saved before a model is ticked', (widgets) async {
    await pump(widgets);
    await enterKeyAndTest(widgets);

    await widgets.tap(find.byKey(const Key('conn-save')));
    await widgets.pumpAndSettle();

    expect(container.read(userConnectionsProvider), isEmpty);
    expect(find.byKey(const Key('conn-save')), findsOneWidget);
  });

  testWidgets('a rejected key shows why and saves nothing', (widgets) async {
    tester.listResult = const ConnectionFailed(
        'The provider rejected the key. Check that it was copied in full.');
    await pump(widgets);

    await enterKeyAndTest(widgets);

    expect(find.textContaining('rejected the key'), findsOneWidget);
    expect(container.read(userConnectionsProvider), isEmpty);
    expect(secrets.values, isEmpty);
  });

  testWidgets('a provider with no model list takes a typed model, checked '
      'before it can be saved', (widgets) async {
    tester.listResult = const ConnectionNoModelList();
    await pump(widgets);
    await enterKeyAndTest(widgets);

    await widgets.enterText(
        find.byKey(const Key('conn-model-id')), 'typed-model');
    await widgets.tap(find.byKey(const Key('conn-check-model')));
    await widgets.pumpAndSettle();
    expect(tester.probed, ['typed-model']);

    await widgets.tap(find.byKey(const Key('conn-save')));
    await widgets.pumpAndSettle();

    expect(
      container.read(userConnectionsProvider).single.models.single.modelId,
      'typed-model',
    );
  });

  testWidgets('the key is hidden as it is typed', (widgets) async {
    await pump(widgets);

    final field = widgets.widget<TextField>(find.byKey(const Key('conn-key')));
    expect(field.obscureText, isTrue);
  });

  testWidgets('the name the student gives is the name on the model',
      (widgets) async {
    await pump(widgets);
    await widgets.enterText(find.byKey(const Key('conn-name')), 'Study AI');
    await enterKeyAndTest(widgets);
    await widgets.tap(find.text('alpha'));
    await widgets.pump();
    await widgets.tap(find.byKey(const Key('conn-save')));
    await widgets.pumpAndSettle();

    expect(
      container.read(modelCatalogueProvider).last.displayName,
      'Study AI · alpha',
    );
  });
}
