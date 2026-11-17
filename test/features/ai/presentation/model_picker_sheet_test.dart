// The model picker: where a student chooses who answers. The rule that matters
// most is that picking a cloud model can never quietly switch cloud AI on.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/domain/catalog/user_connection.dart';
import 'package:margo/features/ai/presentation/ai_providers.dart';
import 'package:margo/features/ai/presentation/widgets/model_picker_sheet.dart';

const _connection = UserConnection(
  id: 'c1',
  label: 'My AI',
  presetId: 'custom',
  baseUrl: 'https://api.example.com/v1',
  models: [UserModel(modelId: 'big', displayName: 'Big')],
);

const _bigId = 'user:c1:big';

void main() {
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    bool cloudOn = true,
    String? stored,
    bool withConnection = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: [
      secretStoreProvider.overrideWithValue(InMemorySecretStore()),
    ]);
    addTearDown(container.dispose);
    container.read(settingsProvider);
    container.read(userConnectionsProvider);
    await tester.pump(const Duration(milliseconds: 30));
    if (withConnection) {
      await tester.runAsync(() => container
          .read(userConnectionsProvider.notifier)
          .save(_connection, apiKey: 'sk-test-1234567890abcdef'));
    }
    await tester.runAsync(() async {
      await container.read(settingsProvider.notifier).setCloudAiEnabled(cloudOn);
      if (stored != null) {
        await container.read(settingsProvider.notifier).setAnswerModelId(stored);
      }
    });

    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showModelPicker(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  SettingsState settings() => container.read(settingsProvider);

  testWidgets('offers auto, the on-device model, the student\'s own models and '
      'Margo\'s as coming soon', (tester) async {
    await pump(tester);

    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('On-device (Gemma)'), findsOneWidget);
    expect(find.text('My AI · Big'), findsOneWidget);
    expect(find.text('Margo Free'), findsOneWidget);
    expect(find.textContaining('Coming soon'), findsWidgets);
  });

  testWidgets('picking the on-device model stores that and closes',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('On-device (Gemma)'));
    await tester.pumpAndSettle();

    expect(settings().answerModelId, 'local');
    expect(find.text('On-device (Gemma)'), findsNothing);
  });

  testWidgets('picking one of the student\'s models stores it', (tester) async {
    await pump(tester);

    await tester.tap(find.text('My AI · Big'));
    await tester.pumpAndSettle();

    expect(settings().answerModelId, _bigId);
    expect(settings().aiMode, AiProcessingMode.auto);
  });

  testWidgets('with cloud AI off, picking a cloud model asks before turning it '
      'on, and a yes turns on auto, never cloud-first', (tester) async {
    await pump(tester, cloudOn: false);

    await tester.tap(find.text('My AI · Big'));
    await tester.pumpAndSettle();
    expect(settings().aiMode, AiProcessingMode.onDevice,
        reason: 'nothing changes before the answer');
    expect(settings().answerModelId, 'auto');

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(settings().aiMode, AiProcessingMode.auto);
    expect(settings().answerModelId, _bigId);
  });

  testWidgets('with cloud AI off, a no changes nothing', (tester) async {
    await pump(tester, cloudOn: false);

    await tester.tap(find.text('My AI · Big'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(settings().aiMode, AiProcessingMode.onDevice);
    expect(settings().answerModelId, 'auto');
  });

  testWidgets('a model that is not available yet cannot be picked',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Margo Free'));
    await tester.pumpAndSettle();

    expect(settings().answerModelId, 'auto');
  });

  testWidgets('a stored pick whose model is gone falls back to auto and says so',
      (tester) async {
    await pump(tester, stored: 'user:deleted:model');

    expect(find.textContaining('no longer available'), findsOneWidget);
    expect(settings().answerModelId, 'auto');
  });
}
