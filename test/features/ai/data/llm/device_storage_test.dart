import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/ai/data/llm/device_storage.dart';

const _channel = MethodChannel('com.inkflow.inkflow/storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('reports the free bytes the platform gives', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async => 4000000000);

    expect(await DeviceStorage().freeBytes(), 4000000000);
  });

  test('a failed platform call reads as no space, so no download starts',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      throw PlatformException(code: 'STATFS_ERROR');
    });

    expect(await DeviceStorage().freeBytes(), 0);
  });

  test('a build without the channel reads as no space, not an exception',
      () async {
    // No handler registered: the platform side is absent.
    expect(await DeviceStorage().freeBytes(), 0);
  });
}
