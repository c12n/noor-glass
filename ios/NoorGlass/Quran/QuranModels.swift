//
//  QuranModels.swift
//  Noor Glass
//
//  Quran player (v2.1.0-private): the bundled surah catalogue
//  (surahs.json) — every surah's names, ayah count, revelation place
//  and per-reciter stream durations — plus the player's shared
//  brand colors. Audio itself is streamed per surah from the CDN in
//  the catalogue (or played from a local download, see
//  QuranDownloads). Target Membership: NoorGlass only.
//

import Foundation
import SwiftUI

// MARK: - Catalogue (surahs.json)

struct QuranReciter: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    /// Narration label shown under the name in the picker, e.g.
    /// "Ad-Duri 'an Abi 'Amr" for Noreen Mohammad Siddiq (the
    /// Sudanese riwaya, NOT Hafs). Optional: phase-1 catalogues
    /// without the field still decode.
    let narration: String?
    /// Per-reciter stream base (phase 2): the Sudanese reciters are
    /// served by mp3quran's CDN, not the Islamic Network CDN in the
    /// catalogue's shared audioBase. Nil = use the shared base.
    let audioBase: String?
    /// True when file names are zero-padded to three digits
    /// (mp3quran style, "036.mp3"); false for the Islamic Network
    /// style ("36.mp3"). Nil = false.
    let padded: Bool?

    init(id: String, name: String, narration: String? = nil,
         audioBase: String? = nil, padded: Bool? = nil) {
        self.id = id
        self.name = name
        self.narration = narration
        self.audioBase = audioBase
        self.padded = padded
    }
}

struct QuranSurah: Codable, Identifiable, Equatable {
    let number: Int
    let arabic: String
    let english: String
    let meaning: String
    let ayahs: Int
    /// "Makki" or "Madani".
    let revelation: String
    /// Stream duration in seconds, keyed by reciter id.
    let durations: [String: Int]

    var id: Int { number }

    func duration(for reciterId: String) -> Int? {
        durations[reciterId]
    }
}

private struct QuranCatalogue: Codable {
    let reciters: [QuranReciter]
    let audioBase: String
    let surahs: [QuranSurah]
}

