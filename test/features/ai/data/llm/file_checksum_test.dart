import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/ai/data/embeddings/embedder_spec.dart';
import 'package:margo/features/ai/data/llm/file_checksum.dart';
import 'package:margo/features/ai/data/llm/llm_exceptions.dart';
import 'package:margo/features/ai/data/llm/llm_model_spec.dart';

void main() {
  late File file;
  late String digest;

  setUp(() {
    file = File('${Directory.systemTemp.createTempSync().path}/m.bin')
      ..writeAsStringSync('model bytes');
    digest = sha256.convert(utf8.encode('model bytes')).toString();
  });

  test('a matching checksum passes, in any letter case', () async {
    await verifySha256(path: file.path, expected: digest, name: 'M');
    await verifySha256(path: file.path, expected: digest.toUpperCase(), name: 'M');
  });

  test('a different file fails with a download error', () async {
    await expectLater(
        verifySha256(path: file.path, expected: 'ab' * 32, name: 'M'),
        throwsA(isA<ModelDownloadException>()));
  });

  test('shipped models are pinned to a commit and carry checksums', () {
    expect(LlmModelSpec.active.downloadUrl, isNot(contains('/resolve/main/')));
    expect(LlmModelSpec.active.sha256, hasLength(64));
    for (final e in EmbedderSpec.all) {
      expect(e.modelUrl, isNot(contains('/resolve/main/')));
      expect(e.modelSha256, hasLength(64));
      if (e.tokenizerUrl == null) continue;
      expect(e.tokenizerUrl, isNot(contains('/resolve/main/')));
      expect(e.tokenizerSha256, hasLength(64));
    }
  });
}
