// Verifying a downloaded model against the SHA-256 the spec pins.
//
// The URLs pin a repo commit, so a re-upload under the same filename cannot
// change what is fetched; the checksum catches a corrupt or tampered transfer.
// Hashing a 2.4 GB file runs in an isolate so the UI does not stall.

import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' show sha256;

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
