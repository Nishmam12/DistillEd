import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/domain/catalog/ai_model_entry.dart';
import 'package:margo/features/ai/presentation/ai_providers.dart';
import 'package:margo/features/ai/presentation/widgets/cloud_send_dialog.dart';

const _mine = AiModelEntry(
  id: 'user:c1:big',
  displayName: 'My AI · Big',
  source: ModelSource.userKey,
  contextWindowTokens: 32000,
  host: 'api.example.com',
);

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    showCloudSendPrompts(context, ref);
    return const Scaffold(body: Text('the page'));
  }
}

void main() {
  late ProviderContainer container;

  Future<void> pumpHost(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: [
      secretStoreProvider.overrideWithValue(InMemorySecretStore()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: _Host()),
    ));
    await tester.pump(const Duration(milliseconds: 30));
  }

  testWidgets('a pending send shows the model and where the text will go',
      (tester) async {
    await pumpHost(tester);

    final answer =
        container.read(cloudSendGateProvider.notifier).confirm(_mine);
    await tester.pumpAndSettle();

    expect(find.textContaining('My AI · Big'), findsWidgets);
    expect(find.textContaining('api.example.com'), findsOneWidget);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(await answer, isTrue);
    expect(find.text('Send'), findsNothing);
  });

  testWidgets('"Not now" sends nothing', (tester) async {
    await pumpHost(tester);

    final answer =
        container.read(cloudSendGateProvider.notifier).confirm(_mine);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(await answer, isFalse);
  });

  testWidgets('tapping outside the question counts as no', (tester) async {
    await pumpHost(tester);

    final answer =
        container.read(cloudSendGateProvider.notifier).confirm(_mine);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(await answer, isFalse);
  });

  testWidgets('the first cloud call ever explains what leaves the device',
      (tester) async {
    await pumpHost(tester);
    expect(container.read(settingsProvider).hasSeenFirstCloudCall, isFalse);

    final answer =
        container.read(cloudSendGateProvider.notifier).confirm(_mine);
    await tester.pumpAndSettle();

    expect(find.textContaining('leaves this device'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await answer;
  });
}
