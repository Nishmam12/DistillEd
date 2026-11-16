import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/features/ai/data/catalog/user_connection_store.dart';
import 'package:margo/features/ai/domain/catalog/user_connection.dart';

const _key = 'sk-test-1234567890abcdef';

const _connection = UserConnection(
  id: 'c1',
  label: 'My Groq',
  presetId: 'groq',
  baseUrl: 'https://api.groq.com/openai/v1',
  models: [UserModel(modelId: 'm', displayName: 'M')],
);

/// A keystore that cannot be written, as on a device with a broken keystore.
class _RefusingSecretStore implements SecretStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<bool> write(String key, String value) async => false;
}

void main() {
  late InMemorySecretStore secrets;
  late UserConnectionStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secrets = InMemorySecretStore();
    store = UserConnectionStore(secrets: secrets);
  });

  test('a saved connection is there on the next load', () async {
    expect(await store.save(_connection, apiKey: _key), isTrue);

    final loaded = await UserConnectionStore(secrets: secrets).load();
    expect(loaded.single.label, 'My Groq');
  });

  test('the key is kept in the keystore and can be read back', () async {
    await store.save(_connection, apiKey: _key);

    expect(await store.keyFor('c1'), _key);
    expect(secrets.values[UserConnectionStore.secretKeyFor('c1')], _key);
  });

  test('the key is never written to preferences', () async {
    await store.save(_connection, apiKey: _key);

    final prefs = await SharedPreferences.getInstance();
    for (final name in prefs.getKeys()) {
      expect('${prefs.get(name)}', isNot(contains(_key)), reason: name);
    }
  });

  test('saving again with no key keeps the key already stored', () async {
    await store.save(_connection, apiKey: _key);
    await store.save(_connection.copyWith(label: 'Renamed'));

    expect(await store.keyFor('c1'), _key);
    expect((await store.load()).single.label, 'Renamed');
  });

  test('saving an existing connection replaces it, not adds a second', () async {
    await store.save(_connection, apiKey: _key);
    await store.save(_connection.copyWith(label: 'Renamed'));

    expect(await store.load(), hasLength(1));
  });

  test('a connection is not saved when its key cannot be stored', () async {
    final refusing = UserConnectionStore(secrets: _RefusingSecretStore());

    expect(await refusing.save(_connection, apiKey: _key), isFalse);
    expect(await refusing.load(), isEmpty);
  });

  test('a new connection with no key is refused', () async {
    expect(await store.save(_connection), isFalse);
    expect(await store.load(), isEmpty);
  });

  test('deleting a connection deletes its key with it', () async {
    await store.save(_connection, apiKey: _key);

    await store.delete('c1');

    expect(await store.load(), isEmpty);
    expect(await store.keyFor('c1'), isNull);
    expect(secrets.values, isEmpty);
  });

  test('deleting one connection leaves the others', () async {
    await store.save(_connection, apiKey: _key);
    await store.save(
      _connection.copyWith(id: 'c2', label: 'Other'),
      apiKey: 'sk-other-000000000000000000',
    );

    await store.delete('c1');

    expect((await store.load()).single.id, 'c2');
    expect(await store.keyFor('c2'), 'sk-other-000000000000000000');
  });
}
