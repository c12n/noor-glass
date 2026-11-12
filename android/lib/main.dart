// Noor Glass | Android edition (Flutter, Material 3 Expressive styling).
//
// A standalone Quran app extracted from Prayer YEG's Quran layer:
// the surah library, reciter and English narration playback with
// background audio and lock screen controls, lyrics with tap to
// seek, the memorization loop, ayah bookmarks, offline downloads,
// the sleep timer with fade out, and listening statistics.
//
// Phase 2 (1.1.0): full theming on every surface, the two
// Sudanese reciters (mp3quran), per-ayah audio where a source
// supports it, Mushaf read mode, full-text search, word by word,
// tafsir on tap, the Daily Ayah widget + reminder, the Khatmah
// planner, custom playlists and the French translation.
//
// Copyright (c) 2026 c12n Apps.

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'daily_ayah.dart';
import 'khatmah.dart';
import 'playlists.dart';
import 'quran_audio_handler.dart';
import 'quran_downloads.dart';
import 'quran_models.dart';
import 'quran_pages.dart';
import 'quran_player.dart';
import 'quran_words.dart';
import 'tafsir_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QuranLibrary.load();
  unawaited(QuranTextData.load());
  unawaited(MushafMeta.load());
  unawaited(QuranWords.load());
  final prefs = await SharedPreferences.getInstance();
  TafsirService.attachPrefs(prefs);
  await QuranDownloads.ensureInit();
  final downloads = QuranDownloads();
  final bookmarks = QuranBookmarks();
  await bookmarks.load(prefs);
  final themeSettings = await AppThemeSettings.load(prefs);
  final playlists = QuranPlaylists();
  await playlists.load(prefs);
  final khatmah = KhatmahStore();
  await khatmah.load(prefs);
  final reminder = DailyReminderSettings();
  reminder.load(prefs);
  unawaited(reminder.syncNative());
  final player = QuranPlayer();
  // Background audio: the media session foreground service is
  // registered before the player restores its session, so a
  // restored surah is published to the lock screen from the first
  // frame. A failure here must never take the app down with it:
  // playback still works in the foreground without the service.
  final audioHandler = QuranAudioHandler();
  audioHandler.attach(player);
  try {
    await AudioService.init(
      builder: () => audioHandler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.c12n.noorglass.audio',
        androidNotificationChannelName: 'Quran Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
  } catch (_) {
    // Foreground service registration unavailable (for example a
    // test environment): the player still runs in app.
  }
  await player.init(prefs);
  runApp(NoorGlassApp(
    player: player,
    downloads: downloads,
    bookmarks: bookmarks,
    themeSettings: themeSettings,
    playlists: playlists,
    khatmah: khatmah,
    reminder: reminder,
  ));
}

/// Material 3 Expressive theme, themed from the picked palette
/// (app_theme.dart): the preset primary seeds the scheme and the
/// picked accent (contrast-adjusted) drives secondary/tertiary,
/// unless Material You dynamic color is on, in which case the
/// wallpaper scheme wins the primary and the accent still
/// applies to secondary/tertiary. Expressive shape tokens
/// throughout: extra large card corners, pill buttons and a
/// floating mini player, plus the emphasized type scale.
class NoorTheme {
  static ThemeData build(
      ColorScheme? dynamicScheme, Brightness brightness, AppThemeSettings s) {
    final useDynamic = s.dynamicColor && dynamicScheme != null;
    final accent = accentFor(brightness, s);
    final ColorScheme scheme;
    if (useDynamic) {
      scheme = dynamicScheme.harmonized().copyWith(
            secondary: accent,
            tertiary: accent,
            secondaryContainer: accent.withValues(alpha: 0.25),
          );
    } else {
      scheme = ColorScheme.fromSeed(
        seedColor: colorFromHex(s.primaryHex),
        brightness: brightness,
      ).copyWith(
        secondary: accent,
        tertiary: accent,
      );
    }
    const cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(28)),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      cardTheme: const CardThemeData(shape: cardShape, elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class NoorGlassApp extends StatelessWidget {
  final QuranPlayer player;
  final QuranDownloads downloads;
  final QuranBookmarks bookmarks;
  final AppThemeSettings themeSettings;
  final QuranPlaylists playlists;
  final KhatmahStore khatmah;
  final DailyReminderSettings reminder;
  const NoorGlassApp({
    super.key,
    required this.player,
    required this.downloads,
    required this.bookmarks,
    required this.themeSettings,
    required this.playlists,
    required this.khatmah,
    required this.reminder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeSettings,
      builder: (context, _) {
        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            themeSettings.dynamicAvailable =
                lightDynamic != null || darkDynamic != null;
            return MaterialApp(
              title: 'Noor Glass',
              debugShowCheckedModeBanner: false,
              theme: NoorTheme.build(lightDynamic, Brightness.light, themeSettings),
              darkTheme:
                  NoorTheme.build(darkDynamic, Brightness.dark, themeSettings),
              themeMode: themeSettings.mode,
              home: ThemeScope(
                settings: themeSettings,
                child: QuranScope(
                  player: player,
                  downloads: downloads,
                  bookmarks: bookmarks,
                  playlists: playlists,
                  khatmah: khatmah,
                  reminder: reminder,
                  child: const NoorHomeShell(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// The shell: the library as home, a Bookmarks section one tap
/// away, and the Expressive pill mini player floating over both
/// while a surah is loaded.
class NoorHomeShell extends StatefulWidget {
  const NoorHomeShell({super.key});

  @override
  State<NoorHomeShell> createState() => _NoorHomeShellState();
}

class _NoorHomeShellState extends State<NoorHomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [
              QuranLibraryPage(embedded: true),
              BookmarksPage(),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 76,
            child: MiniPlayerBar(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks),
            label: 'Bookmarks',
          ),
        ],
      ),
    );
  }
}
