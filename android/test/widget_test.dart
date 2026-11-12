// Noor Glass smoke tests: the bundled Quran catalogue loads and
// the ayah timing estimates behave.

import 'package:flutter_test/flutter_test.dart';
import 'package:noor_glass/daily_ayah.dart';
import 'package:noor_glass/khatmah.dart';
import 'package:noor_glass/playlists.dart';
import 'package:noor_glass/quran_models.dart';
import 'package:noor_glass/quran_words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalogue loads with 114 surahs and 6 reciters', () async {
    await QuranLibrary.load();
    expect(QuranLibrary.surahs.length, 114);
    expect(QuranLibrary.reciters.length, 6);
    expect(QuranLibrary.surah(1)?.english, 'Al-Fatiha');
    expect(QuranLibrary.surah(114)?.english, 'An-Naas');
    expect(QuranLibrary.audioBase,
        'https://cdn.islamic.network/quran/audio-surah/128');
    expect(QuranLibrary.englishStreamUrl(2),
        'https://download.quranicaudio.com/quran/ibrahim_walk/002.mp3');
  });

  test('sudanese reciters stream from mp3quran with padded names', () async {
    await QuranLibrary.load();
    final noreen = QuranLibrary.reciter('noreen-siddiq');
    final zain = QuranLibrary.reciter('zain-ahmad');
    expect(noreen, isNotNull);
    expect(zain, isNotNull);
    expect(noreen!.narration, contains('Ad-Duri'));
    expect(zain!.narration, contains('Hafs'));
    expect(QuranLibrary.streamUrl(1, 'noreen-siddiq'),
        'https://cdn.mp3quran.net/audio/noreen-siddiq/r1/001.mp3');
    expect(QuranLibrary.streamUrl(36, 'zain-ahmad'),
        'https://cdn.mp3quran.net/audio/zain-ahmad/r1/036.mp3');
    expect(QuranLibrary.streamUrl(114, 'zain-ahmad'),
        'https://cdn.mp3quran.net/audio/zain-ahmad/r1/114.mp3');
    // Durations derived from HEAD content-length probes at the
    // measured constant bitrates (128k / 96k).
    expect(QuranLibrary.durationSeconds(1, 'noreen-siddiq'), 62);
    expect(QuranLibrary.durationSeconds(114, 'noreen-siddiq'), 32);
    expect(QuranLibrary.durationSeconds(1, 'zain-ahmad'), 43);
    expect(QuranLibrary.durationSeconds(36, 'zain-ahmad'), 795);
    // Islamic Network reciters keep the unpadded per-surah URL.
    expect(QuranLibrary.streamUrl(2, 'ar.alafasy'),
        'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/2.mp3');
  });

  test('per-ayah audio only where the CDN supports it', () async {
    await QuranLibrary.load();
    expect(QuranLibrary.supportsPerAyahAudio('ar.alafasy'), isTrue);
    expect(QuranLibrary.supportsPerAyahAudio('noreen-siddiq'), isFalse);
    expect(QuranLibrary.supportsPerAyahAudio('zain-ahmad'), isFalse);
    expect(QuranLibrary.globalAyahNumber(1, 1), 1);
    expect(QuranLibrary.globalAyahNumber(2, 1), 8);
    expect(QuranLibrary.globalAyahNumber(114, 6), 6236);
    expect(QuranLibrary.perAyahUrl(2, 255, 'ar.alafasy'),
        'https://cdn.islamic.network/quran/audio/128/ar.alafasy/262.mp3');
  });

  test('french translation is bundled for every ayah', () async {
    await QuranTextData.load();
    var withFrench = 0;
    for (final list in QuranTextData.ayahsBySurah.values) {
      for (final a in list) {
        if (a.fr.isNotEmpty) withFrench++;
        expect(a.translation('fr'), a.fr);
        expect(a.translation('en'), a.en);
      }
    }
    expect(withFrench, 6236);
    expect(QuranTextData.ayahsBySurah[1]!.first.fr, contains("nom d'Allah"));
  });

  test('mushaf meta covers 604 pages and 30 juz', () async {
    await MushafMeta.load();
    expect(MushafMeta.pages.length, 604);
    expect(MushafMeta.juzs.length, 30);
    expect(MushafMeta.pageOf(1, 1), 1);
    expect(MushafMeta.pageOf(2, 1), 2);
    expect(MushafMeta.pageOf(112, 1), 604);
    expect(MushafMeta.pageOf(114, 6), 604);
    expect(MushafMeta.juzOf(1, 1), 1);
    expect(MushafMeta.juzOf(78, 1), 30);
    expect(MushafMeta.pageAyahs(1).length, 7);
    expect(MushafMeta.pageAyahs(604), isNotEmpty);
  });

  test('word by word data loads', () async {
    await QuranWords.load();
    expect(QuranWords.wordsFor(1, 1).length, 4);
    expect(QuranWords.wordsFor(2, 255).length, 50);
    expect(QuranWords.wordsFor(1, 1).first.translation, isNotEmpty);
    final words = QuranWords.wordsFor(2, 255);
    expect(QuranWords.estimatedWordIndex(words, 0), 0);
    expect(QuranWords.estimatedWordIndex(words, 0.999),
        lessThan(words.length));
  });

  test('daily ayah pick is deterministic and in range', () async {
    await QuranLibrary.load();
    final a = DailyAyah.forDate(DateTime(2026, 11, 12));
    final b = DailyAyah.forDate(DateTime(2026, 11, 12));
    expect(a.surah, b.surah);
    expect(a.ayah, b.ayah);
    expect(a.surah, inInclusiveRange(1, 114));
    expect(a.ayah, greaterThanOrEqualTo(1));
    expect(a.ayah,
        lessThanOrEqualTo(QuranLibrary.surah(a.surah)!.ayahs));
  });

  test('playlists and khatmah math', () {
    final store = QuranPlaylists();
    final p = store.create('Test');
    store.addSurah(p, 1);
    store.addSurah(p, 36);
    store.addSurah(p, 36);
    expect(p.surahNumbers, [1, 36]);
    store.moveSurah(p, 1, 0);
    expect(p.surahNumbers, [36, 1]);
    store.removeSurah(p, 36);
    expect(p.surahNumbers, [1]);

    final plan = KhatmahPlan(
      startDate: DateTime(2026, 11, 1),
      targetDays: 30,
      baseline: const {},
    );
    expect(plan.targetDate, DateTime(2026, 11, 30));
    expect(KhatmahStore.totalAyahs, 6236);
  });

  test('quran text loads with 6236 ayahs', () async {
    await QuranTextData.load();
    final total = QuranTextData.ayahsBySurah.values
        .fold<int>(0, (sum, list) => sum + list.length);
    expect(total, 6236);
    expect(QuranTextData.ayahsBySurah[1]?.length, 7);
    expect(QuranTextData.ayahsBySurah[2]?.length, 286);
  });

  test('ayah timing estimates are monotonic', () {
    final ayahs = [
      const QuranAyahText(n: 1, ar: 'aaaa', en: 'a'),
      const QuranAyahText(n: 2, ar: 'aaaaaaaa', en: 'b'),
      const QuranAyahText(n: 3, ar: 'aaaa', en: 'c'),
    ];
    expect(quranAyahStartTime(ayahs, 0, 16), 0);
    expect(quranAyahStartTime(ayahs, 1, 16), 4);
    expect(quranAyahStartTime(ayahs, 2, 16), 12);
    expect(quranCurrentAyahIndex(ayahs, 5, 16), 1);
    expect(QuranLibrary.formatDuration(89), '1:29');
    expect(QuranLibrary.formatDuration(7613), '2:06:53');
  });
}
