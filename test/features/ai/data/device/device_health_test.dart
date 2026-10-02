import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/device/device_health.dart';
import 'package:inkflow/features/ai/domain/device_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.inkflow.inkflow/device');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('reads the snapshot the Android side sends', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return <String, Object?>{
        'totalRamBytes': 7400000000,
        'thermalStatus': 2,
        'thermalHeadroom': 0.8,
        'batteryPercent': 41,
        'charging': false,
        'powerSave': true,
      };
    });

    final s = await DeviceHealth().read();

    expect(seen!.method, 'snapshot');
    expect(s.totalRamBytes, 7400000000);
    expect(s.thermalStatus, 2);
    expect(s.thermalHeadroom, 0.8);
    expect(s.batteryPercent, 41);
    expect(s.powerSave, isTrue);
  });

  test('a platform with no such channel gets the neutral snapshot', () async {
    // iOS, desktop, and every widget test: nothing registered the channel.
    final s = await DeviceHealth().read();

    expect(backgroundPauseReason(s), isNull);
    expect(s.totalRamBytes, isNull);
  });

  test('a platform error also gets the neutral snapshot, not an exception',
      () async {
    messenger.setMockMethodCallHandler(
        channel, (call) async => throw PlatformException(code: 'BOOM'));

    final s = await DeviceHealth().read();

    expect(s.totalRamBytes, isNull);
    expect(s.thermalStatus, 0);
  });
}
