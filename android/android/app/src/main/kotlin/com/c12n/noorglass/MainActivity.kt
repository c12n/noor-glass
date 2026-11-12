package com.c12n.noorglass

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Daily Ayah reminder scheduling (called from lib/daily_ayah.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "noorglass/reminders")
            .setMethodCallHandler { call, result ->
                if (call.method == "setReminder") {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val hour = call.argument<Int>("hour") ?: 8
                    val minute = call.argument<Int>("minute") ?: 0
                    val prefs = getSharedPreferences(
                        "noorglass_native", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putBoolean("reminder.enabled", enabled)
                        .putInt("reminder.hour", hour)
                        .putInt("reminder.minute", minute)
                        .apply()
                    if (enabled) {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                7301
                            )
                        }
                        DailyReminderScheduler.schedule(this, hour, minute)
                    } else {
                        DailyReminderScheduler.cancel(this)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // Alternate launcher icons (called from lib/app_theme.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "noorglass/icons")
            .setMethodCallHandler { call, result ->
                if (call.method == "setIcon") {
                    setLauncherIcon(call.argument<String>("name") ?: "default")
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    /// Enables the chosen icon's activity-alias and disables the
    /// others. The real MainActivity component is never toggled;
    /// only the aliases carry the LAUNCHER intent filter.
    private fun setLauncherIcon(name: String) {
        val aliases = linkedMapOf(
            "default" to "com.c12n.noorglass.IconDefault",
            "ocean" to "com.c12n.noorglass.IconOcean",
            "desert" to "com.c12n.noorglass.IconDesert",
            "emerald" to "com.c12n.noorglass.IconEmerald",
            "crimson" to "com.c12n.noorglass.IconCrimson",
            "sapphire" to "com.c12n.noorglass.IconSapphire",
            "plum" to "com.c12n.noorglass.IconPlum",
            "contrast" to "com.c12n.noorglass.IconContrast"
        )
        val pm = packageManager
        for ((key, className) in aliases) {
            val state = if (key == name) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            try {
                pm.setComponentEnabledSetting(
                    ComponentName(this, className),
                    state,
                    PackageManager.DONT_KILL_APP
                )
            } catch (e: Exception) {
                // Unknown alias on an older build: leave icons as they are.
            }
        }
    }
}
