// Where a secret (the HuggingFace token) is kept: the platform keystore, not
// SharedPreferences, which is a plain XML file any backup or root tool can read.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecretStore {
  Future<String?> read(String key);

  /// Stores [value], or removes [key] when it is empty. False if it could not.
  Future<bool> write(String key, String value);
}

class KeystoreSecretStore implements SecretStore {
  const KeystoreSecretStore();

  static const _storage = FlutterSecureStorage();

  // A keystore that cannot be reached (unsupported platform, tests, a corrupted
  // Android keystore) reads as "no secret": the user pastes the token again.
  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('secure storage unavailable: $e');
      return null;
    }
  }

  @override
  Future<bool> write(String key, String value) async {
    try {
      if (value.isEmpty) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
      return true;
    } catch (e) {
      debugPrint('secure storage unavailable: $e');
      return false;
    }
  }
}

class InMemorySecretStore implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<bool> write(String key, String value) async {
    value.isEmpty ? values.remove(key) : values[key] = value;
    return true;
  }
}
