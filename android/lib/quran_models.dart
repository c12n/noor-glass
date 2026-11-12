// Quran layer (Noor Glass 1.0.0) — the Android counterpart of the iOS Quran
// models: the bundled surah catalogue (surahs.json), the ayah text
// store (quran_text.json — Arabic Uthmani + Saheeh International),
// ayah bookmarks, and the character-weighted ayah timing estimates
// the lyrics view and the memorization loop share, all ported from
// QuranModels.swift / QuranLyrics.swift.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranReciter {
  final String id;
  final String name;

  /// Per-reciter stream base URL (phase 2). Null means the
  /// catalogue-wide [QuranLibrary.audioBase] (Islamic Network,
  /// unpadded surah numbers). The two Sudanese reciters stream
  /// from mp3quran's CDN with their own base and padded numbers.
  final String? base;

  /// True when this reciter's file names are zero-padded to three
  /// digits ("036.mp3"); the Islamic Network files are unpadded.
  final bool pad;

  /// The narration (riwaya) label shown in the picker: the
  /// Sudanese Noreen Mohammad Siddiq recites in Ad-Duri 'an Abi
  /// 'Amr (NOT Hafs), Alzain Mohammad Ahmad in Hafs Murattal.
  final String? narration;

  const QuranReciter({
    required this.id,
    required this.name,
    this.base,
    this.pad = false,
    this.narration,
  });

  factory QuranReciter.fromJson(Map<String, dynamic> json) => QuranReciter(
        id: json['id'] as String,
        name: json['name'] as String,
        base: json['base'] as String?,
        pad: json['pad'] as bool? ?? false,
        narration: json['narration'] as String?,
      );

  String get subtitle => narration ?? "Hafs 'an 'Asim";
}

class QuranSurah {
  final int number;
  final String arabic;
  final String english;
  final String meaning;
  final int ayahs;

  /// "Makki" or "Madani".
  final String revelation;

  /// Stream duration in seconds, keyed by reciter id.
  final Map<String, int> durations;

  const QuranSurah({
    required this.number,
    required this.arabic,
    required this.english,
    required this.meaning,
    required this.ayahs,
    required this.revelation,
    required this.durations,
  });

