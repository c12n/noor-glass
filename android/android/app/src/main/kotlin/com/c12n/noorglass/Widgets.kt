package com.c12n.noorglass

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

private fun openAppIntent(context: Context): PendingIntent {
    val intent = Intent(context, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    return PendingIntent.getActivity(
        context, 0, intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
}

/// Home-screen widget showing the Daily Ayah, colored from the
/// widget theme colors the app stores in shared preferences
/// (match-the-theme by default, or the user's separate widget
/// palette from Settings | Theme | Widget colors).
class DailyAyahWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) updateDaily(context, appWidgetManager, id)
    }

    companion object {
        fun updateDaily(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_daily_ayah)
            val colors = DailyAyahNative.widgetColors(context)
            val (surah, ayah) = DailyAyahNative.forToday()
            val text = DailyAyahNative.ayahText(context, surah, ayah)
                ?: DailyAyahNative.fallbackText(surah, ayah)
            views.setInt(R.id.widget_root, "setBackgroundColor", colors.primary)
            views.setTextColor(R.id.widget_title, colors.accent)
            views.setTextColor(R.id.widget_ref, colors.text)
            views.setTextColor(R.id.widget_translation, colors.text)
            views.setTextViewText(R.id.widget_ref, "Surah $surah | Ayah $ayah")
            views.setTextViewText(R.id.widget_arabic, text?.first ?: "")
            views.setTextViewText(R.id.widget_translation, text?.second ?: "")
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))
            manager.updateAppWidget(id, views)
        }
    }
}

/// Home-screen widget showing where listening left off, colored
/// from the same widget theme colors. Data comes from the snapshot
/// keys the Flutter side writes on every position save
/// (flutter.widget.* and flutter.quran.lastSurah).
class ContinueListeningWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) updateContinue(context, appWidgetManager, id)
    }

    companion object {
        fun updateContinue(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_continue)
            val colors = DailyAyahNative.widgetColors(context)
            val prefs = DailyAyahNative.flutterPrefs(context)
            val name = DailyAyahNative.prefString(prefs, "flutter.widget.lastSurahName")
            val reciter =
                DailyAyahNative.prefString(prefs, "flutter.widget.lastReciterName")
            val pos = DailyAyahNative.prefDoubleValue(prefs, "flutter.widget.positionSec") ?: 0.0
            val dur = DailyAyahNative.prefDoubleValue(prefs, "flutter.widget.durationSec") ?: 0.0
            views.setInt(R.id.widget_root, "setBackgroundColor", colors.primary)
            views.setTextColor(R.id.widget_title, colors.accent)
            views.setTextColor(R.id.widget_name, colors.text)
            views.setTextColor(R.id.widget_reciter, colors.text)
            views.setTextColor(R.id.widget_time, colors.text)
            if (name.isNullOrEmpty()) {
                views.setTextViewText(R.id.widget_name, "Nothing played yet")
                views.setTextViewText(
                    R.id.widget_reciter, "Open Noor Glass to start listening")
                views.setTextViewText(R.id.widget_time, "")
                views.setProgressBar(R.id.widget_progress, 1000, 0, false)
            } else {
                views.setTextViewText(R.id.widget_name, name)
                views.setTextViewText(R.id.widget_reciter, reciter ?: "")
                views.setTextViewText(
                    R.id.widget_time,
                    if (dur > 0) {
                        "${DailyAyahNative.formatClock(pos)} of " +
                            DailyAyahNative.formatClock(dur)
                    } else ""
                )
                val progress = if (dur > 0) {
                    (pos / dur * 1000).toInt().coerceIn(0, 1000)
                } else 0
                views.setProgressBar(R.id.widget_progress, 1000, progress, false)
            }
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))
            manager.updateAppWidget(id, views)
        }
    }
}
