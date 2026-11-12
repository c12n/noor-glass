//
//  ContentView.swift
//  Noor Glass
//
//  Root shell: an iOS 26 Liquid Glass tab bar (the system glass tab
//  bar, minimizing on scroll) with Library, Bookmarks and About
//  tabs, and the glass mini player as the tab bar's bottom
//  accessory whenever a surah is loaded. Tapping the mini player
//  opens Now Playing as a sheet.
//
//  Copyright (c) 2026 c12n Apps
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var player: QuranPlayer
    @EnvironmentObject private var bookmarks: QuranBookmarks
    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    /// Phase 2 theming: owns the palette for the whole tree; the
    /// root `.id` below re-renders every surface on a theme change.
    @StateObject private var themeStore = AppThemeStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Library", systemImage: "books.vertical.fill", value: 0) {
                QuranLibraryView(embeddedInTab: true)
            }
            Tab("Mushaf", systemImage: "book", value: 1) {
                MushafView(openPlayer: { showNowPlaying = true })
            }
            Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) {
                QuranSearchView(openPlayer: { showNowPlaying = true })
            }
            Tab("Bookmarks", systemImage: "bookmark.fill", value: 3) {
                BookmarksTabView(openPlayer: { showNowPlaying = true })
            }
            Tab("You", systemImage: "person.crop.circle.fill", value: 4) {
                AboutView(openPlayer: { showNowPlaying = true })
            }
        }
        .environmentObject(themeStore)
        .preferredColorScheme(themeStore.mode.colorScheme)
        .tint(Theme.green)
        .id(themeStore.revision)
        .onAppear { DailyReminder.reschedule() }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if player.currentSurah != nil {
                MiniPlayerView { showNowPlaying = true }
                    .padding(.horizontal, 8)
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
    }
}

// MARK: - Bookmarks tab