  factory QuranSurah.fromJson(Map<String, dynamic> json) => QuranSurah(
        number: json['number'] as int,
        arabic: json['arabic'] as String,
        english: json['english'] as String,
        meaning: json['meaning'] as String,
        ayahs: json['ayahs'] as int,
        revelation: json['revelation'] as String,
        durations: (json['durations'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      );

  int get id => number;

  int? durationFor(String reciterId) => durations[reciterId];
}

/// The bundled catalogue, loaded once from assets (iOS: QuranLibrary).
class QuranLibrary {
  static List<QuranReciter> reciters = [];
  static List<QuranSurah> surahs = [];
  static String audioBase = '';
  static Map<int, int> englishDurations = {};
  static bool _loaded = false;

  /// The pseudo-reciter id for the English translation audio; it
  /// keys the downloads folder exactly like a reciter id (iOS).
  static const englishReciterId = 'english';
  static const englishReciter =
      QuranReciter(id: englishReciterId, name: 'Ibrahim Walk (English)');

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await rootBundle.loadString('assets/quran/surahs.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    reciters = (decoded['reciters'] as List)
        .map((e) => QuranReciter.fromJson(e as Map<String, dynamic>))
        .toList();
    audioBase = decoded['audioBase'] as String;
    surahs = (decoded['surahs'] as List)
        .map((e) => QuranSurah.fromJson(e as Map<String, dynamic>))
        .toList();
    final enRaw = await rootBundle.loadString('assets/quran/en_durations.json');
    final en = jsonDecode(enRaw) as Map<String, dynamic>;
    englishDurations = {
      for (final entry in en.entries)
        if (int.tryParse(entry.key) != null)
          int.parse(entry.key): (entry.value as num).toInt(),
    };
  }

  static QuranSurah? surah(int number) {
    for (final s in surahs) {
      if (s.number == number) return s;
    }
    return null;
  }

  static QuranReciter? reciter(String id) {
    for (final r in reciters) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// The first reciter in the catalogue (Alafasy) — the default.
  static QuranReciter? get defaultReciter =>
      reciters.isEmpty ? null : reciters.first;

  /// The per-surah stream URL for a reciter: the Islamic Network
  /// pattern "{audioBase}/{reciterId}/{number}.mp3" (128 kbps,
  /// unpadded) for the original four, and "{base}/{NNN}.mp3"
  /// (zero-padded) for reciters with their own base (mp3quran:
  /// the two Sudanese reciters).
  static String streamUrl(int surahNumber, String reciterId) {
    final r = reciter(reciterId);
    if (r?.base != null) {
      final file = r!.pad
          ? '${surahNumber.toString().padLeft(3, '0')}.mp3'
          : '$surahNumber.mp3';
      return '${r.base}/$file';
    }
    return '$audioBase/$reciterId/$surahNumber.mp3';
  }

  // MARK: Per-ayah audio (phase 2, feature 3)

  /// Reciters with verified per-ayah files on the Islamic Network
  /// per-ayah CDN (probed 2026-11-12: Alafasy serves ayahs 1, 262
  /// and 6236; the other three original reciters answer 403
  /// there, and the Sudanese reciters are per-surah only on
  /// mp3quran). Everyone else keeps estimate-based ayah timing.
  static const perAyahReciterIds = {'ar.alafasy'};

  static bool supportsPerAyahAudio(String reciterId) =>
      perAyahReciterIds.contains(reciterId);

  /// The global ayah number (1 to 6236) of a surah's first ayah
  /// is its offset + 1; offsets derive from the catalogue counts.
  static final List<int> _ayahOffsets = () {
    final offsets = <int>[];
    var acc = 0;
    for (final s in surahs) {
      offsets.add(acc);
      acc += s.ayahs;
    }
    return offsets;
  }();

  static int globalAyahNumber(int surahNumber, int ayahNumber) {
    if (surahNumber < 1 || surahNumber > _ayahOffsets.length) return 0;
    return _ayahOffsets[surahNumber - 1] + ayahNumber;
  }

  /// Per-ayah stream URL on the Islamic Network per-ayah CDN,
  /// keyed by the global ayah number.
  static String perAyahUrl(int surahNumber, int ayahNumber, String reciterId) {
    final global = globalAyahNumber(surahNumber, ayahNumber);
    return 'https://cdn.islamic.network/quran/audio/128/$reciterId/$global.mp3';
  }

  /// Full-surah English translation MP3s (Ibrahim Walk), hosted by
  /// QuranicAudio; surah number zero-padded to three digits.
  static String englishStreamUrl(int surahNumber) =>
      'https://download.quranicaudio.com/quran/ibrahim_walk/'
      '${surahNumber.toString().padLeft(3, '0')}.mp3';

  /// The stream URL for any reciter id, English included.
  static String audioUrl(int surahNumber, String reciterId) =>
      reciterId == englishReciterId
          ? englishStreamUrl(surahNumber)
          : streamUrl(surahNumber, reciterId);

  static int? durationSeconds(int surahNumber, String reciterId) =>
      reciterId == englishReciterId
          ? englishDurations[surahNumber]
          : surah(surahNumber)?.durationFor(reciterId);

  /// "7:02" under an hour, "2:05:40" above it.
  static String formatDuration(num seconds) {
    final total = seconds < 0 ? 0 : seconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }
}

/// A named playlist of surahs, shown as a card in the library (iOS).
class QuranCollection {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final List<int> surahNumbers;
  const QuranCollection({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.surahNumbers,
  });

  List<QuranSurah> get surahs =>
      surahNumbers.map(QuranLibrary.surah).whereType<QuranSurah>().toList();

  static const collections = [
    QuranCollection(
      id: 'ramadan',
      titleKey: 'ramadan',
      subtitleKey: 'colRamadanSub',
      surahNumbers: [2, 36, 18, 55, 67, 97, 12, 19, 78, 112, 113, 114],
    ),
    QuranCollection(
      id: 'eid',
      titleKey: 'colEid',
      subtitleKey: 'colEidSub',
      surahNumbers: [87, 88, 50, 54, 109, 112, 113, 114],
    ),
  ];
}

// MARK: - Ayah text (quran_text.json)

class QuranAyahText {
  /// Ayah number within the surah.
  final int n;
  final String ar;
  final String en;

  /// French translation (Muhammad Hamidullah), bundled since
  /// phase 2 (feature 10). Empty when absent.
  final String fr;
  const QuranAyahText({
    required this.n,
    required this.ar,
    required this.en,
    this.fr = '',
  });

  factory QuranAyahText.fromJson(Map<String, dynamic> json) => QuranAyahText(
        n: json['n'] as int,
        ar: json['ar'] as String,
        en: json['en'] as String,
        fr: json['fr'] as String? ?? '',
      );

  /// The translation in the picked language ('en' or 'fr').
  String translation(String lang) => lang == 'fr' && fr.isNotEmpty ? fr : en;
}

/// Loads quran_text.json once and caches it (iOS: QuranTextData).
class QuranTextData {
  static Map<int, List<QuranAyahText>> ayahsBySurah = {};
  static bool _loaded = false;
  static Future<void>? _loading;

  static Future<void> load() {
    if (_loaded) return Future.value();
    return _loading ??= () async {
      final raw = await rootBundle.loadString('assets/quran/quran_text.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final parsed = <int, List<QuranAyahText>>{};
      for (final entry in decoded.entries) {
        final number = int.tryParse(entry.key);
        if (number == null) continue;
        parsed[number] = (entry.value as List)
            .map((e) => QuranAyahText.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      ayahsBySurah = parsed;
      _loaded = true;
    }();
  }
}

// MARK: - Ayah timing estimates (character-weighted, as iOS)

int _weight(QuranAyahText ayah) => ayah.ar.isEmpty ? 1 : ayah.ar.length;

/// Estimated current ayah index: playback fraction applied across
/// the ayahs weighted by Arabic character count.
int quranCurrentAyahIndex(List<QuranAyahText> ayahs, double time, double duration) {
  if (ayahs.isEmpty || duration <= 0) return 0;
  final weights = ayahs.map(_weight).toList();
  final total = weights.fold<int>(0, (a, b) => a + b);
  if (total <= 0) return 0;
  var target = (time / duration) * total;
  for (var i = 0; i < weights.length; i++) {
    if (target < weights[i]) return i;
    target -= weights[i];
  }
  return ayahs.length - 1;
}

/// Start time of an ayah under the same weighted estimate.
double quranAyahStartTime(List<QuranAyahText> ayahs, int index, double duration) {
  if (index < 0 || index >= ayahs.length || duration <= 0) return 0;
  final weights = ayahs.map(_weight).toList();
  final total = weights.fold<int>(0, (a, b) => a + b);
  if (total <= 0) return 0;
  final before = weights.sublist(0, index).fold<int>(0, (a, b) => a + b);
  return duration * before / total;
}

/// End time of an ayah under the same weighted estimate.
double quranAyahEndTime(List<QuranAyahText> ayahs, int index, double duration) {
  if (index < 0 || index >= ayahs.length || duration <= 0) return 0;
  if (index + 1 >= ayahs.length) return duration;
  return quranAyahStartTime(ayahs, index + 1, duration);
}

// MARK: - Ayah bookmarks (iOS: QuranBookmarks)

/// One saved ayah: a surah number + ayah number within it.
class QuranBookmark {
  final int surah;
  final int ayah;
  final DateTime createdAt;
  const QuranBookmark({
    required this.surah,
    required this.ayah,
    required this.createdAt,
  });

  String get id => '$surah:$ayah';

  Map<String, dynamic> toJson() => {
        'surah': surah,
        'ayah': ayah,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory QuranBookmark.fromJson(Map<String, dynamic> json) => QuranBookmark(
        surah: json['surah'] as int,
        ayah: json['ayah'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int? ?? 0),
      );
}

/// Persisted ayah bookmarks (`quran.bookmarks.v1` JSON, like iOS).
class QuranBookmarks extends ChangeNotifier {
  static const _key = 'quran.bookmarks.v1';
  List<QuranBookmark> bookmarks = [];
  SharedPreferences? _prefs;

  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        bookmarks = (jsonDecode(raw) as List)
            .map((e) => QuranBookmark.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (_) {
        bookmarks = [];
      }
    }
    notifyListeners();
  }

  bool isBookmarked(int surah, int ayah) =>
      bookmarks.any((b) => b.surah == surah && b.ayah == ayah);

  void toggle(int surah, int ayah) {
    if (isBookmarked(surah, ayah)) {
      bookmarks.removeWhere((b) => b.surah == surah && b.ayah == ayah);
    } else {
      bookmarks.insert(
          0, QuranBookmark(surah: surah, ayah: ayah, createdAt: DateTime.now()));
    }
    _save();
    notifyListeners();
  }

  void remove(QuranBookmark bookmark) {
    bookmarks.removeWhere((b) => b.id == bookmark.id);
    _save();
    notifyListeners();
  }

  void _save() {
    _prefs?.setString(
        _key, jsonEncode(bookmarks.map((b) => b.toJson()).toList()));
  }
}

/// The favorite heart's red: a semantic signal color, not a
/// theme surface (the theme system lives in app_theme.dart;
/// since 1.1.0 every surface follows the picked theme).
const quranHeartRed = Color(0xFFE5484D);

// MARK: - Mushaf mapping (phase 2, feature 1)

/// One Madani Mushaf anchor: the (surah, ayah) a page or juz
/// starts at. From the AlQuranCloud meta references (604 pages,
/// 30 juzs), bundled as assets/quran/mushaf_meta.json.
class MushafAnchor {
  final int number; // page (1..604) or juz (1..30)
  final int surah;
  final int ayah;
  const MushafAnchor({
    required this.number,
    required this.surah,
    required this.ayah,
  });
}

class MushafMeta {
  static List<MushafAnchor> pages = [];
  static List<MushafAnchor> juzs = [];
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await rootBundle.loadString('assets/quran/mushaf_meta.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    pages = (decoded['pages'] as List)
        .map((e) => MushafAnchor(
              number: (e as Map<String, dynamic>)['page'] as int,
              surah: e['surah'] as int,
              ayah: e['ayah'] as int,
            ))
        .toList();
    juzs = (decoded['juzs'] as List)
        .map((e) => MushafAnchor(
              number: (e as Map<String, dynamic>)['juz'] as int,
              surah: e['surah'] as int,
              ayah: e['ayah'] as int,
            ))
        .toList();
  }

  /// The (surah, ayah) refs a Madani page covers: from its start
  /// anchor up to (not including) the next page's start anchor.
  static List<(int surah, int ayah)> pageAyahs(int page) {
    if (pages.isEmpty || page < 1 || page > pages.length) return const [];
    final start = pages[page - 1];
    final end = page < pages.length ? pages[page] : null;
    final refs = <(int, int)>[];
    var s = start.surah;
    var a = start.ayah;
    while (true) {
      if (end != null && s == end.surah && a == end.ayah) break;
      refs.add((s, a));
      final count = QuranLibrary.surah(s)?.ayahs ?? 0;
      a += 1;
      if (a > count) {
        s += 1;
        a = 1;
        if (s > 114) break;
      }
      if (end == null && s > 114) break;
      if (refs.length > 700) break; // safety net, never expected
    }
    return refs;
  }

  /// The page a (surah, ayah) falls on.
  static int pageOf(int surah, int ayah) {
    var result = 1;
    for (final p in pages) {
      if (p.surah < surah || (p.surah == surah && p.ayah <= ayah)) {
        result = p.number;
      } else {
        break;
      }
    }
    return result;
  }

  /// The juz a (surah, ayah) falls in.
  static int juzOf(int surah, int ayah) {
    var result = 1;
    for (final j in juzs) {
      if (j.surah < surah || (j.surah == surah && j.ayah <= ayah)) {
        result = j.number;
      } else {
        break;
      }
    }
    return result;
  }
}
