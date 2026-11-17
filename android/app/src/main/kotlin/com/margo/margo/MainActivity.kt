package com.margo.margo

import android.app.ActivityManager
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.StatFs
import android.provider.MediaStore
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Free-space check used before downloading the on-device LLM (~2.4 GB).
    // Reports the available bytes on the volume backing the app's files dir —
    // the same volume flutter_edge_ai installs models to.
    private val storageChannel = "com.margo.margo/storage"

    // RAM, thermal state and battery — what the AI pipeline needs to pick a
    // profile for this device and to pause background indexing when it is hot
    // or low on power. One call returns all of it, so polling while a bulk job
    // runs costs a single platform round trip.
    private val deviceChannel = "com.margo.margo/device"

    // Starts/stops the microphone foreground service that keeps a lecture
    // recording alive in the background (see RecordingService).
    private val recordingChannel = "com.margo.margo/recording"

    // Copies finished backup files into Download/Margo (MediaStore, no
    // permission needed on Android 10+) so they outlive the app. Android 8–9
    // would need a storage permission, so there they stay in the app's own
    // external folder and the Dart side says so.
    private val backupChannel = "com.margo.margo/backup"
    private val backupIo = Executors.newSingleThreadExecutor()
    private val mainThread = Handler(Looper.getMainLooper())

    // "Share to Margo" / "Open with Margo". The intent is held until Dart asks
    // for it ("take"), so a cold start loses nothing; a share that arrives while
    // the app is open is announced with "arrived". Files are copied into the
    // cache because Dart cannot read content:// URIs.
    private val shareChannelName = "com.margo.margo/share"
    private var shareChannel: MethodChannel? = null
    @Volatile private var pendingShare: Intent? = null // set on main, taken on backupIo

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (isShare(intent)) {
            pendingShare = intent
            shareChannel?.invokeMethod("arrived", null)
        }
    }

    private fun isShare(intent: Intent?): Boolean = when (intent?.action) {
        Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE -> true
        Intent.ACTION_VIEW -> intent.data != null
        else -> false
    }

    /** The pending share as {text, files: [{path, mimeType, name}]}, or null. */
    private fun takeShare(): Map<String, Any?>? {
        val intent = pendingShare ?: return null
        pendingShare = null
        val uris = mutableListOf<android.net.Uri>()
        when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let { uris.add(it) }
            Intent.ACTION_SEND -> intentStream(intent)?.let { uris.add(it) }
            Intent.ACTION_SEND_MULTIPLE -> uris.addAll(intentStreams(intent))
        }
        // Each share replaces the last one's copies: the importer has already
        // copied or rendered them into the notebook by then.
        val dir = File(cacheDir, "shared").apply { deleteRecursively(); mkdirs() }
        val files = uris.filter(::isForeignContent).mapIndexedNotNull { i, uri ->
            try {
                val name = displayName(uri) ?: "shared_$i"
                // A folder per file keeps two "image.jpg"s apart and the name
                // intact (the PDF importer shows it as the source).
                val target = File(File(dir, "$i").apply { mkdirs() }, name.replace('/', '_'))
                (contentResolver.openInputStream(uri) ?: return@mapIndexedNotNull null)
                    .use { input -> target.outputStream().use { input.copyTo(it) } }
                mapOf(
                    "path" to target.absolutePath,
                    "mimeType" to (contentResolver.getType(uri) ?: intent.type ?: ""),
                    "name" to name,
                )
            } catch (e: Exception) {
                null // unreadable (revoked grant, deleted file): skip it
            }
        }
        val text = if (intent.action == Intent.ACTION_SEND && uris.isEmpty())
            intent.getStringExtra(Intent.EXTRA_TEXT) else null
        if (files.isEmpty() && text.isNullOrBlank()) return null
        return mapOf(
            "text" to text,
            "subject" to intent.getStringExtra(Intent.EXTRA_SUBJECT),
            "files" to files,
        )
    }

    @Suppress("DEPRECATION")
    private fun intentStream(intent: Intent): android.net.Uri? =
        if (Build.VERSION.SDK_INT >= 33)
            intent.getParcelableExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java)
        else intent.getParcelableExtra(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun intentStreams(intent: Intent): List<android.net.Uri> =
        (if (Build.VERSION.SDK_INT >= 33)
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java)
        else intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)) ?: emptyList()

    /**
     * Only content:// from another app's provider. A file:// URI or one of
     * Margo's own providers would let a sender make Margo copy its private
     * files (database, keys) into a note. Senders can't share file:// since
     * Android 7 anyway.
     */
    private fun isForeignContent(uri: android.net.Uri): Boolean {
        if (uri.scheme != "content") return false
        // Null = a provider package visibility hides from us, so not ours;
        // our own always resolve.
        val owner = packageManager.resolveContentProvider(uri.authority ?: return false, 0)
        return owner?.packageName != packageName
    }

    private fun displayName(uri: android.net.Uri): String? {
        contentResolver.query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) return c.getString(0) }
        return null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (isShare(intent)) pendingShare = intent
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
            .apply {
                setMethodCallHandler { call, result ->
                    if (call.method != "take") return@setMethodCallHandler result.notImplemented()
                    // Copying can take a moment for a big PDF: off the main thread.
                    backupIo.execute {
                        try {
                            val share = takeShare()
                            mainThread.post { result.success(share) }
                        } catch (e: Exception) {
                            mainThread.post { result.error("SHARE_ERROR", e.message, null) }
                        }
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, recordingChannel)
            .setMethodCallHandler { call, result ->
                try {
                    val intent = Intent(this, RecordingService::class.java)
                    when (call.method) {
                        "start" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
                            else startService(intent)
                            result.success(null)
                        }
                        "stop" -> {
                            stopService(intent)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("RECORDING_SERVICE", e.message, null)
                }
            }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannel)
            .setMethodCallHandler { call, result ->
                // File copies can take a moment: off the main thread.
                backupIo.execute {
                    try {
                        val name = call.argument<String>("name") ?: ""
                        if (call.method != "list" && name.isEmpty()) {
                            throw IllegalArgumentException("name")
                        }
                        val reply: Any? = when (call.method) {
                            "list" -> listBackups()
                            "copyOut" -> {
                                copyBackupOut(
                                    name,
                                    call.argument<String>("destPath")
                                        ?: throw IllegalArgumentException("destPath"),
                                )
                                null
                            }
                            "save" -> saveBackup(
                                call.argument<String>("sourcePath")
                                    ?: throw IllegalArgumentException("sourcePath"),
                                name,
                                call.argument<String>("mimeType") ?: "application/octet-stream",
                            )
                            "delete" -> { deleteBackup(name); null }
                            else -> { mainThread.post { result.notImplemented() }; return@execute }
                        }
                        mainThread.post { result.success(reply) }
                    } catch (e: Exception) {
                        mainThread.post { result.error("BACKUP_ERROR", e.message, null) }
                    }
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

    private val backupRelativePath = Environment.DIRECTORY_DOWNLOADS + "/Margo/"

    /** Where backups go before Android 10: the app's own external folder. */
    private fun legacyBackupDir(): File =
        File(getExternalFilesDir(null), "Margo backups").apply { mkdirs() }

    /** The Download/Margo file this app wrote under [name], if any. */
    @android.annotation.TargetApi(Build.VERSION_CODES.Q)
    private fun findOwnBackup(name: String): android.net.Uri? {
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        contentResolver.query(
            collection,
            arrayOf(MediaStore.MediaColumns._ID),
            "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND ${MediaStore.MediaColumns.DISPLAY_NAME}=?",
            arrayOf(backupRelativePath, name),
            null,
        )?.use { c ->
            if (c.moveToFirst()) return ContentUris.withAppendedId(collection, c.getLong(0))
        }
        return null
    }

    /** Copies [sourcePath] to the backup folder as [name]; returns the folder. */
    private fun saveBackup(sourcePath: String, name: String, mimeType: String): Map<String, Any> {
        val source = File(sourcePath)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val target = File(legacyBackupDir(), name)
            source.copyTo(target, overwrite = true)
            return mapOf("location" to legacyBackupDir().absolutePath, "appStorage" to true)
        }
        val resolver = contentResolver
        val existing = findOwnBackup(name)
        val uri = existing ?: resolver.insert(
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
            ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, backupRelativePath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            },
        ) ?: throw IOException("Could not create $name in Downloads")
        (resolver.openOutputStream(uri, "wt") ?: throw IOException("Could not write $name"))
            .use { out -> source.inputStream().use { it.copyTo(out) } }
        if (existing == null) {
            resolver.update(
                uri,
                ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
                null,
                null,
            )
        }
        return mapOf("location" to "Download/Margo", "appStorage" to false)
    }

    /** The `.margo` files this app can see in the backup folder. */
    private fun listBackups(): List<Map<String, Any>> {
        val out = mutableListOf<Map<String, Any>>()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            legacyBackupDir().listFiles()?.forEach { f ->
                if (f.isFile && f.name.endsWith(".margo")) {
                    out.add(mapOf("name" to f.name, "size" to f.length(), "modified" to f.lastModified()))
                }
            }
            return out
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        contentResolver.query(
            collection,
            arrayOf(
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.DATE_MODIFIED,
            ),
            "${MediaStore.MediaColumns.RELATIVE_PATH}=?",
            arrayOf(backupRelativePath),
            null,
        )?.use { c ->
            while (c.moveToNext()) {
                val name = c.getString(0) ?: continue
                if (!name.endsWith(".margo")) continue
                // DATE_MODIFIED is in seconds.
                out.add(mapOf("name" to name, "size" to c.getLong(1), "modified" to c.getLong(2) * 1000))
            }
        }
        return out
    }

    /** Copies backup [name] to a plain file at [destPath]. */
    private fun copyBackupOut(name: String, destPath: String) {
        val dest = File(destPath)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            File(legacyBackupDir(), name).copyTo(dest, overwrite = true)
            return
        }
        val uri = findOwnBackup(name) ?: throw IOException("No backup named $name")
        (contentResolver.openInputStream(uri) ?: throw IOException("Could not read $name"))
            .use { input -> dest.outputStream().use { input.copyTo(it) } }
    }

    private fun deleteBackup(name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            File(legacyBackupDir(), name).delete()
            return
        }
        findOwnBackup(name)?.let { contentResolver.delete(it, null, null) }
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
            // Mobile data, or a Wi-Fi hotspot the user marked metered: big
            // downloads ask first. Needs ACCESS_NETWORK_STATE (declared).
            "metered" to
                (getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager)
                    .isActiveNetworkMetered,
        )
    }
}
