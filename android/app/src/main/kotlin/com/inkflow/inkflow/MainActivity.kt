package com.inkflow.inkflow

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Free-space check used before downloading the on-device LLM (~2.4 GB).
    // Reports the available bytes on the volume backing the app's files dir —
    // the same volume flutter_gemma installs models to.
    private val storageChannel = "com.inkflow.inkflow/storage"

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
    }
}
