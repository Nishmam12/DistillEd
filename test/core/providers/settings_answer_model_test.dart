import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/core/providers/settings_provider.dart';

Future<SettingsNotifier> restoredNotifier() async {
  final notifier = SettingsNotifier(secrets: InMemorySecretStore());
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('with nothing stored the answer model is auto, as before the picker',
      () async {
    final notifier = await restoredNotifier();
    expect(notifier.state.answerModelId, 'auto');
  });

  test('a picked model is still picked after a restart', () async {
    final notifier = await restoredNotifier();
    await notifier.setAnswerModelId('user:c1:big');
    expect(notifier.state.answerModelId, 'user:c1:big');

    final afterRestart = await restoredNotifier();
    expect(afterRestart.state.answerModelId, 'user:c1:big');
  });

  test('picking a model does not change where pages are read', () async {
    final notifier = await restoredNotifier();
    await notifier.setAiMode(AiProcessingMode.auto);

    await notifier.setAnswerModelId('user:c1:big');

    expect(notifier.state.aiMode, AiProcessingMode.auto);
    expect(notifier.state.aiMode.prefersCloud, isFalse);
  });

  test('switching cloud AI off keeps the pick for when it is back on',
      () async {
    final notifier = await restoredNotifier();
    await notifier.setAnswerModelId('user:c1:big');

    await notifier.setCloudAiEnabled(false);

    expect(notifier.state.answerModelId, 'user:c1:big');
  });
}
