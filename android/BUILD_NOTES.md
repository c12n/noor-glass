# Noor Glass Android | build notes

## Route decision: Flutter port with Material 3 Expressive styling

The preferred route was native Kotlin with Jetpack Compose and Media3. This build takes the documented fallback route, for concrete reasons:

* This VM has no JVM, no Kotlin compiler, no Gradle and no Android SDK installed (verified 2026-11-12: `java`, `kotlinc`, `gradle`, `sdkmanager` all absent). A Compose project written here could not be compiled or even syntax checked at all in this run, so it would ship completely unverified.
* A full Flutter toolchain IS present (Flutter 3.47.8, Dart 3.13.7 at ~/workspace/.sdk/flutter), and the reference implementation in Prayer YEG is Flutter. The port reuses that proven engine (player, downloads, media session handler) and is verified here with `flutter analyze` (no errors) and `flutter test` (all passing).
* What differs from a Compose build: the UI is Flutter widgets, not Compose; Material 3 Expressive is applied as styling (dynamic color via the dynamic_color package, harmonized schemes, 28 dp card shapes, pill buttons, floating pill mini player, emphasized type scale) rather than native Compose Expressive components and motion; background audio uses just_audio plus audio_service (the same media session stack Prayer YEG ships) instead of Media3/ExoPlayer directly. Feature behavior is carried over 1:1 from the reference.

A Compose rewrite remains possible later on a machine with the Android toolchain; the data files, persistence keys (quran.*) and feature set are identical either way.

## Adaptations from the Prayer YEG reference

* Copied as the engine: quran_models.dart, quran_player.dart, quran_downloads.dart, quran_audio_handler.dart from ~/workspace/alrashid-widget/flutter/lib/.
* Removed from quran_player.dart: the Prayer YEG Continue Listening widget MethodChannel ('alrashid/widgets') and its shared-preferences widget snapshot writes. Noor Glass 1.0.0 has no home screen widget.
* Rewritten for the standalone app: main.dart (shell, theme, audio_service channel id com.c12n.noorglass.audio) and quran_pages.dart (the reference pages depended on Prayer YEG strings, layout and tab navigation files; the Noor Glass pages implement the same screens against the same engine with no Prayer YEG dependencies).
* Data: assets/quran/ holds copies of shared-data surahs.json, quran_text.json and en_durations.json.

## Verification (this machine)

* `flutter pub get`: resolved, 56 dependencies.
* `flutter analyze`: no errors and no warnings after cleanup; remaining items are info-level lints (deprecated Radio groupValue usage carried from the reference style, two infos in quran_models.dart).
* `flutter test`: 3 tests pass (catalogue: 114 surahs, 4 reciters, audio base URL, English URL format; text: 6,236 ayahs with per-surah counts; timing: character-weighted ayah estimates and duration formatting).

## APK build: attempted locally, blocked by this sandbox, CI workflow is the build route

No APK was produced in this VM. What was done, with evidence:

* Toolchain installed from direct downloads (curl through the egress proxy works): Temurin JDK 17.0.21 at ~/workspace/.sdk/jdk17, Android SDK at ~/workspace/.sdk/android-sdk (platform-tools 37.0.3, platforms android-35 and android-36, build-tools 35.0.0 and 36.0.0, license files written). Flutter configured against it (`flutter config --android-sdk`).
* Two Java download paths fail against this sandbox's egress proxy with a JDK CONNECT tunneling exception (`java.util.NoSuchElementException` at `HttpURLConnection.doTunneling0`): sdkmanager (so SDK packages were installed from the official zips listed in repository2-3.xml instead) and the Gradle wrapper downloader (so Gradle 9.3.1 was downloaded with curl and seeded into the wrapper dists folder; note the JVM user.home here is /root while $HOME is /home/hatch, which also had to be aligned via GRADLE_USER_HOME).
* The remaining blocker: the Gradle daemon JVM starts, writes its greeting, then is terminated externally before the client can dispatch the build (`Could not dispatch a message to the daemon`; daemon log ends with "Daemon vm is shutting down... terminated in response to a user interrupt" plus a file-lock contention handler error on shutdown). Reproduced with the standard daemon, with `--no-daemon`, and with matched JVM options intended to force in-process execution (Gradle 9 still forks a single-use daemon). Plain loopback TCP between local processes works (verified with a Python socket pair), so this is specific to the forked Gradle daemon in this sandbox, not a project problem.
* The exact Gradle invocation Flutter generates was captured from `flutter build apk --release -v` and run directly against the extracted Gradle binary; it reaches the same daemon dispatch failure, confirming the failure is at daemon startup, before any project code, plugin or dependency is evaluated. Nothing in the failure implicates the app sources, which `flutter analyze` and `flutter test` verify independently.
* Build route: .github/workflows/build-apk.yml (GitHub hosted runner, JDK 17, Flutter stable) runs pub get, analyze, test and `flutter build apk --release`, and uploads the APK as an artifact. That is the same route Prayer YEG's Android builds use.
* Minor project change made for constrained builders: android/gradle.properties heap lowered from the template -Xmx8G to -Xmx3G.

