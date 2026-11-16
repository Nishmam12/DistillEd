// The student's own cloud connections, as the app sees them: loaded once from
// the store, then kept in step with every add, edit and delete.

import 'package:flutter_riverpod/legacy.dart';

import '../data/catalog/user_connection_store.dart';
import '../domain/catalog/user_connection.dart';

class UserConnectionsNotifier extends StateNotifier<List<UserConnection>> {
  final UserConnectionStore _store;

  UserConnectionsNotifier(this._store) : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final connections = await _store.load();
    if (mounted) state = connections;
  }

  /// Adds [connection] or replaces the one with its id. [apiKey] is needed for
  /// a new connection and optional afterwards. False when nothing was saved
  /// (see [UserConnectionStore.save]).
  Future<bool> save(UserConnection connection, {String? apiKey}) async {
    if (!await _store.save(connection, apiKey: apiKey)) return false;
    await _load();
    return true;
  }

  /// Removes the connection and its key.
  Future<void> delete(String connectionId) async {
    await _store.delete(connectionId);
    await _load();
  }

  /// Records that the student has been told where text sent to this connection
  /// goes, so they are not told again.
  Future<void> markConsented(String connectionId) async {
    for (final connection in state) {
      if (connection.id == connectionId && !connection.consentShown) {
        await save(connection.copyWith(consentShown: true));
        return;
      }
    }
  }

  /// The saved key for [connectionId], read when a request is about to be made.
  Future<String?> keyFor(String connectionId) => _store.keyFor(connectionId);
}
