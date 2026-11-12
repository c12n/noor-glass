package com.c12n.noorglass

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.Calendar

/// Schedules the daily reminder with an inexact daily alarm
/// (no exact-alarm permission needed; delivery may drift a few
/// minutes, which is fine for a daily ayah).
object DailyReminderScheduler {
    private const val REQUEST_CODE = 7302

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, DailyReminderReceiver::class.java)
        return PendingIntent.getBroadcast(
            context, REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun schedule(context: Context, hour: Int, minute: Int) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }
        alarm.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            next.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent(context)
        )
    }

    fun cancel(context: Context) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarm.cancel(pendingIntent(context))
    }
}

/// Posts the Daily Ayah notification (framework notification APIs
/// only, so the module needs no extra dependencies).
class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        val channelId = "daily_ayah_reminders"
        val channel = NotificationChannel(
            channelId, "Daily Ayah reminder",
            NotificationManager.IMPORTANCE_DEFAULT
        )
        manager.createNotificationChannel(channel)

        val (surah, ayah) = DailyAyahNative.forToday()
        val text = DailyAyahNative.ayahText(context, surah, ayah)
            ?: DailyAyahNative.fallbackText(surah, ayah)
        val body = text?.second ?: ""
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context, 0, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = Notification.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_stat_noor)
            .setContentTitle("Daily Ayah | Surah $surah, Ayah $ayah")
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .build()
        manager.notify(7301, notification)
    }
}

/// Reschedules the reminder after a reboot, if it was enabled.
class DailyReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val prefs = context.getSharedPreferences("noorglass_native", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("reminder.enabled", false)) return
        DailyReminderScheduler.schedule(
            context,
            prefs.getInt("reminder.hour", 8),
            prefs.getInt("reminder.minute", 0)
        )
    }
}
