//
//  FeatureViews.swift
//  Noor Glass
//
//  Phase-2 feature surfaces: the Daily Ayah card, custom playlists
//  (feature 8), the Khatmah planner (feature 7), word-by-word
//  (feature 4), the tafsir sheet (feature 5) and the Appearance
//  settings for the full theming layer.
//
//  Copyright (c) 2026 c12n Apps
//

import SwiftUI

// MARK: - Daily Ayah card (feature 6)

struct DailyAyahCard: View {
    @EnvironmentObject private var player: QuranPlayer
    let openPlayer: () -> Void

    private var ayah: DailyAyah { DailyAyahs.ayah(for: .now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Daily Ayah", systemImage: "sun.max.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.adaptiveGold)
                Spacer()
                Text(ayah.reference)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Text(ayah.arabic)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .lineSpacing(6)
            Text(ayah.english)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            Button {
                player.play(surahNumber: ayah.chapter,
                            queue: QuranLibrary.surahs.map(\.number),
                            contextLabel: "Daily Ayah")
                let ayahs = QuranTextData.ayahsBySurah[ayah.chapter] ?? []
                if let index = ayahs.firstIndex(where: { $0.n == ayah.verse }) {
                    player.seek(to: quranAyahStartTime(
                        ayahs, index: index, duration: player.duration))
                }
                openPlayer()
            } label: {
                Label("Listen", systemImage: "play.fill")
                    .font(.subheadline.weight(.bold))
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.gold)
            .foregroundStyle(Theme.deepGreen)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [QuranTheme.deepGreen, QuranTheme.midGreen,
                         QuranTheme.darkestGreen],
                startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Playlists (feature 8)

struct PlaylistsView: View {
    @EnvironmentObject private var playlists: QuranPlaylists
    @State private var showingCreate = false
    @State private var newName = ""

    var body: some View {
        List {
            if playlists.playlists.isEmpty {
                ContentUnavailableView(
                    "No playlists yet",
                    systemImage: "music.note.list",
                    description: Text("Create a playlist, or add a surah from its menu in the library."))
            }
            ForEach(playlists.playlists) { playlist in
                NavigationLink(value: playlist) {
                    HStack {
                        Image(systemName: "music.note.list")
                            .foregroundStyle(Theme.green)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(playlist.name).font(.headline)
                            Text("\(playlist.surahNumbers.count) surahs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    playlists.delete(id: playlists.playlists[index].id)
                }
            }
        }
        .navigationTitle("Playlists")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newName = ""
                    showingCreate = true
                } label: {
                    Label("New playlist", systemImage: "plus")
                }
            }
        }
        .alert("New playlist", isPresented: $showingCreate) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { playlists.create(name: name) }
            }
        }
    }
}

struct PlaylistDetailView: View {
    @EnvironmentObject private var player: QuranPlayer
    @EnvironmentObject private var playlists: QuranPlaylists
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdd = false
    let playlistID: String
    let openPlayer: () -> Void

    private var playlist: QuranPlaylist? { playlists.playlist(id: playlistID) }

