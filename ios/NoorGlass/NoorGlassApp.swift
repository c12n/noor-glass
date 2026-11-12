//
//  NoorGlassApp.swift
//  Noor Glass
//
//  Standalone Quran player, extracted from Prayer YEG's Quran layer.
//  One player engine, one download store and one bookmarks store for
//  the whole app. The player's init restores the last session
//  (paused, never autoplays). Background audio is declared in
//  Info.plist (UIBackgroundModes: audio) and the player configures
//  the AVAudioSession for playback + lock-screen controls.
//
//  Copyright (c) 2026 c12n Apps
//

import SwiftUI

@main
struct NoorGlassApp: App {
    @StateObject private var quranPlayer = QuranPlayer()
    @StateObject private var quranDownloads = QuranDownloads()
    @StateObject private var quranBookmarks = QuranBookmarks()
    @StateObject private var quranPlaylists = QuranPlaylists()
    @StateObject private var ayahAudioPlayer = AyahAudioPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(quranPlayer)
                .environmentObject(quranDownloads)
                .environmentObject(quranBookmarks)
                .environmentObject(quranPlaylists)
                .environmentObject(ayahAudioPlayer)
                .tint(Theme.green)
        }
    }
}
