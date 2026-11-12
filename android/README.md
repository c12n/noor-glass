# Noor Glass | Android

The Android edition of Noor Glass, a standalone Quran listening and reading app. Extracted from Prayer YEG's Quran layer and rebuilt as its own app.

Copyright (c) 2026 c12n Apps

## Features

* Surah library with search, Favorites and Downloaded filters, and Ramadan and Eid collections
* Four Arabic reciters (Mishary Rashid Alafasy, Abdul Basit Abdul Samad, Abdullah Basfar, Aziz Alili) streamed from the Islamic Network CDN, plus English narration by Ibrahim Walk via QuranicAudio
* Now Playing with queue, Play Next, Add to Queue, shuffle and repeat
* Lyrics for all 6,236 ayahs (Arabic Uthmani text, Saheeh International English) with tap an ayah to seek
* Memorization loop: repeat one ayah or the current ayah a set number of times or until stopped
* Ayah bookmarks
* Bulk downloads and a downloads manager for offline listening
* Sleep timer with fade out, including end of surah
* Listening statistics: time listened and surahs completed
* Background audio with lock screen and notification controls (audio_service media session)

## Design

Material 3 Expressive styling on Flutter's Material 3 base: dynamic color from the device wallpaper (Android 12 and up) with a deep green and gold seed fallback, extra large rounded card shapes (28 dp), pill buttons, a floating pill mini player, and an emphasized type scale. Flutter does not expose every native Material 3 Expressive component (for example the Compose expressive motion and shape system), so this is Expressive styling rather than a Jetpack Compose implementation. See BUILD_NOTES.md for the route decision.

## App identity

| Field | Value |
| --- | --- |
| Display name | Noor Glass |
| Package / applicationId | com.c12n.noorglass |
| Version | 1.0.0 (versionCode 1) |
| minSdk | 26 |
| Permissions | INTERNET, ACCESS_NETWORK_STATE, WAKE_LOCK, FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK, POST_NOTIFICATIONS |

## Building

Requires Flutter (stable) and JDK 17 with the Android SDK.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The APK lands at `build/app/outputs/flutter-apk/app-release.apk`. A GitHub Actions workflow is included at `.github/workflows/build-apk.yml` (move it to the repository root workflows folder when publishing, as its header notes). Release builds are currently signed with the debug key until a c12n release keystore is configured.

## Phase 2 (version 1.1.0)

* Sudanese recitations: Noreen Mohammad Siddiq (narration Ad-Duri 'an Abi 'Amr, the Sudanese riwaya, labelled in the reciter picker) and Alzain Mohammad Ahmad (Hafs 'an 'Asim, Murattal), both streaming per surah from the mp3quran CDN with zero padded file names. Their durations were derived by HEAD probing all 114 files per reciter and dividing by the measured constant bitrate (128 kbps and 96 kbps after the fixed ID3 overhead), then written into surahs.json like the other reciters.
* Full theming: 8 theme presets (Mosque Green default, Ocean Depths, Desert Dunes, Emerald Night, Crimson Dusk, Sapphire Noor, Plum Velvet, High Contrast) with appearance mode (System, Light, Dark), main color and accent pickers with a custom color option and per surface contrast adjustment, a Material You dynamic color toggle, widget colors (match the theme or a separate widget palette), and alternate launcher icons tinted per theme family. The theme reaches every surface: library, Now Playing sleeve, lyrics including the playing ayah card, mini player, Mushaf reader and both home screen widgets.
* Mushaf read mode: the 604 page Madani mapping with page and juz navigation, flowing page text or ayah rows, optional translation, and per ayah actions (play from here, bookmark, tafsir, open in lyrics).
* Full text search across the Arabic (diacritic insensitive), English and French texts.
* Per ayah audio where the source supports it: Mishary Al-Afasy via the Islamic Network per ayah CDN (the other Islamic Network reciters return 403 on that CDN in probes, and the Sudanese recitations are per surah only, so those keep the estimate timing).
* Word by word translation and transliteration per ayah (Quran.com data, bundled), with estimated highlighting from the playback position; the timing is estimated and the app says so.
* Tafsir on tap: Ibn Kathir (Abridged) in English, fetched per ayah from the Quran.com API on demand and cached on device (no bulk dataset is published; nothing is faked offline).
* Daily Ayah home screen widget plus a Continue Listening widget, both in the widget theme colors, and an optional daily reminder notification at a chosen time.
* Khatmah planner: start a cycle of 7 to 90 days; progress is measured from your listening statistics snapshot at the start, with a daily portion list.
* Custom playlists: create, rename, reorder, play all, shuffle; add any surah from its menu.
* French translation (Muhammad Hamidullah, via AlQuranCloud) bundled for all 6,236 ayahs and switchable in the lyrics and Options screens.

Not in this phase by design: Android Auto and Wear OS.
