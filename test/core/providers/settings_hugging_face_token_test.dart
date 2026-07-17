import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inkflow/core/providers/settings_provider.dart';

const _key = 'ai.huggingFaceToken';

/// The notifier restores from SharedPreferences asynchronously in its
/// constructor; give that a turn of the loop before asserting.
Future<SettingsNotifier> restoredNotifier() async {
  final notifier = SettingsNotifier();
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('there is no token by default, so gated models stay unavailable',
      () async {
    final notifier = await restoredNotifier();
    expect(notifier.state.huggingFaceToken, '');
    expect(notifier.state.hasHuggingFaceToken, isFalse);
  });

  test('a token is trimmed before it is stored', () async {
    final notifier = await restoredNotifier();
    // Tokens pasted from a browser routinely carry whitespace; a stray space
    // would 401 confusingly.
    await notifier.setHuggingFaceToken('  hf_abc123\n');

    expect(notifier.state.huggingFaceToken, 'hf_abc123');
    expect(notifier.state.hasHuggingFaceToken, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_key), 'hf_abc123');
  });

  test('a stored token survives a restart', () async {
    SharedPreferences.setMockInitialValues({_key: 'hf_persisted'});

    final notifier = await restoredNotifier();
    expect(notifier.state.huggingFaceToken, 'hf_persisted');
    expect(notifier.state.hasHuggingFaceToken, isTrue);
  });

  test('a blank token removes the stored one', () async {
    SharedPreferences.setMockInitialValues({_key: 'hf_old'});
    final notifier = await restoredNotifier();

    await notifier.setHuggingFaceToken('   ');

    expect(notifier.state.hasHuggingFaceToken, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_key), isNull,
        reason: 'clearing must delete the key, not store an empty string');
  });

  test('setting a token leaves the other AI settings alone', () async {
    SharedPreferences.setMockInitialValues({
      'ai.cloudEnabled': true,
      'ai.recognitionLanguage': 'bn',
    });
    final notifier = await restoredNotifier();

    await notifier.setHuggingFaceToken('hf_abc');

    expect(notifier.state.cloudAiEnabled, isTrue);
    expect(notifier.state.recognitionLanguage, 'bn');
  });
}