## Phase 2 additions (version 1.1.0)

* New Dart modules: app_theme.dart (presets, settings, contrast guards, launcher icon channel), feature_pages.dart (Mushaf, search, playlists, khatmah, theme settings), quran_words.dart, tafsir_service.dart, playlists.dart, khatmah.dart, daily_ayah.dart. No new pub dependencies; tafsir uses dart:io HttpClient, everything else is bundled assets or shared preferences.
* Data added under assets/quran/: mushaf_meta.json (AlQuranCloud meta, 604 page anchors and 30 juz anchors), word_by_word.json (Quran.com API v4, 77,429 words over 6,236 ayahs). quran_text.json gained the French Hamidullah text per ayah (AlQuranCloud edition fr.hamidullah). surahs.json gained the two Sudanese reciters with narration labels, per reciter base URL and padding flags, and probed durations.
* The fixed QuranThemeColors palette from the Prayer YEG port is gone; all Quran surfaces take the Material 3 scheme built from AppThemeSettings (or the Material You dynamic scheme when enabled and available, with the accent still applied). The Now Playing page renders its sleeve as a gradient of the theme primary. Widget colors are always written as flat effective hexes under appearance.widgetTheme.home.* in FlutterSharedPreferences so the Kotlin widgets can read them; modes "match" and "separate" mirror Prayer YEG Android (appearance.* plus appearance.partTheme.home / appearance.widgetTheme.home.* keys).
* Native (Kotlin, framework APIs only, no new Gradle dependencies; compiles first in CI): MainActivity hosts the noorglass/reminders and noorglass/icons method channels; DailyAyahNative reimplements the Dart daily pick rule (local epoch day mod 6236 over the ayah counts); DailyAyahWidget and ContinueListeningWidget read the FlutterSharedPreferences snapshot keys (flutter.widget.*) the player writes on position saves; the reminder uses AlarmManager.setInexactRepeating (no exact alarm permission) with a boot receiver; launcher icons switch via activity aliases (the LAUNCHER filter moved from MainActivity to 8 aliases, IconDefault enabled by default). Alternate icon PNGs are the stock artwork with the background recolored per theme family and the gold artwork preserved (PIL).
* Known limits, stated plainly: all Kotlin in this phase is compile-verified only by CI (the local Gradle daemon blocker above still stands, so no local APK). Word timing highlighting is estimated. Tafsir needs a network connection the first time each ayah is opened. The Continue Listening widget refreshes on the system widget schedule, not in real time.
* Phase 2 verification on this machine: `flutter analyze` reports no errors and no warnings (11 info-level lints remain, the same carried phase 1 style items). `flutter test`: 10 tests pass, covering the 6 reciter catalogue with the Sudanese mp3quran URL patterns and probed durations (surah 1: Noreen 62 s, Zain 43 s), per ayah audio support flags and global ayah numbering, French text present for all 6,236 ayahs, Mushaf meta (604 pages, pageOf(112,1) = 604, juzOf(78,1) = 30), word by word counts (1:1 = 4 words, 2:255 = 50), the deterministic daily pick, and playlist / khatmah math. Note: /tmp on this VM is a 512 MB tmpfs; large scratch downloads there (sample MP3s) can fill it and make flutter test fail with "No space left on device" while copying the test dill.
