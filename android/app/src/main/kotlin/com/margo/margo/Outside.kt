package com.margo.margo

// Margo outside the app (docs/COMPETITOR_UPGRADE_PLAN.md, Phase 7): study
// reminders, the "New note" Quick Settings tile and the two home-screen
// widgets. Each opens MainActivity with a launch action ([Launch]); Dart takes
// it over the "com.margo.margo/launch" channel. Dart works out what to show
// (reminder texts, cards due, the pinned note) and hands it over, because the
// notes live in a database only Dart reads.

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

object Launch {
    const val PREFIX = "com.margo.margo.action."
    const val NEW_NOTE = PREFIX + "NEW_NOTE"
    const val OPEN = PREFIX + "OPEN"
    const val REVIEW = PREFIX + "REVIEW"
    const val EXTRA_NOTEBOOK = "notebookId"

    fun isLaunch(intent: Intent?): Boolean = intent?.action?.startsWith(PREFIX) == true

    /** {action: "new_note" | "scan" | ..., notebookId?} for Dart. */
    fun describe(intent: Intent): Map<String, Any?> = mapOf(
        "action" to intent.action!!.removePrefix(PREFIX).lowercase(),
        "notebookId" to intent.getIntExtra(EXTRA_NOTEBOOK, -1).takeIf { it >= 0 },
    )

    fun pending(context: Context, action: String, notebookId: Int?, code: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(action)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (notebookId != null) intent.putExtra(EXTRA_NOTEBOOK, notebookId)
        return PendingIntent.getActivity(
            context, code, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

/** Study reminders: a list of {at, title, body, notebookId} kept in prefs, one
 *  alarm armed for the next. Planned by Dart whenever the app is left. */
object Reminders {
    private const val PREFS = "margo_outside"
    private const val KEY = "reminders"
    private const val CHANNEL = "study_reminders"

    fun save(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()
        arm(context)
    }

    private fun load(context: Context): JSONArray = try {
        JSONArray(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]"))
    } catch (_: Exception) {
        JSONArray()
    }

    /** Arms an (inexact, battery-friendly) alarm for the next reminder. */
    fun arm(context: Context) {
        val now = System.currentTimeMillis()
        var next: Long? = null
        val all = load(context)
        for (i in 0 until all.length()) {
            val at = all.getJSONObject(i).getLong("at")
            if (at > now && (next == null || at < next)) next = at
        }
        val alarms = context.getSystemService(AlarmManager::class.java)
        val pending = PendingIntent.getBroadcast(
            context, 0, Intent(context, ReminderReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarms.cancel(pending)
        if (next != null) alarms.set(AlarmManager.RTC_WAKEUP, next, pending)
    }

    /** Shows the reminders whose time has come (within the last day), then
     *  arms the next. */
    fun fire(context: Context) {
        val now = System.currentTimeMillis()
        val all = load(context)
        val left = JSONArray()
        var shown: JSONObject? = null
        for (i in 0 until all.length()) {
            val r = all.getJSONObject(i)
            val at = r.getLong("at")
            when {
                at > now -> left.put(r)
                now - at < 24 * 3600_000L -> shown = r // the latest due one
            }
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY, left.toString()).apply()
        shown?.let { notify(context, it) }
        arm(context)
    }

    private fun notify(context: Context, r: JSONObject) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Study reminders", NotificationManager.IMPORTANCE_DEFAULT),
            )
        }
        val notebook = if (r.isNull("notebookId")) null else r.getInt("notebookId")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION") android.app.Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(r.getString("title"))
            .setContentText(r.getString("body"))
            .setAutoCancel(true)
            .setContentIntent(Launch.pending(context, Launch.REVIEW, notebook, 10))
            .build()
        // Without the notification permission this posts nothing; the setting
        // asked for it when switched on.
        try {
            manager.notify(7, notification)
        } catch (_: SecurityException) {
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            // Alarms don't survive a restart or an app update.
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> Reminders.arm(context)
            else -> Reminders.fire(context)
        }
    }
}

/** Quick Settings: "New note". */
class NewNoteTileService : TileService() {
    override fun onClick() {
        super.onClick()
        val pending = Launch.pending(this, Launch.NEW_NOTE, null, 20)
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(pending)
        } else {
            @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(
                Intent(this, MainActivity::class.java)
                    .setAction(Launch.NEW_NOTE)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }
}

/** The two widgets' data: written by Dart, drawn here. */
object Widgets {
    private const val PREFS = "margo_outside"

    fun save(context: Context, due: Int, pinnedId: Int?, pinnedTitle: String?, pinnedText: String?) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt("due", due)
            .putInt("pinnedId", pinnedId ?: -1)
            .putString("pinnedTitle", pinnedTitle)
            .putString("pinnedText", pinnedText)
            .apply()
        refresh(context, DueCardsWidget::class.java)
        refresh(context, PinnedNoteWidget::class.java)
    }

    private fun refresh(context: Context, type: Class<*>) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, type))
        if (ids.isEmpty()) return
        context.sendBroadcast(
            Intent(context, type)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
        )
    }

    fun due(context: Context): Int =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt("due", 0)

    fun pinned(context: Context): Triple<Int?, String?, String?> {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val id = p.getInt("pinnedId", -1)
        return Triple(id.takeIf { it >= 0 }, p.getString("pinnedTitle", null), p.getString("pinnedText", null))
    }
}

class DueCardsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val due = Widgets.due(context)
        val views = RemoteViews(context.packageName, R.layout.widget_due).apply {
            setTextViewText(R.id.widget_due_count, due.toString())
            setTextViewText(
                R.id.widget_due_label,
                when (due) {
                    0 -> "No cards due"
                    1 -> "card due today"
                    else -> "cards due today"
                },
            )
            setOnClickPendingIntent(R.id.widget_root, Launch.pending(context, Launch.REVIEW, null, 30))
        }
        manager.updateAppWidget(ids, views)
    }
}

class PinnedNoteWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val (id, title, text) = Widgets.pinned(context)
        val views = RemoteViews(context.packageName, R.layout.widget_pinned).apply {
            setTextViewText(R.id.widget_pinned_title, title ?: "No pinned note")
            setTextViewText(R.id.widget_pinned_text, text ?: if (id == null) "Pin a note in Margo to keep it here." else "")
            setOnClickPendingIntent(
                R.id.widget_root,
                if (id != null) Launch.pending(context, Launch.OPEN, id, 40)
                else Launch.pending(context, Launch.PREFIX + "HOME", null, 41),
            )
        }
        manager.updateAppWidget(ids, views)
    }
}
