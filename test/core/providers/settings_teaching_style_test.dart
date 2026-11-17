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

  test('with nothing stored the tutor explains, as it always has', () async {
    final notifier = await restoredNotifier();
    expect(notifier.state.teachingStyle, TeachingStyle.explain);
  });

  test('"guide me" is still chosen after a restart', () async {
    final notifier = await restoredNotifier();
    await notifier.setTeachingStyle(TeachingStyle.guide);
    expect(notifier.state.teachingStyle, TeachingStyle.guide);

    final afterRestart = await restoredNotifier();
    expect(afterRestart.state.teachingStyle, TeachingStyle.guide);
  });

  test('it is stored by name under ai.teachingStyle', () async {
    final notifier = await restoredNotifier();
    await notifier.setTeachingStyle(TeachingStyle.guide);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ai.teachingStyle'), 'guide');
  });

  test('a value this build does not know falls back to explain', () async {
    SharedPreferences.setMockInitialValues({'ai.teachingStyle': 'socratic'});
    final notifier = await restoredNotifier();
    expect(notifier.state.teachingStyle, TeachingStyle.explain);
  });

  test('choosing a style changes nothing about where the AI runs', () async {
    final notifier = await restoredNotifier();
    await notifier.setAnswerModelId('user:c1:big');

    await notifier.setTeachingStyle(TeachingStyle.guide);

    expect(notifier.state.answerModelId, 'user:c1:big');
    expect(notifier.state.aiMode, AiProcessingMode.onDevice);
    expect(notifier.state.cloudPrivacy, CloudPrivacy.askEachTime);
  });
}
