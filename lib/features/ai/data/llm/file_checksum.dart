// Verifying a downloaded model against the SHA-256 the spec pins.
//
// The URLs pin a repo commit, so a re-upload under the same filename cannot
// change what is fetched; the checksum catches a corrupt or tampered transfer.
// Hashing a 2.4 GB file runs in an isolate so the UI does not stall.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' show sha256;
import 'package:shared_preferences/shared_preferences.dart';

import 'llm_exceptions.dart';

Future<String> _sha256OfFile(String path) => Isolate.run(
    () async => (await sha256.bind(File(path).openRead()).first).toString());

/// Throws [ModelDownloadException] unless the file at [path] hashes to
/// [expected]. The caller removes the file: it knows how its plugin records it.
Future<void> verifySha256({
  required String path,
  required String expected,
  required String name,
}) async {
  final actual = await _sha256OfFile(path);
  if (actual != expected.toLowerCase()) {
    throw ModelDownloadException(
        '$name did not download correctly (checksum mismatch). Try again.');
  }
}

// ponytail: a marker set before a download and cleared once its checksum passes,
// so a hash cut short by the app dying leaves the model "not installed" instead
// of trusted for good. Models installed before it existed carry none; they are
// hashed once at first use instead (see [ensureVerifiedOnce]).
String _pendingKey(String name) => 'model_verify_pending:$name';

Future<bool> isVerifyPending(String name) async {
  try {
    return (await SharedPreferences.getInstance()).getBool(_pendingKey(name)) ??
        false;
  } catch (_) {
    return false; // storage unavailable: behave as before the marker existed
  }
}

Future<void> setVerifyPending(String name, bool pending) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    pending
        ? await prefs.setBool(_pendingKey(name), true)
        : await prefs.remove(_pendingKey(name));
  } catch (_) {}
}

// Set once a model's checksum has passed, by install or by [ensureVerifiedOnce].
// The pending marker above only covers downloads made since it existed; this
// one lets a model installed before either marker be checked once, at first use.
String _verifiedKey(String name) => 'model_verified:$name';

/// Verified this run, also the fallback when storage is unavailable, so a
/// device without prefs does not re-hash 2.4 GB on every load.
final Set<String> _verifiedThisRun = {};
final Map<String, Future<void>> _verifying = {};

/// Records that [name] passed its checksum.
Future<void> markVerified(String name) async {
  _verifiedThisRun.add(name);
  try {
    await (await SharedPreferences.getInstance())
        .setBool(_verifiedKey(name), true);
  } catch (_) {}
}

/// Hashes the files of model [name] once if it was never verified (installed
/// before the markers existed), then remembers it passed. Cheap after that.
/// On a mismatch it runs [onMismatch] (remove the model) and throws
/// [LlmNotReadyException], so the caller's download offer repairs it.
/// [files] pairs each path with its expected SHA-256; null hashes are skipped.
Future<void> ensureVerifiedOnce({
  required String name,
  required Future<List<(String, String?)>> Function() files,
  required Future<void> Function() onMismatch,
}) async {
  if (_verifiedThisRun.contains(name)) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_verifiedKey(name)) ?? false) {
      _verifiedThisRun.add(name);
      return;
    }
  } catch (_) {}
  // Two loads racing on first use share one hash rather than running two.
  return _verifying[name] ??= () async {
    try {
      for (final (path, expected) in await files()) {
        if (expected == null) continue;
        await verifySha256(path: path, expected: expected, name: name);
      }
      await markVerified(name);
    } on ModelDownloadException {
      await onMismatch();
      throw LlmNotReadyException();
    } finally {
      unawaited(_verifying.remove(name));
    }
  }();
}
