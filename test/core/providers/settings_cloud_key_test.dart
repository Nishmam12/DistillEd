// The user's own cloud AI key: keystore only, and cloud is off without it.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/core/providers/settings_provider.dart';

const _key = 'ai.cloudApiKey';
const _url = 'https://openrouter.ai/api/v1';

late InMemorySecretStore store;

/// The notifier restores asynchronously from its constructor; wait for it.
Future<SettingsNotifier> restoredNotifier([SecretStore? secrets]) async {
  final notifier = SettingsNotifier(secrets: secrets ?? store);
  while (!notifier.state.loaded) {
    await Future<void>.delayed(Duration.zero);
  }
  return notifier;
}

/// A store whose cloud key read returns the value as it was when the read
/// began, but only once [gate] completes: a slow keystore answering with the
/// old key. Other reads answer at once.
class _SlowStore extends InMemorySecretStore {
  final gate = Completer<void>();

  @override
  Future<String?> read(String key) async {
    final value = values[key];
    if (key == _key) await gate.future;
    return value;
  }
}

Future<SettingsNotifier> withProvider() async {
  final notifier = await restoredNotifier();
  await notifier.setCloudProvider(
    presetId: 'openrouter',
    baseUrl: _url,
    model: 'some/model',
  );
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = InMemorySecretStore();
  });

  test('there is no cloud key by default', () async {
    final s = (await restoredNotifier()).state;
    expect(s.cloudApiKey, '');
    expect(s.cloudPresetId, '');
    expect(s.cloudBaseUrl, '');
    expect(s.cloudModel, '');
    expect(s.cloudContextTokens, 0);
    expect(s.hasCloudKey, isFalse);
  });

  test('the key goes to the keystore and never to prefs', () async {
    final notifier = await withProvider();
    expect(await notifier.setCloudApiKey('sk-test-123'), isTrue);

    expect(notifier.state.cloudApiKey, 'sk-test-123');
    expect(store.values[_key], 'sk-test-123');
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys()) {
      expect(prefs.get(k).toString(), isNot(contains('sk-test-123')));
    }
  });

  test('a stored key survives a restart with its base URL and model',
      () async {
    SharedPreferences.setMockInitialValues({
      'ai.mode': 'auto',
      'ai.cloudPresetId': 'openrouter',
      'ai.cloudBaseUrl': _url,
      'ai.cloudModel': 'some/model',
      'ai.cloudContextTokens': 128000,
    });
    store.values[_key] = 'sk-persisted';

    final s = (await restoredNotifier()).state;
    expect(s.cloudApiKey, 'sk-persisted');
    expect(s.cloudPresetId, 'openrouter');
    expect(s.cloudBaseUrl, _url);
    expect(s.cloudModel, 'some/model');
    expect(s.cloudContextTokens, 128000);
    expect(s.hasCloudKey, isTrue);
    expect(s.cloudAiEnabled, isTrue);
  });

  test('a key without a base URL or model is not enough', () async {
    final notifier = await restoredNotifier();
    await notifier.setAiMode(AiProcessingMode.auto);
    await notifier.setCloudApiKey('sk-test-123');
    expect(notifier.state.hasCloudKey, isFalse);
    expect(notifier.state.cloudAiEnabled, isFalse);

    await notifier.setCloudProvider(
        presetId: 'openrouter', baseUrl: _url, model: '  ');
    expect(notifier.state.cloudAiEnabled, isFalse);

    await notifier.setCloudProvider(
        presetId: 'openrouter', baseUrl: '', model: 'some/model');
    expect(notifier.state.cloudAiEnabled, isFalse);
  });

  test('onDevice with a key keeps the cloud off', () async {
    final notifier = await withProvider();
    await notifier.setCloudApiKey('sk-test-123');
    await notifier.setAiMode(AiProcessingMode.onDevice);
    expect(notifier.state.hasCloudKey, isTrue);
    expect(notifier.state.cloudAiEnabled, isFalse);
    expect(notifier.state.prefersCloud, isFalse);
  });

  test('cloudFirst only prefers the cloud once a key is saved', () async {
    final notifier = await withProvider();
    await notifier.setAiMode(AiProcessingMode.cloudFirst);
    expect(notifier.state.prefersCloud, isFalse);

    await notifier.setCloudApiKey('sk-test-123');
    expect(notifier.state.prefersCloud, isTrue);

    await notifier.setAiMode(AiProcessingMode.auto);
    expect(notifier.state.prefersCloud, isFalse);
  });

  test('a blank key deletes the keystore entry', () async {
    final notifier = await withProvider();
    await notifier.setCloudApiKey('sk-test-123');
    await notifier.setCloudApiKey('   ');
    expect(notifier.state.cloudApiKey, '');
    expect(notifier.state.hasCloudKey, isFalse);
    expect(store.values.containsKey(_key), isFalse);
  });

  test('a pasted key loses its whitespace and surrounding quotes', () async {
    final notifier = await restoredNotifier();
    await notifier.setCloudApiKey('  "sk-ab\ncd"\n');
    expect(notifier.state.cloudApiKey, 'sk-abcd');
    expect(store.values[_key], 'sk-abcd');
  });

  test('setCloudProvider persists all four prefs and strips trailing slashes',
      () async {
    final notifier = await restoredNotifier();
    await notifier.setCloudProvider(
      presetId: ' custom ',
      baseUrl: ' http://localhost:11434/v1// ',
      model: ' llama3 ',
      contextTokens: 8192,
    );
    expect(notifier.state.cloudPresetId, 'custom');
    expect(notifier.state.cloudBaseUrl, 'http://localhost:11434/v1');
    expect(notifier.state.cloudModel, 'llama3');
    expect(notifier.state.cloudContextTokens, 8192);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ai.cloudPresetId'), 'custom');
    expect(prefs.getString('ai.cloudBaseUrl'), 'http://localhost:11434/v1');
    expect(prefs.getString('ai.cloudModel'), 'llama3');
    expect(prefs.getInt('ai.cloudContextTokens'), 8192);

    // Unknown (0, or a negative) removes the stored window.
    await notifier.setCloudProvider(
        presetId: 'custom', baseUrl: _url, model: 'm', contextTokens: -5);
    expect(notifier.state.cloudContextTokens, 0);
    expect(prefs.containsKey('ai.cloudContextTokens'), isFalse);
  });

  test('loaded waits for the keystore read', () async {
    final slow = _SlowStore()..values[_key] = 'sk-persisted';
    final notifier = SettingsNotifier(secrets: slow);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(notifier.state.loaded, isFalse);
    expect(notifier.state.cloudApiKey, '');

    slow.gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(notifier.state.loaded, isTrue);
    expect(notifier.state.cloudApiKey, 'sk-persisted');
  });

  test('a key cleared while the keystore is being read stays cleared',
      () async {
    final slow = _SlowStore()..values[_key] = 'sk-persisted';
    final notifier = SettingsNotifier(secrets: slow);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await notifier.setCloudApiKey('');
    slow.gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(notifier.state.loaded, isTrue);
    expect(notifier.state.cloudApiKey, '');
    expect(slow.values.containsKey(_key), isFalse);
  });
}
