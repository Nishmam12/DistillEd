// The device's RAM, thermal state and battery, over a small MethodChannel in
// MainActivity.kt (Android-only app) — the same pattern as `DeviceStorage`.
//
// Everywhere else (iOS, desktop, tests) nothing registers the channel, and the
// answer is the neutral snapshot: nothing is degraded or paused on the strength
// of a reading that could not be made.

import 'package:flutter/services.dart';

import '../../domain/device_state.dart';

class DeviceHealth {
  static const MethodChannel _channel =
      MethodChannel('com.inkflow.inkflow/device');

  /// One round trip for everything, so a poll while a bulk job runs costs a
  /// single platform call.
  Future<DeviceSnapshot> read() async {
    try {
      return DeviceSnapshot.fromMap(
          await _channel.invokeMapMethod<Object?, Object?>('snapshot'));
    } on PlatformException {
      return const DeviceSnapshot();
    } on MissingPluginException {
      return const DeviceSnapshot();
    }
  }
}
