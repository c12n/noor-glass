// Khatmah planner (Noor Glass 1.1.0, phase 2 feature 7).
//
// A finish-the-Quran listening plan built on the player's
// existing listening statistics. A cycle snapshots the per-surah
// completion counts when it starts; a surah counts toward the
// khatmah once it has been played to its natural end at least
// once more within the cycle. Progress is measured in ayahs
// covered. Persisted under `quran.khatmah.v1`.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_models.dart';
import 'quran_player.dart';

class KhatmahPlan {
  /// Cycle start (local date, time zeroed).
  DateTime startDate;

  /// Target length of the cycle in days.
  int targetDays;

  /// Per-surah completion counts at cycle start (baseline);
  /// progress counts completions beyond these.
  Map<String, int> baseline;

  KhatmahPlan({
    required this.startDate,
    required this.targetDays,
    required this.baseline,
  });

  DateTime get targetDate => startDate.add(Duration(days: targetDays - 1));

  Map<String, dynamic> toJson() => {
        'start': startDate.millisecondsSinceEpoch,
        'days': targetDays,
        'baseline': baseline,
      };

  factory KhatmahPlan.fromJson(Map<String, dynamic> json) => KhatmahPlan(
        startDate: DateTime.fromMillisecondsSinceEpoch(
            (json['start'] as num?)?.toInt() ?? 0),
        targetDays: (json['days'] as num?)?.toInt() ?? 30,
        baseline: (json['baseline'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      );
}

class KhatmahStore extends ChangeNotifier {
  static const _key = 'quran.khatmah.v1';
  KhatmahPlan? plan;
  SharedPreferences? _prefs;

  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        plan = KhatmahPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        plan = null;
      }
    }
    notifyListeners();
  }

  void start(QuranPlayer player, int targetDays) {
    final now = DateTime.now();
    plan = KhatmahPlan(
      startDate: DateTime(now.year, now.month, now.day),
      targetDays: targetDays,
      baseline: Map.of(player.stats.perSurah),
    );
    _save();
    notifyListeners();
  }

  void clear() {
    plan = null;
    _prefs?.remove(_key);
    notifyListeners();
  }

  void _save() {
    final p = plan;
    if (p == null) return;
    _prefs?.setString(_key, jsonEncode(p.toJson()));
  }

  /// Surahs completed within the current cycle (delta over the
  /// baseline), in surah order.
  List<int> completedSurahs(QuranPlayer player) {
    final p = plan;
    if (p == null) return const [];
    return [
      for (var n = 1; n <= 114; n++)
        if ((player.stats.perSurah['$n'] ?? 0) > (p.baseline['$n'] ?? 0)) n,
    ];
  }

  /// Ayahs covered within the cycle.
  int coveredAyahs(QuranPlayer player) => completedSurahs(player)
      .fold(0, (sum, n) => sum + (QuranLibrary.surah(n)?.ayahs ?? 0));

  static const totalAyahs = 6236;

  double progress(QuranPlayer player) =>
      plan == null ? 0 : coveredAyahs(player) / totalAyahs;

  /// Whole days elapsed in the cycle, counting the start day.
  int dayOfCycle(DateTime now) {
    final p = plan;
    if (p == null) return 0;
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(p.startDate).inDays + 1;
  }

  /// The ayah quota for today: what an even pace asks for by the
  /// end of today, minus what is already covered (never below 0).
  int todaysQuotaAyahs(QuranPlayer player, DateTime now) {
    final p = plan;
    if (p == null) return 0;
    final day = dayOfCycle(now).clamp(1, p.targetDays);
    final expectedByToday = (totalAyahs * day / p.targetDays).ceil();
    return math.max(0, expectedByToday - coveredAyahs(player));
  }

  /// Today's portion: the next surahs in order (not yet completed
  /// this cycle) whose ayahs fill today's quota; the final surah
  /// may overshoot the quota, since playback is per surah.
  List<int> todaysPortion(QuranPlayer player, DateTime now) {
    final quota = todaysQuotaAyahs(player, now);
    if (quota <= 0) return const [];
    final done = completedSurahs(player).toSet();
    final portion = <int>[];
    var acc = 0;
    for (var n = 1; n <= 114 && acc < quota; n++) {
      if (done.contains(n)) continue;
      portion.add(n);
      acc += QuranLibrary.surah(n)?.ayahs ?? 0;
    }
    return portion;
  }
}