    var body: some View {
        Group {
            if let playlist {
                List {
                    Section {
                        Button {
                            playAll(playlist, shuffle: false)
                        } label: {
                            Label("Play all", systemImage: "play.fill")
                        }
                        Button {
                            playAll(playlist, shuffle: true)
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        Button {
                            showingAdd = true
                        } label: {
                            Label("Add surahs", systemImage: "plus.circle")
                        }
                    }
                    Section {
                        ForEach(playlist.surahNumbers, id: \.self) { number in
                            if let surah = QuranLibrary.surah(number) {
                                Button {
                                    player.play(
                                        surahNumber: number,
                                        queue: playlist.surahNumbers,
                                        contextLabel: playlist.name)
                                    openPlayer()
                                } label: {
                                    PlaylistSurahRow(surah: surah)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                playlists.remove(
                                    surahNumber: playlist.surahNumbers[index],
                                    from: playlistID)
                            }
                        }
                    }
                    Section {
                        Button(role: .destructive) {
                            playlists.delete(id: playlistID)
                            dismiss()
                        } label: {
                            Label("Delete playlist", systemImage: "trash")
                        }
                    }
                }
            } else {
                ContentUnavailableView("Playlist gone", systemImage: "music.note.list")
            }
        }
        .navigationTitle(playlist?.name ?? "Playlist")
        .sheet(isPresented: $showingAdd) {
            AddSurahsView(playlistID: playlistID)
        }
    }

    private func playAll(_ playlist: QuranPlaylist, shuffle: Bool) {
        guard let first = playlist.surahNumbers.first else { return }
        if shuffle { player.shuffle = true }
        player.play(surahNumber: first, queue: playlist.surahNumbers,
                    contextLabel: playlist.name)
        openPlayer()
    }
}

/// Multi-select surah picker for a playlist.
struct AddSurahsView: View {
    @EnvironmentObject private var playlists: QuranPlaylists
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    let playlistID: String

    private var playlist: QuranPlaylist? { playlists.playlist(id: playlistID) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(QuranLibrary.surahs.filter {
                    search.isEmpty
                        || $0.english.localizedCaseInsensitiveContains(search)
                        || "\($0.number)".hasPrefix(search)
                }) { surah in
                    let included = playlist?.surahNumbers.contains(surah.number) ?? false
                    Button {
                        if included {
                            playlists.remove(surahNumber: surah.number, from: playlistID)
                        } else {
                            playlists.add(surahNumber: surah.number, to: playlistID)
                        }
                    } label: {
                        HStack {
                            PlaylistSurahRow(surah: surah)
                            Spacer()
                            if included {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.green)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Add surahs")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search surahs")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// One compact surah row (number tile, names, ayah count), shared
/// by the playlist views.
struct PlaylistSurahRow: View {
    let surah: QuranSurah

    var body: some View {
        HStack(spacing: 12) {
            Text("\(surah.number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.deepGreen)
                .frame(width: 40, height: 40)
                .background(Theme.adaptiveGold.opacity(0.18),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(surah.english).font(.headline)
                Text("\(surah.meaning) | \(surah.ayahs) ayahs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(surah.arabic)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.deepGreen)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Khatmah planner (feature 7)

/// A khatmah plan on top of the listening stats: progress is the
/// ayahs of surahs completed at least once; the plan turns the
/// remaining ayahs and the chosen number of days into a daily
/// target and shows today's suggested stretch.
struct KhatmahView: View {
    @EnvironmentObject private var player: QuranPlayer
    @AppStorage("khatmah.active") private var active = false
    @AppStorage("khatmah.days") private var planDays = 30
    @AppStorage("khatmah.start") private var startEpoch: Double = 0

    private static let totalAyahs = 6236

    private var completedAyahs: Int { player.khatmahAyahsCompleted }
    private var remainingAyahs: Int { max(0, Self.totalAyahs - completedAyahs) }

    private var daysLeft: Int {
        guard active, startEpoch > 0 else { return planDays }
        let start = Date(timeIntervalSince1970: startEpoch)
        let elapsed = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: .now)).day ?? 0
        return max(1, planDays - elapsed)
    }

    private var dailyTarget: Int {
        guard active else { return 0 }
        return Int(ceil(Double(remainingAyahs) / Double(max(1, daysLeft))))
    }

    /// The next stretch of not-yet-completed surahs, sized to
    /// today's target.
    private var todaysStretch: [(surah: QuranSurah, ayahs: Int)] {
        var stretch: [(QuranSurah, Int)] = []
        var budget = dailyTarget
        guard budget > 0 else { return [] }
        for surah in QuranLibrary.surahs {
            if player.completionCount(for: surah.number) > 0 { continue }
            stretch.append((surah, surah.ayahs))
            budget -= surah.ayahs
            if budget <= 0 { break }
        }
        return stretch
    }

    var body: some View {
        Form {
            Section("Progress") {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: Double(completedAyahs),
                                 total: Double(Self.totalAyahs))
                        .tint(Theme.green)
                    Text("\(completedAyahs) of \(Self.totalAyahs) ayahs | surahs completed at least once")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Listening streak: \(player.listeningStreakDays) day\(player.listeningStreakDays == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            Section("Plan") {
                Toggle("Khatmah plan active", isOn: $active)
                    .onChange(of: active) { isOn in
                        if isOn { startEpoch = Date.now.timeIntervalSince1970 }
                    }
                Stepper("Finish in \(planDays) days", value: $planDays, in: 7...365, step: 1)
                    .disabled(!active)
                if active {
                    LabeledContent("Days left", value: "\(daysLeft)")
                    LabeledContent("Today's target", value: "\(dailyTarget) ayahs")
                }
                Text("Progress counts a surah once you have heard it to the end at least once (from your listening stats). Days left count from when the plan was switched on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if active && !todaysStretch.isEmpty {
                Section("Today's stretch") {
                    ForEach(todaysStretch, id: \.surah.number) { item in
                        Button {
                            player.play(
                                surahNumber: item.surah.number,
                                queue: todaysStretch.map { $0.surah.number },
                                contextLabel: "Khatmah")
                        } label: {
                            PlaylistSurahRow(surah: item.surah)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Khatmah Planner")
    }
}

// MARK: - Tafsir sheet (feature 5)

struct AyahRef: Identifiable {
    let surah: Int
    let ayah: Int
    var id: String { "\(surah):\(ayah)" }
}

struct TafsirSheet: View {
    @Environment(\.dismiss) private var dismiss
    let surah: Int
    let ayah: Int
    @State private var text: String?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if let text {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tafsir Ibn Kathir (Abridged) | English, via Quran.com")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(text)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .padding(20)
                    }
                } else if failed {
                    ContentUnavailableView(
                        "Tafsir unavailable",
                        systemImage: "wifi.slash",
                        description: Text("The tafsir is fetched from Quran.com the first time; check your connection and try again."))
                } else {
                    ProgressView("Loading tafsir…")
                }
            }
            .navigationTitle("Ayah \(surah):\(ayah)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                switch await TafsirService.fetch(surah: surah, ayah: ayah) {
                case .success(let loaded): text = loaded
                case .failure: failed = true
                }
            }
        }
    }
}

// MARK: - Word by word (feature 4)

/// Word-by-word for a whole surah. Word data comes from the
/// Quran.com API on first open and is cached per surah. While the
/// main player is playing this surah, the current ayah (and word)
/// is estimated from the same character-weighted timing the lyrics
/// use - the word timing is an estimate, the words and their
/// translations are exact dataset values.
struct WordByWordView: View {
    @EnvironmentObject private var player: QuranPlayer
    @EnvironmentObject private var ayahPlayer: AyahAudioPlayer
    let surahNumber: Int
    @State private var ayahs: [QuranAyahWords] = []
    @State private var failed = false
    @State private var loaded = false

    private var texts: [QuranAyahText] {
        QuranTextData.ayahsBySurah[surahNumber] ?? []
    }

    private var currentAyahIndex: Int? {
        guard player.currentSurah?.number == surahNumber else { return nil }
        return quranCurrentAyahIndex(texts, time: player.currentTime,
                                     duration: player.duration)
    }

    /// Estimated current word position inside the current ayah
    /// (the ayah's elapsed fraction times its word count).
    private func estimatedWord(ayahIndex: Int) -> Int? {
        guard let ayahWords = ayahs.first(where: { $0.ayah == ayahIndex + 1 }),
              !ayahWords.words.isEmpty else { return nil }
        let start = quranAyahStartTime(texts, index: ayahIndex, duration: player.duration)
        let end = quranAyahEndTime(texts, index: ayahIndex, duration: player.duration)
        guard end > start else { return nil }
        let fraction = min(1, max(0, (player.currentTime - start) / (end - start)))
        return min(ayahWords.words.count - 1, Int(fraction * Double(ayahWords.words.count)))
    }

    var body: some View {
        Group {
            if loaded {
                List(ayahs) { ayahWords in
                    Section {
                        wordsBlock(ayahWords)
                    } header: {
                        HStack {
                            Text("Ayah \(ayahWords.ayah)")
                            Spacer()
                            if QuranLibrary.supportsPerAyah(reciterId: player.reciterId) {
                                Button {
                                    player.pause()
                                    ayahPlayer.play(
                                        surah: surahNumber, ayah: ayahWords.ayah,
                                        reciterId: player.reciterId)
                                } label: {
                                    Label("Play ayah", systemImage: "play.circle")
                                        .font(.caption.weight(.bold))
                                }
                                .textCase(nil)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else if failed {
                ContentUnavailableView(
                    "Word data unavailable",
                    systemImage: "wifi.slash",
                    description: Text("Word-by-word data is fetched from Quran.com the first time you open a surah; check your connection and try again."))
            } else {
                ProgressView("Loading word data…")
            }
        }
        .navigationTitle("Word by Word")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            switch await WordByWordService.fetch(surah: surahNumber) {
            case .success(let data): ayahs = data; loaded = true
            case .failure: failed = true
            }
        }
    }

    @ViewBuilder
    private func wordsBlock(_ ayahWords: QuranAyahWords) -> some View {
        let isCurrentAyah = currentAyahIndex == ayahWords.ayah - 1
        let currentWord = isCurrentAyah ? estimatedWord(ayahIndex: ayahWords.ayah - 1) : nil
        FlowLayout(spacing: 8, rtl: true) {
            ForEach(ayahWords.words) { word in
                VStack(spacing: 1) {
                    Text(word.arabic)
                        .font(.title3.weight(.medium))
                    Text(word.transliteration)
                        .font(.caption2.italic())
                        .foregroundStyle(.secondary)
                    Text(word.translation)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    currentWord == word.position - 1
                        ? Theme.adaptiveGold.opacity(0.35)
                        : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
    }
}

/// Minimal wrapping flow layout for the word chips. `rtl` lays
/// rows out right-to-left so the Arabic words read in order.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rtl: Bool = false

    private func rows(width: CGFloat, subviews: Subviews)
        -> [(views: [Subviews.Element], height: CGFloat)] {
        var result: [(views: [Subviews.Element], height: CGFloat)] = []
        var row: [Subviews.Element] = []
        var x: CGFloat = 0, height: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, !row.isEmpty {
                result.append((row, height))
                row = []
                x = 0
                height = 0
            }
            row.append(view)
            x += size.width + spacing
            height = max(height, size.height)
        }
        if !row.isEmpty { result.append((row, height)) }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews,
                      cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let rows = rows(width: width, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +)
            + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            if rtl {
                var x = bounds.maxX
                for view in row.views {
                    let size = view.sizeThatFits(.unspecified)
                    x -= size.width
                    view.place(at: CGPoint(x: x, y: y),
                               proposal: ProposedViewSize(size))
                    x -= spacing
                }
            } else {
                var x = bounds.minX
                for view in row.views {
                    let size = view.sizeThatFits(.unspecified)
                    view.place(at: CGPoint(x: x, y: y),
                               proposal: ProposedViewSize(size))
                    x += size.width + spacing
                }
            }
            y += row.height + spacing
        }
    }
}

// MARK: - Appearance (full theming layer)

struct IconOption: Identifiable {
    let iconName: String?
    let label: String
    let preview: String
    var id: String { iconName ?? "primary" }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var theme: AppThemeStore

    static let iconOptions: [IconOption] = [
        IconOption(iconName: nil, label: "Mosque Green", preview: "IconPreviewDefault"),
        IconOption(iconName: "AppIconOcean", label: "Ocean Depths", preview: "IconPreviewOcean"),
        IconOption(iconName: "AppIconDesert", label: "Desert Dunes", preview: "IconPreviewDesert"),
        IconOption(iconName: "AppIconEmerald", label: "Emerald Night", preview: "IconPreviewEmerald"),
        IconOption(iconName: "AppIconCrimson", label: "Crimson Dusk", preview: "IconPreviewCrimson"),
        IconOption(iconName: "AppIconSapphire", label: "Sapphire Noor", preview: "IconPreviewSapphire"),
        IconOption(iconName: "AppIconPlum", label: "Plum Velvet", preview: "IconPreviewPlum"),
        IconOption(iconName: "AppIconContrast", label: "High Contrast", preview: "IconPreviewContrast"),
    ]

    var body: some View {
        Form {
            Section("Theme") {
                ForEach(NoorAppearance.presetThemes) { preset in
                    Button {
                        theme.applyPreset(preset)
                    } label: {
                        HStack(spacing: 12) {
                            swatch(primaryHex: preset.primaryHex,
                                   accentHex: preset.accentHex)
                            Text(preset.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if theme.presetId == preset.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.green)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("Appearance") {
                Picker("Mode", selection: modeBinding) {
                    ForEach(NoorAppearance.Mode.allCases, id: \.rawValue) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text("System follows your iPhone's Light and Dark Mode setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Accent") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(NoorAppearance.accentPresets, id: \.name) { preset in
                            Button {
                                theme.setAccent(hex: preset.hex)
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(uiColor: NoorAppearance.uiColor(forHex: preset.hex)))
                                        .frame(width: 34, height: 34)
                                        .overlay {
                                            if theme.accentHex == preset.hex {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.weight(.heavy))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    Text(preset.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                ColorPicker("Custom accent", selection: customAccentBinding,
                            supportsOpacity: false)
                if theme.presetId == "custom" {
                    Button("Use the theme's accent") {
                        if let preset = NoorAppearance.preset(id: "preset-mosque") {
                            theme.applyPreset(preset)
                        }
                    }
                }
                Text("The accent is brightened on dark backgrounds, deepened on light ones, and checked for contrast so text stays readable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Widget colors") {
                Picker("Home Screen widgets", selection: widgetModeBinding) {
                    Text("Match my theme").tag(NoorAppearance.WidgetColorMode.match)
                    Text("Separate colors").tag(NoorAppearance.WidgetColorMode.separate)
                }
                .pickerStyle(.segmented)
                if theme.widgetColorMode == .separate {
                    ForEach(NoorAppearance.presetThemes) { preset in
                        Button {
                            theme.setWidgetHomeTheme(preset)
                        } label: {
                            HStack(spacing: 12) {
                                swatch(primaryHex: preset.primaryHex,
                                       accentHex: preset.accentHex)
                                Text(preset.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if NoorAppearance.storedWidgetHomeTheme?.id == preset.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.green)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Lock Screen widgets are drawn by iOS itself as a single tint; they use the widget accent color as that tint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("App icon") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76))], spacing: 14) {
                    ForEach(Self.iconOptions) { option in
                        Button {
                            theme.setIcon(name: option.iconName)
                        } label: {
                            VStack(spacing: 5) {
                                Image(option.preview)
                                    .resizable()
                                    .frame(width: 58, height: 58)
                                    .clipShape(RoundedRectangle(
                                        cornerRadius: 13, style: .continuous))
                                    .overlay {
                                        if theme.iconName == option.iconName {
                                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                .stroke(Theme.adaptiveGold, lineWidth: 2.5)
                                        }
                                    }
                                Text(option.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            Section {
                Button("Reset appearance", role: .destructive) {
                    theme.resetToDefaults()
                }
            }
        }
        .navigationTitle("Appearance")
    }

    private func swatch(primaryHex: UInt32, accentHex: UInt32) -> some View {
        ZStack {
            Circle().fill(Color(uiColor: NoorAppearance.uiColor(forHex: primaryHex)))
            Circle().fill(Color(uiColor: NoorAppearance.uiColor(forHex: accentHex)))
                .frame(width: 14, height: 14)
                .offset(x: 7, y: 7)
        }
        .frame(width: 30, height: 30)
    }

    private var modeBinding: Binding<NoorAppearance.Mode> {
        Binding(get: { theme.mode }, set: { theme.setMode($0) })
    }

    private var customAccentBinding: Binding<Color> {
        Binding(
            get: { Color(uiColor: NoorAppearance.uiColor(forHex: theme.accentHex)) },
            set: { newColor in theme.setAccent(hex: newColor.hexValue) })
    }

    private var widgetModeBinding: Binding<NoorAppearance.WidgetColorMode> {
        Binding(get: { theme.widgetColorMode },
                set: { theme.setWidgetColorMode($0) })
    }
}
