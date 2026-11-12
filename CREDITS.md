# Credits and Attribution | Noor Glass

This file records where everything used in Noor Glass came from. It is carried over from the Prayer YEG credits, limited to the Quran layer that Noor Glass is extracted from.

## This app

- Noor Glass, designed and developed by c12n Apps. Copyright (c) 2026 c12n Apps.
- The app began as the Quran player of Prayer YEG (c12n/PrayerAppYEG) and was split into a standalone app on 2026-11-12 at the developer's direction.

## Quran text and translation

- Arabic Quran text (Uthmani script): bundled in quran_text.json and shown in the lyrics view. The digital source the text file was taken from is not named in the source repository; see "Origins not documented".
- English translation of the Quran (full text): Saheeh International, bundled in quran_text.json.
- French translation of the Quran (full text): Muhammad Hamidullah, bundled in quran_fr.json via the AlQuranCloud API (fr.hamidullah edition), added in phase 2.
- Mushaf page mapping (the 604 pages of the Madani mushaf, with page and juz per ayah): generated from the AlQuranCloud quran-uthmani edition's per-ayah page and juz fields, bundled as mushaf_pages.json.

## Audio

- Arabic Quran recitation (streaming and downloads): audio files are served by the Islamic Network CDN (cdn.islamic.network), at 128 kbps per surah.
- Arabic reciters, as named in the bundled surah catalogue (surahs.json): Mishary Rashid Alafasy, Abdul Basit Abdul Samad, Abdullah Basfar, and Aziz Alili.
- English Quran narration: narrated by Ibrahim Walk, audio hosted by QuranicAudio (download.quranicaudio.com).
- Sudanese recitations, added in phase 2: audio files are served by the mp3quran CDN (cdn.mp3quran.net). Reciters: Noreen Mohammad Siddiq, narration Ad-Duri 'an Abi 'Amr (the Sudanese riwaya), and Alzain Mohammad Ahmad, narration Hafs 'an Asim, Murattal style. Both complete over all 114 surahs.
- Per-ayah audio, added in phase 2: individual ayah files served by the Islamic Network CDN for the reciters it carries per ayah (Mishary Rashid Alafasy, Abdul Basit Abdul Samad, Abdullah Basfar).

## Reference data fetched in the app

- Tafsir on tap: Tafsir Ibn Kathir (Abridged), English, fetched per ayah from the Quran.com API (tafsir resource 169) and cached on device.
- Word-by-word translation and transliteration: fetched per surah from the Quran.com API (verses by chapter, with words) and cached on device.

## Origins not documented

- The digital source of the bundled Arabic Quran text file (quran_text.json), beyond its Uthmani script.

If you are a creator named in this file, or you hold rights in anything listed above, please open an issue in this repository so the record can be corrected or completed.
