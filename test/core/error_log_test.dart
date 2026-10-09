import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/core/error_log.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

void _documentsAt(String path) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathChannel, (call) async => path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('error_log_test_');
    _documentsAt(dir.path);
  });

  tearDown(() async {
    _documentsAt('');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathChannel, null);
    await dir.delete(recursive: true);
  });

  File logFile() => File('${dir.path}/error_log.txt');

  test('an error is appended with its message and a separator', () async {
    await ErrorLog.record(StateError('boom'), StackTrace.current);

    final text = await logFile().readAsString();
    expect(text, contains('Bad state: boom'));
    expect(text, contains('----'));
  });

  test('entries accumulate in the order they happened', () async {
    await ErrorLog.record(Exception('first'), null);
    await ErrorLog.record(Exception('second'), null);

    final text = await logFile().readAsString();
    expect(text.indexOf('first'), lessThan(text.indexOf('second')));
  });

  test('once past 100 KB the older half is dropped, and the newest is kept',
      () async {
    final padding = 'x' * 200;
    for (var i = 0; i < 1000; i++) {
      await ErrorLog.record(Exception('old $i $padding'), null);
    }
    await ErrorLog.record(Exception('newest entry'), null);

    final text = await logFile().readAsString();
    expect(text, contains('newest entry'));
    expect(text, isNot(contains('old 0 ')));
    expect(await logFile().length(), lessThan(110 * 1024));
  });

  test('a log that cannot be written never throws into the caller', () async {
    _documentsAt('${dir.path}/no/such/folder');

    await expectLater(
      ErrorLog.record(Exception('lost'), null),
      completes,
    );
  });

  test('existing() is null until something has been logged', () async {
    expect(await ErrorLog.existing(), isNull);

    await ErrorLog.record(Exception('one'), null);

    expect((await ErrorLog.existing())?.path, logFile().path);
  });
}
