// What the device can take: which AI profile it gets, and when background AI
// work should wait (docs/AI_PIPELINE_PLAN.md, item 13).
//
// A phone that benchmarks fine in a two-second burst throttles hard after ten
// minutes of indexing, and a 4 GB phone cannot hold a 2.6 GB model at all. So
// the app reads the device's total RAM, whether the GPU backend actually loaded,
// the thermal state and the battery, and adapts instead of assuming a flagship.
//
// Pure — the platform read is `data/device/device_health.dart` — so the
// decisions are tested without a device. Every threshold here is the plan's
// STARTING POINT, not a measurement.

import 'compute_backend.dart';

/// How much of the on-device pipeline this device is given.
enum AiProfile {
  /// The whole thing: full context, optional figure passes, GPU.
  full,

  /// Smaller context and no optional passes — enough RAM for the model, not
  /// enough to be generous with it, or no GPU to run it on.
  lite,

  /// Too little RAM to lean on the local model: for a user who has opted in, the
  /// cloud is the better first choice. (Without the opt-in this behaves as
  /// [lite] — never silently off the device.)
  cloudAssisted,
}

/// Why background AI work should wait.
enum PauseReason { hot, lowBattery }

/// A reading of the device's state. Every field is best-effort: a platform that
/// cannot say leaves it at its neutral value, which never degrades anything.
class DeviceSnapshot {
  /// Total RAM as the OS reports it — an "8 GB" phone reports a little under 8.
  final int? totalRamBytes;

  /// Android's `PowerManager.THERMAL_STATUS_*`: 0 none … 2 moderate … 6
  /// shutdown. 0 also means "not reported".
  final int thermalStatus;

  /// Android's forecast of how close the device is to throttling: 1.0 is the
  /// point of severe throttling. Null when the device does not report it.
  final double? thermalHeadroom;

  final int? batteryPercent;
  final bool charging;

  /// Battery saver is on — the user has asked the phone to do less.
  final bool powerSave;

  const DeviceSnapshot({
    this.totalRamBytes,
    this.thermalStatus = 0,
    this.thermalHeadroom,
    this.batteryPercent,
    this.charging = false,
    this.powerSave = false,
  });

  /// Reads the map the platform channel sends, tolerating anything missing or
  /// mistyped: a snapshot that cannot be read is the neutral one, not an error.
  factory DeviceSnapshot.fromMap(Map<Object?, Object?>? map) {
    if (map == null) return const DeviceSnapshot();
    int? intOf(Object? v) => v is num ? v.toInt() : null;
    final headroom = map['thermalHeadroom'];
    // Android answers Integer.MIN_VALUE when it cannot read the battery; a level
    // outside 0–100 is "unknown", not a battery that is -2 billion percent full.
    final battery = intOf(map['batteryPercent']);
    return DeviceSnapshot(
      totalRamBytes: intOf(map['totalRamBytes']),
      thermalStatus: intOf(map['thermalStatus']) ?? 0,
      thermalHeadroom:
          headroom is num && !headroom.isNaN ? headroom.toDouble() : null,
      batteryPercent: battery != null && battery >= 0 && battery <= 100
          ? battery
          : null,
      charging: map['charging'] == true,
      powerSave: map['powerSave'] == true,
    );
  }
}

/// RAM below this is [AiProfile.lite]; the plan's "about 7 GB or more". An "8 GB"
/// phone reports ~7.4, so the bar is NOT 8.
const int kFullProfileMinRamBytes = 7 * 1000 * 1000 * 1000;

/// RAM below this is [AiProfile.cloudAssisted].
const int kLiteProfileMinRamBytes = 5 * 1000 * 1000 * 1000;

/// The profile for a device with [totalRamBytes] whose model has run on
/// [backend] (null until it has loaded once).
///
/// RAM sets the tier; the backend can only LOWER it — plenty of RAM and no GPU
/// is [AiProfile.lite], but a GPU never rescues a device that is short of RAM.
/// An unreadable amount of RAM is not a reason to degrade anyone.
AiProfile chooseProfile({
  required int? totalRamBytes,
  ComputeBackend? backend,
}) {
  var profile = AiProfile.full;
  if (totalRamBytes != null) {
    if (totalRamBytes < kLiteProfileMinRamBytes) {
      profile = AiProfile.cloudAssisted;
    } else if (totalRamBytes < kFullProfileMinRamBytes) {
      profile = AiProfile.lite;
    }
  }
  if (backend == ComputeBackend.cpu && profile == AiProfile.full) {
    profile = AiProfile.lite;
  }
  return profile;
}

/// Android's thermal status from which background work waits: moderate, where
/// the system itself starts to throttle.
const int kPauseAtThermalStatus = 2;

/// Forecast headroom from which background work waits — close to throttling,
/// before it has actually got hot.
const double kPauseAtThermalHeadroom = 0.9;

/// Battery percentage at or below which background work waits, unless charging.
const int kPauseAtBatteryPercent = 15;

/// Why background AI work should wait right now, or null when it may run.
///
/// Heat is checked first: a hot device that is also low on battery is better
/// described by the thing that will clear up on its own in a few minutes.
PauseReason? backgroundPauseReason(DeviceSnapshot s) {
  final headroom = s.thermalHeadroom;
  if (s.thermalStatus >= kPauseAtThermalStatus ||
      (headroom != null && headroom >= kPauseAtThermalHeadroom)) {
    return PauseReason.hot;
  }
  if (s.powerSave ||
      (!s.charging && (s.batteryPercent ?? 100) <= kPauseAtBatteryPercent)) {
    return PauseReason.lowBattery;
  }
  return null;
}
