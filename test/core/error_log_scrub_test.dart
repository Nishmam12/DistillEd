// The error log is a file a student shares with a bug report. A key they typed
// into the app must never be in it, whatever error carried it there.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/core/error_log.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  group('scrubSecrets', () {
    test('removes a bearer token, keeping the word that shows one was there',
        () {
      final scrubbed =
          scrubSecrets('headers: {Authorization: Bearer sk-abc123def456ghi789}');

      expect(scrubbed, isNot(contains('sk-abc123def456ghi789')));
      expect(scrubbed, contains('Bearer [removed]'));
    });

    test('removes an sk- style key wherever it appears', () {
      final scrubbed = scrubSecrets(
          'Incorrect API key provided: sk-proj-AbCdEf0123456789_xyz-ABCDEF.');

      expect(scrubbed, isNot(contains('AbCdEf0123456789')));
      expect(scrubbed, contains('[removed]'));
    });

    test('removes a Google style key', () {
      final scrubbed =
          scrubSecrets('key AIzaSyA1b2C3d4E5f6G7h8I9j0KlMnOpQrStUv rejected');

      expect(scrubbed, isNot(contains('AIzaSyA1b2C3d4E5f6G7h8I9j0')));
    });

    test('removes a key passed in an address', () {
      final scrubbed = scrubSecrets(
          'GET https://api.example.com/v1/models?key=abcdef123456&x=1 failed');

      expect(scrubbed, isNot(contains('abcdef123456')));
      expect(scrubbed, contains('key=[removed]'));
      expect(scrubbed, contains('x=1'));
    });

    test('removes a Hugging Face token', () {
      final scrubbed = scrubSecrets('token hf_AbCdEfGhIjKlMnOpQrStUvWxYz rejected');

      expect(scrubbed, isNot(contains('hf_AbCdEfGhIjKlMnOpQrStUvWxYz')));
    });

    test('leaves ordinary error text exactly as it was', () {
      const text = 'Bad state: page 12 has no elements (skipped 3 tasks)';

      expect(scrubSecrets(text), text);
    });

    test('does not mistake short look-alikes for keys', () {
      const text = 'the task sk-1 and the risk-averse disk-check ran';

      expect(scrubSecrets(text), text);
    });
  });

  group('ErrorLog.record', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('error_log_scrub_test_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathChannel, (call) async => dir.path);
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathChannel, null);
      await dir.delete(recursive: true);
    });

    test('a key inside an error never reaches the file', () async {
      const key = 'sk-test-1234567890abcdefXYZ';

      await ErrorLog.record(
        StateError('request failed, Authorization: Bearer $key'),
        StackTrace.fromString('#0 send (file.dart:1) key=$key'),
      );

      final text = await File('${dir.path}/error_log.txt').readAsString();
      expect(text, isNot(contains(key)));
      expect(text, contains('request failed'));
    });
  });
}
