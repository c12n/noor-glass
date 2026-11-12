// Word by word (Noor Glass 1.1.0, phase 2 feature 4).
//
// Data: the Quran.com API v4 word segmentation (Uthmani word
// text, English transliteration and English word translation),
// fetched once at build time for all 6,236 ayahs and bundled as
// assets/quran/word_by_word.json in the compact form
// { "surah:ayah": [[uthmani, transliteration, translation], ...] }.
//
// Playback highlighting is ESTIMATED: the current word is picked
// by character weights inside the current ayah, the same estimate
// family the ayah timing uses. It is labelled as an estimate in
// the UI; it is not measured word timing.

import 'dart:convert';

import 'package:flutter/services.dart';

class QuranWord {
  final String ar;
  final String transliteration;
  final String translation;
  const QuranWord({
    required this.ar,
    required this.transliteration,
    required this.translation,
  });
}

class QuranWords {
  static Map<String, List<QuranWord>> _byKey = {};
  static bool _loaded = false;
  static Future<void>? _loading;

  static Future<void> load() {
    if (_loaded) return Future.value();
    return _loading ??= () async {
      try {
        final raw =
            await rootBundle.loadString('assets/quran/word_by_word.json');
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final parsed = <String, List<QuranWord>>{};
        for (final entry in decoded.entries) {
          parsed[entry.key] = (entry.value as List)
              .map((w) => QuranWord(
                    ar: (w as List)[0] as String,
                    transliteration: w[1] as String,
                    translation: w[2] as String,
                  ))
              .toList();
        }
        _byKey = parsed;
      } catch (_) {
        _byKey = {};
      }
      _loaded = true;
    }();
  }

  static bool get isLoaded => _loaded;

  static List<QuranWord> wordsFor(int surah, int ayah) =>
      _byKey['$surah:$ayah'] ?? const [];

  /// The estimated current word index inside an ayah: the
  /// fraction of the ayah already played (0..1) applied across
  /// the words weighted by Arabic character count.
  static int estimatedWordIndex(List<QuranWord> words, double ayahFraction) {
    if (words.isEmpty) return -1;
    if (ayahFraction <= 0) return 0;
    if (ayahFraction >= 1) return words.length - 1;
    final weights = [
      for (final w in words) w.ar.isEmpty ? 1 : w.ar.length
    ];
    final total = weights.fold<int>(0, (a, b) => a + b);
    if (total <= 0) return 0;
    var target = ayahFraction * total;
    for (var i = 0; i < weights.length; i++) {
      if (target < weights[i]) return i;
      target -= weights[i];
    }
    return words.length - 1;
  }
}
