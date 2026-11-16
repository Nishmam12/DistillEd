// Where the student's own cloud connections are kept.
//
// Two places, on purpose. What a connection IS (its name, address, models) is
// ordinary preferences. Its KEY goes to the platform keystore and nowhere else:
// preferences are a plain XML file a backup or a root tool can read.

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/secret_store.dart';
import '../../domain/catalog/user_connection.dart';

class UserConnectionStore {
  final SecretStore _secrets;

  const UserConnectionStore({required this._secrets});

  static const _kConnections = 'ai.userConnections';

  /// The keystore name a connection's key is stored under.
  static String secretKeyFor(String connectionId) =>
      'ai.userKey.$connectionId';

  Future<List<UserConnection>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return decodeConnections(prefs.getString(_kConnections));
  }

  /// Saves [connection], adding it or replacing the one with the same id.
  ///
  /// [apiKey] is stored when given and left alone when null, so a rename does
  /// not need the key again. False, with nothing saved, when the key could not
  /// be stored or a new connection came with none: a connection without a key
  /// can do nothing but fail.
  Future<bool> save(UserConnection connection, {String? apiKey}) async {
    final key = apiKey?.trim();
    if (key != null && key.isNotEmpty) {
      if (!await _secrets.write(secretKeyFor(connection.id), key)) return false;
    } else if (await keyFor(connection.id) == null) {
      return false;
    }

    final connections = await load();
    final index = connections.indexWhere((c) => c.id == connection.id);
    final next = [...connections];
    index < 0 ? next.add(connection) : next[index] = connection;
    await _write(next);
    return true;
  }

  /// Removes the connection and its key together.
  Future<void> delete(String connectionId) async {
    await _secrets.write(secretKeyFor(connectionId), '');
    final connections = await load();
    await _write([
      for (final c in connections)
        if (c.id != connectionId) c,
    ]);
  }

  /// The key for [connectionId], or null when there is none.
  Future<String?> keyFor(String connectionId) async {
    final key = await _secrets.read(secretKeyFor(connectionId));
    return key == null || key.isEmpty ? null : key;
  }

  Future<void> _write(List<UserConnection> connections) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConnections, encodeConnections(connections));
  }
}
