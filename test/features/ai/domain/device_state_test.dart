// What the device can take: which AI profile it gets, and when background AI
// work should wait. The thresholds are the plan's starting points, not
// measurements, so the tests pin the BEHAVIOUR around them — an "8 GB" phone
// must still be "full", a hot one must pause — rather than the exact digits.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/compute_backend.dart';
import 'package:inkflow/features/ai/domain/device_state.dart';

void main() {
  const gb = 1000 * 1000 * 1000;

  group('chooseProfile', () {
    test('an "8 GB" phone is full — it reports a little under 8', () {
      // Reporting 7.4 GB is what an 8 GB phone does; setting the bar AT 8 would
      // put every one of them in the lite tier.
      expect(chooseProfile(totalRamBytes: (7.4 * gb).round()), AiProfile.full);
      expect(chooseProfile(totalRamBytes: 12 * gb), AiProfile.full);
    });

    test('a 6 GB phone is lite', () {
      expect(chooseProfile(totalRamBytes: (5.6 * gb).round()), AiProfile.lite);
    });

    test('a 4 GB phone leans on the cloud', () {
      expect(chooseProfile(totalRamBytes: (3.6 * gb).round()),
          AiProfile.cloudAssisted);
    });

    test('plenty of RAM but no GPU is lite — the GPU is half the plan\'s test',
        () {
      expect(
        chooseProfile(totalRamBytes: 8 * gb, backend: ComputeBackend.cpu),
        AiProfile.lite,
      );
      expect(
        chooseProfile(totalRamBytes: 8 * gb, backend: ComputeBackend.gpu),
        AiProfile.full,
      );
    });

    test('a GPU that has not been tried yet does not count against the device',
        () {
      expect(chooseProfile(totalRamBytes: 8 * gb), AiProfile.full);
    });

    test('an unreadable amount of RAM is not a reason to degrade anyone', () {
      expect(chooseProfile(totalRamBytes: null), AiProfile.full);
    });

    test('the backend only ever lowers a profile, never raises it', () {
      expect(
        chooseProfile(totalRamBytes: (3.6 * gb).round(), backend: ComputeBackend.gpu),
        AiProfile.cloudAssisted,
      );
    });
  });

  group('backgroundPauseReason', () {
    test('a cool, charged device runs background work', () {
      expect(backgroundPauseReason(const DeviceSnapshot()), isNull);
      expect(
        backgroundPauseReason(const DeviceSnapshot(
            thermalStatus: 1, batteryPercent: 80, thermalHeadroom: 0.4)),
        isNull,
        reason: 'merely warm is fine',
      );
    });

    test('a device that is moderately hot or worse waits', () {
      expect(backgroundPauseReason(const DeviceSnapshot(thermalStatus: 2)),
          PauseReason.hot);
      expect(backgroundPauseReason(const DeviceSnapshot(thermalStatus: 4)),
          PauseReason.hot);
    });

    test('one forecast to throttle soon waits, before it has actually got hot',
        () {
      expect(backgroundPauseReason(const DeviceSnapshot(thermalHeadroom: 0.95)),
          PauseReason.hot);
    });

    test('a low battery waits — unless it is charging', () {
      expect(
        backgroundPauseReason(const DeviceSnapshot(batteryPercent: 12)),
        PauseReason.lowBattery,
      );
      expect(
        backgroundPauseReason(
            const DeviceSnapshot(batteryPercent: 12, charging: true)),
        isNull,
      );
    });

    test('battery saver waits: the user asked the phone to do less', () {
      expect(backgroundPauseReason(const DeviceSnapshot(powerSave: true)),
          PauseReason.lowBattery);
    });

    test('heat outranks battery when both apply', () {
      expect(
        backgroundPauseReason(
            const DeviceSnapshot(thermalStatus: 3, batteryPercent: 5)),
        PauseReason.hot,
      );
    });
  });

  group('DeviceSnapshot.fromMap', () {
    test('reads what the platform sent', () {
      final s = DeviceSnapshot.fromMap({
        'totalRamBytes': 7400000000,
        'thermalStatus': 2,
        'thermalHeadroom': 0.7,
        'batteryPercent': 55,
        'charging': true,
        'powerSave': false,
      });

      expect(s.totalRamBytes, 7400000000);
      expect(s.thermalStatus, 2);
      expect(s.thermalHeadroom, 0.7);
      expect(s.batteryPercent, 55);
      expect(s.charging, isTrue);
      expect(s.powerSave, isFalse);
    });

    test('a missing or oddly-typed field is "unknown", never an exception', () {
      final s = DeviceSnapshot.fromMap({
        'totalRamBytes': 'lots',
        'thermalStatus': null,
        'batteryPercent': 55.0, // a double where an int was expected
      });

      expect(s.totalRamBytes, isNull);
      expect(s.thermalStatus, 0);
      expect(s.thermalHeadroom, isNull);
      expect(s.batteryPercent, 55);
      expect(s.charging, isFalse);
    });

    test('a battery level outside 0–100 is unknown, not "empty"', () {
      // Android reports Integer.MIN_VALUE when it cannot read the battery. Taken
      // at face value that is a -2 billion percent charge: background work
      // paused for ever on a device whose battery is fine.
      final s = DeviceSnapshot.fromMap({'batteryPercent': -2147483648});

      expect(s.batteryPercent, isNull);
      expect(backgroundPauseReason(s), isNull);
      expect(DeviceSnapshot.fromMap({'batteryPercent': 250}).batteryPercent,
          isNull);
      expect(DeviceSnapshot.fromMap({'batteryPercent': 0}).batteryPercent, 0);
      expect(DeviceSnapshot.fromMap({'batteryPercent': 100}).batteryPercent,
          100);
    });

    test('no map at all is the neutral snapshot', () {
      final s = DeviceSnapshot.fromMap(null);
      expect(backgroundPauseReason(s), isNull);
      expect(chooseProfile(totalRamBytes: s.totalRamBytes), AiProfile.full);
    });
  });
}