/// The bundled catalogue, loaded once from surahs.json.
enum QuranLibrary {
    private static let catalogue: QuranCatalogue = {
        guard let url = Bundle.main.url(forResource: "surahs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(QuranCatalogue.self, from: data)
        else {
            assertionFailure("surahs.json missing or undecodable")
            return QuranCatalogue(reciters: [], audioBase: "", surahs: [])
        }
        return decoded
    }()

    static var reciters: [QuranReciter] { catalogue.reciters }
    static var surahs: [QuranSurah] { catalogue.surahs }
    static var audioBase: String { catalogue.audioBase }

    static func surah(_ number: Int) -> QuranSurah? {
        catalogue.surahs.first { $0.number == number }
    }

    static func reciter(_ id: String) -> QuranReciter? {
        catalogue.reciters.first { $0.id == id }
    }

    /// The first reciter in the catalogue (Alafasy) — the default.
    static var defaultReciter: QuranReciter? { catalogue.reciters.first }

    /// The stream URL for a reciter. Two layouts exist:
    /// - mp3quran (the Sudanese pair, `padded` true): the files sit
    ///   directly under the reciter's own base, zero-padded, with
    ///   NO reciter-id segment: "{audioBase}/{NNN}.mp3".
    /// - Islamic Network (everyone else): the reciter-id segment
    ///   is required: "{base}/{reciterId}/{number}.mp3" unpadded,
    ///   where base is the reciter's own audioBase when the
    ///   catalogue carries one, else the shared catalogue base.
    /// Build 3 fix: the v2 catalogue gives the Islamic Network
    /// reciters their own audioBase too, and the old code treated
    /// ANY audioBase as the mp3quran layout, dropping the
    /// reciter-id segment. The CDN answers those URLs 403, every
    /// player item failed, and the app was silent while showing a
    /// playing state. `padded` is the layout discriminator, not
    /// the mere presence of an audioBase.
    static func streamURL(surahNumber: Int, reciterId: String) -> URL? {
        guard let reciter = reciter(reciterId) else {
            return URL(string: "\(catalogue.audioBase)/\(reciterId)/\(surahNumber).mp3")
        }
        let base = reciter.audioBase ?? catalogue.audioBase
        if reciter.padded ?? false {
            return URL(string: "\(base)/\(String(format: "%03d.mp3", surahNumber))")
        }
        return URL(string: "\(base)/\(reciterId)/\(surahNumber).mp3")
    }

    // MARK: Per-ayah audio (phase 2, feature 3)

    /// Reciters whose per-ayah files the Islamic Network CDN
    /// actually serves, with the bitrate that answers 200 (verified
    /// live 2026-11-12: Alafasy at 128, Abdul Basit and Basfar at
    /// 64; Aziz Alili answers 403 at every bitrate, and the
    /// Sudanese reciters are per-surah only on mp3quran, so they
    /// keep the character-weighted estimate timing).
    static let perAyahBitrate: [String: Int] = [
        "ar.alafasy": 128,
        "ar.abdulbasitmurattal": 64,
        "ar.abdullahbasfar": 64,
    ]

    static func supportsPerAyah(reciterId: String) -> Bool {
        perAyahBitrate[reciterId] != nil
    }

    /// 1-based global ayah number (1...6236) from the catalogue's
    /// ayah counts.
    static func globalAyahNumber(surahNumber: Int, ayah: Int) -> Int {
        var offset = 0
        for surah in catalogue.surahs where surah.number < surahNumber {
            offset += surah.ayahs
        }
        return offset + ayah
    }

    /// One ayah's own MP3 on the Islamic Network CDN, for reciters
    /// in perAyahBitrate; nil for everyone else.
    static func perAyahURL(surahNumber: Int, ayah: Int, reciterId: String) -> URL? {
        guard let bitrate = perAyahBitrate[reciterId] else { return nil }
        let global = globalAyahNumber(surahNumber: surahNumber, ayah: ayah)
        return URL(string: "https://cdn.islamic.network/quran/audio/\(bitrate)/\(reciterId)/\(global).mp3")
    }

    /// Bundled stream duration for a surah under a reciter, if known.
    static func duration(surahNumber: Int, reciterId: String) -> TimeInterval? {
        guard let seconds = surah(surahNumber)?.duration(for: reciterId) else { return nil }
        return TimeInterval(seconds)
    }

    // MARK: English audio (v2.2.0-alpha)

    /// The pseudo-reciter id for the English translation audio. It
    /// keys the downloads folder (QuranAudio/english/) exactly like a
    /// reciter id, so the downloads machinery needs no special case.
    static let englishReciterId = "english"

    static let englishReciter = QuranReciter(
        id: englishReciterId, name: "Ibrahim Walk (English)")

    /// Full-surah English translation MP3s (Ibrahim Walk), hosted by
    /// QuranicAudio; surah number zero-padded to three digits.
    static func englishStreamURL(surahNumber: Int) -> URL? {
        URL(string: String(format: "https://download.quranicaudio.com/quran/ibrahim_walk/%03d.mp3",
                           surahNumber))
    }

    /// The stream URL for any reciter id, English included.
    static func audioURL(surahNumber: Int, reciterId: String) -> URL? {
        reciterId == englishReciterId
            ? englishStreamURL(surahNumber: surahNumber)
            : streamURL(surahNumber: surahNumber, reciterId: reciterId)
    }

    /// Bundled English durations (en_durations.json, measured from
    /// the hosted files), keyed by surah number.
    static let englishDurations: [Int: Int] = {
        guard let url = Bundle.main.url(forResource: "en_durations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return decoded.reduce(into: [Int: Int]()) { result, pair in
            if let number = Int(pair.key) { result[number] = pair.value }
        }
    }()

    static func englishDuration(surahNumber: Int) -> TimeInterval? {
        englishDurations[surahNumber].map(TimeInterval.init)
    }

    /// "7:02" under an hour, "2:05:40" above it.
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Collections (v2.2.0-alpha)

/// A named playlist of surahs, shown as a card in the library.
struct QuranCollection: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let surahNumbers: [Int]

    var surahs: [QuranSurah] { surahNumbers.compactMap(QuranLibrary.surah) }

    static func == (lhs: QuranCollection, rhs: QuranCollection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension QuranLibrary {
    static var collections: [QuranCollection] {
        [
            QuranCollection(
                id: "ramadan",
                title: "Ramadan",
                subtitle: "For the nights of Ramadan",
                surahNumbers: [2, 36, 18, 55, 67, 97, 12, 19, 78, 112, 113, 114]),
            QuranCollection(
                id: "eid",
                title: "Eid",
                subtitle: "Recited in the Eid prayers",
                surahNumbers: [87, 88, 50, 54, 109, 112, 113, 114]),
        ]
    }
}

// MARK: - Player brand colors (per the approved mockup)

/// Fixed mosque-green / gold palette for the Quran player surfaces.
/// The library sits on the app's light background; the mini player
/// and Now Playing wear the deep green from the mockup regardless of
/// the user's theme, like a record sleeve.
enum QuranTheme {
    // Phase 2: the Quran surfaces follow the app theme like every
    // other surface (Youssef's call, reversing the Prayer YEG rule
    // that this palette was fixed). Under the default Mosque Green
    // preset these resolve to the phase-1 constants: deepGreen
    // #0B3D2E, gold #D4AF37, lightGold #E9D48A family.
    static var deepGreen: Color { NoorPalette.app.primary }
    static var midGreen: Color { NoorPalette.app.primaryBright }
    static var darkestGreen: Color { NoorPalette.app.primaryDarkest }
    static var accentGreen: Color {
        Color(uiColor: NoorAppearance.primaryUIColor.lightened(by: 0.30))
    }
    static var gold: Color { NoorPalette.app.accent }
    static var lightGold: Color { NoorPalette.app.accentLight }
    static var mutedOnGreen: Color { NoorPalette.app.onPrimaryMuted }
    /// #E5484D — the favorite heart (semantic red in every theme).
    static let heartRed = Color(red: 0.898, green: 0.282, blue: 0.302)
    static var pageTint: Color { NoorPalette.app.pageTint }
}

// MARK: - Ayah bookmarks (build 31)

/// One saved ayah: a surah number + ayah number within it.
struct QuranBookmark: Codable, Identifiable, Equatable {
    var surah: Int
    var ayah: Int
    var createdAt: Date

    var id: String { "\(surah):\(ayah)" }
}

/// Persisted ayah bookmarks (`quran.bookmarks.v1`, JSON in
/// UserDefaults.standard, like the listening stats).
final class QuranBookmarks: ObservableObject {
    @Published private(set) var bookmarks: [QuranBookmark] = []

    private let key = "quran.bookmarks.v1"
    private var defaults: UserDefaults { .standard }

    init() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([QuranBookmark].self, from: data) {
            bookmarks = decoded.sorted { $0.createdAt > $1.createdAt }
        }
    }

    func isBookmarked(surah: Int, ayah: Int) -> Bool {
        bookmarks.contains { $0.surah == surah && $0.ayah == ayah }
    }

    func toggle(surah: Int, ayah: Int) {
        if isBookmarked(surah: surah, ayah: ayah) {
            bookmarks.removeAll { $0.surah == surah && $0.ayah == ayah }
        } else {
            bookmarks.insert(QuranBookmark(surah: surah, ayah: ayah,
                                           createdAt: Date()), at: 0)
        }
        save()
    }

    func remove(_ bookmark: QuranBookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            defaults.set(data, forKey: key)
        }
    }
}
