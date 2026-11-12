# Noor Glass | iOS

Native SwiftUI Quran player for iOS 26, built with the Liquid Glass design: glass tab bar, glass mini player, glass Now Playing surfaces.

## Features

Library and search | 6 Arabic reciters plus English narration by Ibrahim Walk | Sudanese recitations: Noreen Mohammad Siddiq (Ad-Duri 'an Abi 'Amr) and Alzain Mohammad Ahmad (Hafs Murattal) from mp3quran | Now Playing with lyrics, tap an ayah to seek | Memorization loop | Ayah bookmarks | Favourites | Bulk downloads and download manager | Sleep timer with fade out | Listening stats | Playback queue | Background audio with lock screen controls

Phase 2: Mushaf page reader (604 pages, Madani mushaf) | Full-text search in Arabic, English and French | Per-ayah audio where the CDN serves it | Word-by-word translation and transliteration | Tafsir Ibn Kathir on tap | Daily Ayah widgets (Home Screen and Lock Screen) plus a daily reminder | Khatmah planner | Custom playlists | French translation (Hamidullah) switchable in the lyrics | Full theming: 8 theme presets, appearance mode, accent picker, widget colors and themed alternate icons, applied to every surface

Arabic text: Uthmani script. English translation: Saheeh International. French translation: Muhammad Hamidullah. Arabic audio: the Islamic Network CDN and mp3quran. English audio: QuranicAudio.

## Build

Open `NoorGlass.xcodeproj`, scheme `NoorGlass`. Deployment target iOS 26.0, bundle ID `com.c12n.noorglass`, version 1.0.0 (2). The widget extension target is `NoorGlassWidgets` (bundle ID `com.c12n.noorglass.widgets`).

Tools: `tools/make_icons.py` regenerates the app icon family and picker previews; `tools/probe_sudanese_durations.py` documents how the Sudanese reciters' per-surah durations were derived.

Copyright (c) 2026 c12n Apps
