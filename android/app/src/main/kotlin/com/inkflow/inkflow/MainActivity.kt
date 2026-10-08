package com.inkflow.inkflow

import android.app.ActivityManager
import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Free-space check used before downloading the on-device LLM (~2.4 GB).
    // Reports the available bytes on the volume backing the app's files dir —
    // the same volume flutter_edge_ai installs models to.
    private val storageChannel = "com.inkflow.inkflow/storage"

    // RAM, thermal state and battery — what the AI pipeline needs to pick a
    // profile for this device and to pause background indexing when it is hot
    // or low on power. One call returns all of it, so polling while a bulk job
    // runs costs a single platform round trip.
    private val deviceChannel = "com.inkflow.inkflow/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getFreeBytes" -> {
                        try {
                            result.success(StatFs(filesDir.path).availableBytes)
                        } catch (e: Exception) {
                            result.error("STATFS_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "snapshot" -> {
                        try {
                            result.success(deviceSnapshot())
                        } catch (e: Exception) {
                            result.error("DEVICE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun deviceSnapshot(): Map<String, Any?> {
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        val battery = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val memory = ActivityManager.MemoryInfo()
        (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager)
            .getMemoryInfo(memory)

        // 0 = none/unknown, 2 = moderate, up to 6 = shutdown. Needs API 29.
        val thermalStatus =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) power.currentThermalStatus
            else 0

        // A forecast, ten seconds ahead, of how close the device is to
        // throttling (1.0 = severe). API 30; NaN when the device cannot say.
        val thermalHeadroom: Double? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val headroom = power.getThermalHeadroom(10)
                if (headroom.isNaN()) null else headroom.toDouble()
            } else null

        return mapOf(
            "totalRamBytes" to memory.totalMem,
            "thermalStatus" to thermalStatus,
            "thermalHeadroom" to thermalHeadroom,
            // Integer.MIN_VALUE when it cannot be read; the Dart side treats
            // anything outside 0–100 as unknown.
            "batteryPercent" to
                battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY),
            "charging" to battery.isCharging,
            "powerSave" to power.isPowerSaveMode,
        )
    }
}
