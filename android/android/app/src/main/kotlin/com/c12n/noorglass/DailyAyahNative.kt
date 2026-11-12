package com.c12n.noorglass

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.time.LocalDate

/// Shared native logic for the Daily Ayah widget and the daily
/// reminder: the same deterministic pick the Dart side uses
/// (lib/daily_ayah.dart), the widget theme colors the Flutter side
/// stores in shared preferences, and the bundled Quran text.
object DailyAyahNative {

    // Ayah counts per surah, 1..114 (total 6236).
    private val ayahCounts = intArrayOf(
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52,
        99, 128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88,
        69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59,
        37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
        14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31,
        50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21,
        11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4,
        5, 6
    )

    private const val totalAyahs = 6236

    /// Returns (surah, ayah) for the given local epoch day, using the
    /// exact rule in lib/daily_ayah.dart: index = day % 6236 walked
    /// over the surah ayah counts.
    fun forEpochDay(epochDay: Long): Pair<Int, Int> {
        var idx = Math.floorMod(epochDay, totalAyahs.toLong()).toInt()
        for (i in ayahCounts.indices) {
            if (idx < ayahCounts[i]) return Pair(i + 1, idx + 1)
            idx -= ayahCounts[i]
        }
        return Pair(1, 1)
    }

    fun forToday(): Pair<Int, Int> = forEpochDay(LocalDate.now().toEpochDay())

    // MARK: - Widget theme colors (written by the Dart side)

    data class WidgetColors(val primary: Int, val accent: Int, val text: Int)

    private fun prefLong(prefs: SharedPreferences, key: String): Long? {
        return try {
            if (!prefs.contains(key)) null else prefs.getLong(key, 0L)
        } catch (e: ClassCastException) {
            try {
                prefs.getInt(key, 0).toLong()
            } catch (e2: Exception) {
                null
            }
        }
    }

    private fun prefDouble(prefs: SharedPreferences, key: String): Double? {
        return try {
            if (!prefs.contains(key)) null else prefs.getFloat(key, 0f).toDouble()
        } catch (e: ClassCastException) {
            null
        }
    }

    fun widgetColors(context: Context): WidgetColors {
        val defaults = WidgetColors(0xFF0B3D2E.toInt(), 0xFFD4AF37.toInt(), 0xFFFFFFFF.toInt())
        return try {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE)
            val primary = prefLong(prefs, "flutter.appearance.widgetTheme.home.primaryHex")
            val accent = prefLong(prefs, "flutter.appearance.widgetTheme.home.accentHex")
            val text = prefLong(prefs, "flutter.appearance.widgetTheme.home.textHex")
            WidgetColors(
                primary?.toInt() ?: defaults.primary,
                accent?.toInt() ?: defaults.accent,
                text?.toInt() ?: defaults.text
            )
        } catch (e: Exception) {
            defaults
        }
    }

    fun flutterPrefs(context: Context): SharedPreferences =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    fun prefString(prefs: SharedPreferences, key: String): String? =
        try {
            prefs.getString(key, null)
        } catch (e: Exception) {
            null
        }

    fun prefIntValue(prefs: SharedPreferences, key: String): Int? =
        prefLong(prefs, key)?.toInt()

    fun prefDoubleValue(prefs: SharedPreferences, key: String): Double? {
        // shared_preferences stores Dart doubles as raw doubles, which
        // the Android legacy implementation keeps in a string-encoded
        // form readable only through its own codec; getFloat covers
        // the plain case. Anything unreadable falls back to null.
        return try {
            @Suppress("UNCHECKED_CAST")
            val raw = prefs.all[key]
            when (raw) {
                is Double -> raw
                is Float -> raw.toDouble()
                is Long -> java.lang.Double.longBitsToDouble(raw)
                else -> prefDouble(prefs, key)
            }
        } catch (e: Exception) {
            null
        }
    }

    // MARK: - Bundled text

    /// (arabic, english) for one ayah from the bundled asset, or null.
    fun ayahText(context: Context, surah: Int, ayah: Int): Pair<String, String>? {
        return try {
            val json = context.assets
                .open("flutter_assets/assets/quran/quran_text.json")
                .bufferedReader().use { it.readText() }
            val root = JSONObject(json)
            val arr = root.getJSONArray(surah.toString())
            for (i in 0 until arr.length()) {
                val item = arr.getJSONObject(i)
                if (item.getInt("n") == ayah) {
                    return Pair(item.optString("ar"), item.optString("en"))
                }
            }
            null
        } catch (e: Exception) {
            null
        }
    }

    /// Small built-in fallback, used only if the asset cannot be read.
    fun fallbackText(surah: Int, ayah: Int): Pair<String, String>? {
        val table = mapOf(
            (2 to 255) to ("Allah! There is no god but He, the Living, the Self-subsisting, Eternal."),
            (2 to 152) to ("So remember Me; I will remember you."),
            (2 to 286) to ("Allah does not charge a soul except [with that within] its capacity."),
            (94 to 6) to ("Indeed, with hardship comes ease."),
            (13 to 28) to ("Verily, in the remembrance of Allah do hearts find rest."),
            (40 to 60) to ("And your Lord says: Call upon Me; I will respond to you."),
            (3 to 160) to ("If Allah should aid you, no one can overcome you."),
            (65 to 3) to ("And whoever relies upon Allah, then He is sufficient for him."),
            (14 to 7) to ("If you are grateful, I will surely increase you [in favor]."),
            (55 to 13) to ("So which of the favors of your Lord would you deny?")
        )
        val en = table[surah to ayah] ?: return null
        return Pair("", en)
    }

    fun formatClock(totalSeconds: Double): String {
        val s = totalSeconds.toInt().coerceAtLeast(0)
        val h = s / 3600
        val m = (s % 3600) / 60
        val sec = s % 60
        return if (h > 0) "%d:%02d:%02d".format(h, m, sec) else "%d:%02d".format(m, sec)
    }
}
