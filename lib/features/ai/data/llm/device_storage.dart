// Free-disk-space query backed by a small StatFs MethodChannel in
// MainActivity.kt (Android-only app).

import 'package:flutter/services.dart';

class DeviceStorage {
  static const MethodChannel _channel =
      MethodChannel('com.inkflow.inkflow/storage');

  /// Available bytes on the volume backing the app's files directory — the
  /// same volume model files are installed to. Returns 0 when the platform
  /// call fails, which makes callers treat storage as insufficient rather
  /// than start a doomed multi-GB download.
  Future<int> freeBytes() async {
    try {
      final value = await _channel.invokeMethod<int>('getFreeBytes');
      return value ?? 0;
    } on PlatformException {
      return 0;
    }
  }
}
