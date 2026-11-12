// Daily Ayah (Noor Glass 1.1.0, phase 2 feature 6).
//
// One ayah per day, picked deterministically: the day number
// (days since epoch, local) modulo 6,236 walks the whole Quran
// in order, so the app UI, the home-screen widget and the daily
// reminder all show the same ayah without coordinating. The
// Kotlin widget and reminder receiver implement the identical
// rule natively (see DailyAyahWidget.kt).
//
// The reminder itself is scheduled natively (AlarmManager)
// through the 'noorglass/reminders' MethodChannel implemented
// in MainActivity.kt; its settings live under
// `daily.reminder.*` here.

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_models.dart';

class DailyAyah {
  final int surah;
  final int ayah;
  const DailyAyah(this.surah, this.ayah);

  QuranAyahText? get text {
    final list = QuranTextData.ayahsBySurah[surah];
    if (list == null || ayah < 1 || ayah > list.length) return null;
    return list[ayah - 1];
  }

  String get reference =>
      '${QuranLibrary.surah(surah)?.english ?? 'Surah $surah'} | Ayah $ayah';

  /// The deterministic pick for a local date. The day number is
  /// the epoch day of the local calendar date (computed via a UTC
  /// date so the value matches java.time.LocalDate.toEpochDay()
  /// in the Kotlin widget and reminder exactly, in any timezone).
  static DailyAyah forDate(DateTime date) {
    final dayNumber =
        DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
    return fromGlobalIndex(dayNumber % 6236);
  }

  /// Maps a 0-based global ayah index to (surah, ayah).
  static DailyAyah fromGlobalIndex(int globalIndex) {
    var remaining = globalIndex % 6236;
    for (final s in QuranLibrary.surahs) {
      if (remaining < s.ayahs) return DailyAyah(s.number, remaining + 1);
      remaining -= s.ayahs;
    }
    return const DailyAyah(1, 1);
  }
}

/// Settings for the daily reminder notification: enabled flag
/// and a local time of day, persisted and mirrored to the
/// native scheduler.
class DailyReminderSettings {
  static const enabledKey = 'daily.reminder.enabled';
  static const hourKey = 'daily.reminder.hour';
  static const minuteKey = 'daily.reminder.minute';
  static const _channel = MethodChannel('noorglass/reminders');

  bool enabled = false;
  int hour = 8;
  int minute = 0;
  SharedPreferences? _prefs;

  void load(SharedPreferences prefs) {
    _prefs = prefs;
    enabled = prefs.getBool(enabledKey) ?? false;
    hour = prefs.getInt(hourKey) ?? 8;
    minute = prefs.getInt(minuteKey) ?? 0;
  }

  Future<void> apply({bool? enabled, int? hour, int? minute}) async {
    if (enabled != null) this.enabled = enabled;
    if (hour != null) this.hour = hour;
    if (minute != null) this.minute = minute;
    await _prefs?.setBool(enabledKey, this.enabled);
    await _prefs?.setInt(hourKey, this.hour);
    await _prefs?.setInt(minuteKey, this.minute);
    await syncNative();
  }

  /// Tells the native scheduler the current settings. Safe when
  /// the channel is unavailable (tests, other platforms).
  Future<void> syncNative() async {
    try {
      await _channel.invokeMethod<void>('setReminder', {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
      });
    } catch (_) {
      // No native side: the setting simply has no effect yet.
    }
  }
}