/// Every bookmarked ayah, newest first. Tapping one plays its surah
/// and seeks to the ayah's estimated start (the same behaviour as
/// the library's Bookmarks chip), then opens Now Playing.
private struct BookmarksTabView: View {
    @EnvironmentObject private var player: QuranPlayer
    @EnvironmentObject private var bookmarks: QuranBookmarks
    let openPlayer: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if bookmarks.bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("In Now Playing, open the lyrics and long-press any ayah to bookmark it."))
                }
                ForEach(bookmarks.bookmarks) { bookmark in
                    Button {
                        playBookmark(bookmark)
                    } label: {
                        bookmarkRow(bookmark)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            bookmarks.remove(bookmark)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Bookmarks")
        }
    }

    private func bookmarkRow(_ bookmark: QuranBookmark) -> some View {
        let surah = QuranLibrary.surah(bookmark.surah)
        let ayahText = QuranTextData.ayahsBySurah[bookmark.surah]?
            .first { $0.n == bookmark.ayah }
        return HStack(spacing: 12) {
            Image(systemName: "bookmark.fill")
                .font(.subheadline)
                .foregroundStyle(Theme.adaptiveGold)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(surah?.english ?? "Surah \(bookmark.surah)") | Ayah \(bookmark.ayah)")
                    .font(.headline)
                if let ayahText {
                    Text(ayahText.en)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.green)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func playBookmark(_ bookmark: QuranBookmark) {
        guard QuranLibrary.surah(bookmark.surah) != nil else { return }
        player.play(surahNumber: bookmark.surah,
                    queue: QuranLibrary.surahs.map(\.number),
                    contextLabel: "Bookmarks")
        let ayahs = QuranTextData.ayahsBySurah[bookmark.surah] ?? []
        if let index = ayahs.firstIndex(where: { $0.n == bookmark.ayah }) {
            player.seek(to: quranAyahStartTime(ayahs, index: index,
                                               duration: player.duration))
        }
        openPlayer()
    }
}

// MARK: - About tab

/// Voice picker shortcut, listening stats and credits. The full
/// reciter / language pickers also live in the library Options sheet.
private struct AboutView: View {
    @EnvironmentObject private var player: QuranPlayer
    @EnvironmentObject private var themeStore: AppThemeStore
    let openPlayer: () -> Void

    @State private var reminderOn = DailyReminder.enabled
    @State private var reminderTime: Date =
        Calendar.current.date(bySettingHour: DailyReminder.hour,
                              minute: DailyReminder.minute,
                              second: 0, of: .now) ?? .now

    private var reminderEnabledBinding: Binding<Bool> {
        Binding(get: { reminderOn }, set: { newValue in
            reminderOn = newValue
            DailyReminder.enabled = newValue
            DailyReminder.reschedule()
        })
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(get: { reminderTime }, set: { newValue in
            reminderTime = newValue
            let parts = Calendar.current.dateComponents([.hour, .minute],
                                                        from: newValue)
            DailyReminder.hour = parts.hour ?? 7
            DailyReminder.minute = parts.minute ?? 0
            DailyReminder.reschedule()
        })
    }

    private var listenedLabel: String {
        let total = Int(player.totalSecondsListened.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Noor Glass")
                            .font(.title2.weight(.bold))
                        Text("The Holy Quran | Listen, read along, memorize")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    DailyAyahCard(openPlayer: openPlayer)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("Your Quran") {
                    NavigationLink {
                        KhatmahView()
                    } label: {
                        Label("Khatmah Planner", systemImage: "calendar.badge.checkmark")
                    }
                    NavigationLink {
                        PlaylistsView()
                    } label: {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                    .navigationDestination(for: QuranPlaylist.self) { playlist in
                        PlaylistDetailView(playlistID: playlist.id,
                                           openPlayer: openPlayer)
                    }
                    LabeledContent("Listening streak",
                                   value: "\(player.listeningStreakDays) day\(player.listeningStreakDays == 1 ? "" : "s")")
                }

                Section("Appearance") {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("Theme: \(NoorAppearance.preset(id: themeStore.presetId)?.name ?? "Custom")",
                              systemImage: "paintpalette")
                    }
                }

                Section("Daily Ayah reminder") {
                    Toggle("Daily reminder", isOn: reminderEnabledBinding)
                    if reminderOn {
                        DatePicker("Time", selection: reminderTimeBinding,
                                   displayedComponents: .hourAndMinute)
                    }
                    Text("One notification a day with the Daily Ayah, at your chosen time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Audio language") {
                    Picker("Audio language", selection: Binding(
                        get: { player.audioLanguage },
                        set: { player.setAudioLanguage($0) }
                    )) {
                        Text("Arabic").tag(QuranPlayer.AudioLanguage.arabic)
                        Text("English (Ibrahim Walk)").tag(QuranPlayer.AudioLanguage.english)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                if player.audioLanguage == .arabic {
                    Section("Reciter") {
                        Picker("Reciter", selection: Binding(
                            get: { player.reciterId },
                            set: { player.setReciter($0) }
                        )) {
                            ForEach(QuranLibrary.reciters) { reciter in
                                Text(reciter.narration.map {
                                    "\(reciter.name) | \($0)"
                                } ?? reciter.name).tag(reciter.id)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }

                Section("Listening") {
                    LabeledContent("Surahs completed", value: "\(player.completedSurahsTotal)")
                    LabeledContent("Time listened", value: listenedLabel)
                    LabeledContent("Favourites", value: "\(player.favorites.count)")
                }

                Section("Credits") {
                    Text("Arabic recitation | Mishary Rashid Alafasy, Abdul Basit Abdul Samad, Abdullah Basfar and Aziz Alili, streamed from the Islamic Network CDN. Noreen Mohammad Siddiq (Ad-Duri 'an Abi 'Amr) and Alzain Mohammad Ahmad (Hafs Murattal), streamed from mp3quran.")
                    Text("French translation | Muhammad Hamidullah, via AlQuranCloud. Tafsir and word-by-word data | Quran.com (Tafsir Ibn Kathir, abridged).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("English narration | Ibrahim Walk, via QuranicAudio.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("English translation | Saheeh International. Arabic text | Uthmani script.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Copyright (c) 2026 c12n Apps")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("About")
        }
    }
}
