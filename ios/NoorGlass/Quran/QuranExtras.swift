//
//  QuranExtras.swift
//  Noor Glass
//
//  Phase-2 data and services:
//  - French translation (Muhammad Hamidullah), bundled in
//    quran_fr.json from the AlQuranCloud fr.hamidullah edition.
//  - MushafData: the 604-page Madani mushaf mapping (page and juz
//    per ayah), generated from the AlQuranCloud quran-uthmani
//    edition's page/juz fields into mushaf_pages.json.
//  - Custom playlists, persisted locally.
//  - TafsirService: English Ibn Kathir (Abridged) per ayah from
//    the Quran.com API (tafsir 169), fetched on tap and cached.
//  - WordByWordService: per-word Arabic, transliteration and
//    translation from the Quran.com API, fetched per surah and
//    cached. Word timing during playback is ESTIMATED from the
//    word's share of its ayah (character-weighted, the same
//    estimate family as the ayah timing) - never exact.
//  - AyahAudioPlayer: exact per-ayah audio for the reciters the
//    Islamic Network CDN serves per-ayah files for.
//  - DailyReminder: the Daily Ayah notification.
//
//  Copyright (c) 2026 c12n Apps
//

import AVFoundation
import Foundation
import SwiftUI
import UserNotifications

// MARK: - French translation (feature 10)

struct QuranFrenchAyah: Codable, Identifiable {
    let n: Int
    let fr: String
    var id: Int { n }
}

/// Synchronous, parse-once access to the bundled French text
/// (Hamidullah), keyed exactly like QuranTextData.
enum QuranFrenchData {
    static let ayahsBySurah: [Int: [QuranFrenchAyah]] = {
        guard let url = Bundle.main.url(forResource: "quran_fr",
                                        withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(
                  [String: [QuranFrenchAyah]].self, from: data)
        else { return [:] }
        var parsed: [Int: [QuranFrenchAyah]] = [:]
        for (key, ayahs) in decoded {
            if let number = Int(key) { parsed[number] = ayahs }
        }
        return parsed
    }()

    static func text(surah: Int, ayah: Int) -> String? {
        ayahsBySurah[surah]?.first { $0.n == ayah }?.fr
    }
}

/// Which translation the lyrics and reader show beside the Arabic.
enum QuranTranslation: String, CaseIterable, Identifiable {
    case english, french

    var id: String { rawValue }
    var label: String {
        switch self {
        case .english: "English | Saheeh International"
        case .french: "French | Hamidullah"
        }
    }
    var shortLabel: String {
        switch self {
        case .english: "English"
        case .french: "French"
        }
    }

    func text(surah: Int, ayah: Int) -> String? {
        switch self {
        case .english:
            QuranTextData.ayahsBySurah[surah]?.first { $0.n == ayah }?.en
        case .french:
            QuranFrenchData.text(surah: surah, ayah: ayah)
        }
    }
}

// MARK: - Mushaf mapping (feature 1)

/// The Madani mushaf's 604 pages: where every ayah sits, and which
/// juz it belongs to. Generated from per-ayah page/juz fields, so
/// page boundaries are the printed mushaf's, not a guess.
enum MushafData {
    struct Segment: Identifiable, Equatable {
        let surah: Int
        let fromAyah: Int
        let toAyah: Int
        var id: String { "\(surah):\(fromAyah)-\(toAyah)" }
    }

    private struct File: Codable {
        let pageCount: Int
        let surahPages: [String: [[Int]]]
        let surahJuz: [String: [[Int]]]
        /// juz -> [surah, ayah, page]
        let juzStarts: [String: [Int]]
    }

    private static let file: File? = {
        guard let url = Bundle.main.url(forResource: "mushaf_pages",
                                        withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data)
        else { return nil }
        return decoded
    }()

    static var pageCount: Int { file?.pageCount ?? 604 }

    private static func value(breakpoints: [[Int]], ayah: Int) -> Int? {
        var result: Int?
        for point in breakpoints {
            if point[0] <= ayah { result = point[1] } else { break }
        }
        return result
    }

    static func page(surah: Int, ayah: Int) -> Int? {
        guard let points = file?.surahPages["\(surah)"] else { return nil }
        return value(breakpoints: points, ayah: ayah)
    }

    static func juz(surah: Int, ayah: Int) -> Int? {
        guard let points = file?.surahJuz["\(surah)"] else { return nil }
        return value(breakpoints: points, ayah: ayah)
    }

    static func juzStartPage(_ juz: Int) -> Int? {
        file?.juzStarts["\(juz)"]?[2]
    }

    static func juzStartLabel(_ juz: Int) -> String? {
        guard let start = file?.juzStarts["\(juz)"], start.count == 3,
              let surah = QuranLibrary.surah(start[0]) else { return nil }
        return "\(surah.english) | Ayah \(start[1])"
    }

    /// The ayah ranges printed on one page, in order.
    static let segmentsByPage: [Int: [Segment]] = {
        guard let file else { return [:] }
        var result: [Int: [Segment]] = [:]
        for (key, points) in file.surahPages {
            guard let surahNumber = Int(key),
                  let surah = QuranLibrary.surah(surahNumber) else { continue }
            for (index, point) in points.enumerated() {
                let from = point[0]
                let page = point[1]
                let to = index + 1 < points.count
                    ? points[index + 1][0] - 1
                    : surah.ayahs
                if from <= to {
                    result[page, default: []].append(
                        Segment(surah: surahNumber, fromAyah: from, toAyah: to))
                }
            }
        }
        for page in result.keys {
            result[page]?.sort { $0.surah < $1.surah }
        }
        return result
    }()
}

// MARK: - Custom playlists (feature 8)

struct QuranPlaylist: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var surahNumbers: [Int]
    var createdAt: Date
}

/// Persisted custom playlists (`quran.playlists.v1`).
final class QuranPlaylists: ObservableObject {
    @Published private(set) var playlists: [QuranPlaylist] = []

    private let key = "quran.playlists.v1"
    private var defaults: UserDefaults { .standard }

    init() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([QuranPlaylist].self, from: data) {
            playlists = decoded
        }
    }

    @discardableResult
    func create(name: String, surahNumbers: [Int] = []) -> QuranPlaylist {
        let playlist = QuranPlaylist(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            surahNumbers: surahNumbers, createdAt: .now)
        playlists.append(playlist)
        save()
        return playlist
    }

    func rename(id: String, to name: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].name = name.trimmingCharacters(in: .whitespaces)
        save()
    }

    func delete(id: String) {
        playlists.removeAll { $0.id == id }
        save()
    }

    func add(surahNumber: Int, to id: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }),
              !playlists[index].surahNumbers.contains(surahNumber) else { return }
        playlists[index].surahNumbers.append(surahNumber)
        save()
    }

    func remove(surahNumber: Int, from id: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].surahNumbers.removeAll { $0 == surahNumber }
        save()
    }

    func playlist(id: String) -> QuranPlaylist? {
        playlists.first { $0.id == id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(playlists) {
            defaults.set(data, forKey: key)
        }
    }
}

// MARK: - Tafsir (feature 5)

/// English Ibn Kathir (Abridged) per ayah, Quran.com tafsir 169.
/// Fetched on demand, cached on disk (Caches/NoorTafsir), so a
/// second look is instant and offline after the first.
enum TafsirService {
    struct Response: Codable {
        struct Tafsir: Codable {
            let text: String?
            let resourceName: String?
            enum CodingKeys: String, CodingKey {
                case text
                case resourceName = "resource_name"
            }
        }
        let tafsir: Tafsir?
    }

    private static var cacheDir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory,
                                            in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("NoorTafsir", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir,
                                                 withIntermediateDirectories: true)
        return dir
    }

    static func cached(surah: Int, ayah: Int) -> String? {
        let url = cacheDir.appendingPathComponent("\(surah)_\(ayah).txt")
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func fetch(surah: Int, ayah: Int) async -> Result<String, Error> {
        if let hit = cached(surah: surah, ayah: ayah) {
            return .success(hit)
        }
        guard let url = URL(string:
            "https://api.quran.com/api/v4/tafsirs/169/by_ayah/\(surah):\(ayah)")
        else { return .failure(URLError(.badURL)) }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            guard let raw = decoded.tafsir?.text, !raw.isEmpty else {
                return .failure(URLError(.resourceUnavailable))
            }
            let plain = stripHTML(raw)
            let file = cacheDir.appendingPathComponent("\(surah)_\(ayah).txt")
            try? plain.write(to: file, atomically: true, encoding: .utf8)
            return .success(plain)
        } catch {
            return .failure(error)
        }
    }

    /// Quran.com tafsir text arrives as HTML; reduce it to plain
    /// paragraphs for display.
    static func stripHTML(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "</p>", with: "\n\n")
        text = text.replacingOccurrences(of: "<br>", with: "\n")
        text = text.replacingOccurrences(of: "<br/>", with: "\n")
        text = text.replacingOccurrences(of: "<[^>]+>", with: "",
                                         options: .regularExpression)
        let entities: [String: String] = [
            "&nbsp;": " ", "&amp;": "&", "&quot;": "\"", "&apos;": "'",
            "&lt;": "<", "&gt;": ">", "&#39;": "'",
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Word by word (feature 4)

struct QuranWord: Codable, Identifiable {
    let position: Int
    let arabic: String
    let transliteration: String
    let translation: String

    var id: Int { position }
}

struct QuranAyahWords: Codable, Identifiable {
    let ayah: Int
    let words: [QuranWord]

    var id: Int { ayah }
}

/// Per-word data from the Quran.com API (verses/by_chapter with
/// words). Cached per surah on disk after the first fetch.
enum WordByWordService {
    private struct APIResponse: Codable {
        struct Verse: Codable {
            struct Word: Codable {
                let position: Int
                // The words payload names the Arabic word simply
                // "text" (verified against the live API response).
                let textUthmani: String?
                let charTypeName: String?
                let transliteration: Transliteration?
                let translation: Translation?
                enum CodingKeys: String, CodingKey {
                    case position
                    case textUthmani = "text"
                    case charTypeName = "char_type_name"
                    case transliteration, translation
                }
            }
            struct Transliteration: Codable { let text: String? }
            struct Translation: Codable { let text: String? }
            let verseKey: String
            let words: [Word]
            enum CodingKeys: String, CodingKey {
                case verseKey = "verse_key"
                case words
            }
            /// Ayah number within the surah, from the "36:9" key
            /// (the API's verse_number field is the global number
            /// on some endpoints, so the key is the reliable one).
            var numberInSurah: Int {
                Int(verseKey.split(separator: ":").last ?? "") ?? 0
            }
        }
        struct Pagination: Codable {
            let nextPage: Int?
            enum CodingKeys: String, CodingKey { case nextPage = "next_page" }
        }
        let verses: [Verse]
        let pagination: Pagination?
    }

    private static var cacheDir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory,
                                            in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("NoorWords", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir,
                                                 withIntermediateDirectories: true)
        return dir
    }

    static func cached(surah: Int) -> [QuranAyahWords]? {
        let url = cacheDir.appendingPathComponent("\(surah).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([QuranAyahWords].self, from: data)
    }

    static func fetch(surah: Int) async -> Result<[QuranAyahWords], Error> {
        if let hit = cached(surah: surah) { return .success(hit) }
        var collected: [QuranAyahWords] = []
        var page: Int? = 1
        do {
            while let current = page {
                guard let url = URL(string:
                    "https://api.quran.com/api/v4/verses/by_chapter/\(surah)"
                    + "?words=true&fields=text_uthmani&per_page=300&page=\(current)")
                else { return .failure(URLError(.badURL)) }
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
                for verse in decoded.verses {
                    let words = verse.words
                        .filter { $0.charTypeName != "end" }
                        .map { word in
                            QuranWord(
                                position: word.position,
                                arabic: word.textUthmani ?? "",
                                transliteration: word.transliteration?.text ?? "",
                                translation: word.translation?.text ?? "")
                        }
                        .filter { !$0.arabic.isEmpty }
                    collected.append(QuranAyahWords(ayah: verse.numberInSurah,
                                                    words: words))
                }
                page = decoded.pagination?.nextPage
            }
        } catch {
            return .failure(error)
        }
        if let data = try? JSONEncoder().encode(collected) {
            let file = cacheDir.appendingPathComponent("\(surah).json")
            try? data.write(to: file)
        }
        return .success(collected)
    }
}

// MARK: - Per-ayah audio player (feature 3)

/// Exact per-ayah playback on its own AVPlayer, separate from the
/// per-surah engine: one ayah, or one ayah repeated for
/// memorization with true ayah boundaries. Only for reciters in
/// QuranLibrary.perAyahBitrate; the UI hides it otherwise.
final class AyahAudioPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    /// "36:9" style label of the ayah currently loaded.
    @Published private(set) var currentLabel: String?

    private let player = AVPlayer()
    private var endObserver: NSObjectProtocol?
    private var repeatsLeft = 0
    private var currentItemURL: URL?

    func play(surah: Int, ayah: Int, reciterId: String, repeats: Int = 1) {
        guard let url = QuranLibrary.perAyahURL(
            surahNumber: surah, ayah: ayah, reciterId: reciterId) else { return }
        stop()
        currentItemURL = url
        repeatsLeft = max(1, repeats)
        currentLabel = "\(surah):\(ayah)"
        load(url)
    }

    private func load(_ url: URL) {
        let item = AVPlayerItem(url: url)
        if let existing = endObserver {
            NotificationCenter.default.removeObserver(existing)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.repeatsLeft -= 1
            if self.repeatsLeft > 0 {
                self.player.seek(to: .zero)
                self.player.play()
            } else {
                self.isPlaying = false
                self.currentLabel = nil
            }
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true
    }

    func stop() {
        player.pause()
        isPlaying = false
        currentLabel = nil
        repeatsLeft = 0
        if let existing = endObserver {
            NotificationCenter.default.removeObserver(existing)
            endObserver = nil
        }
    }
}

// MARK: - Daily Ayah reminder (feature 6)

/// One notification per day for the next seven days, each carrying
/// that day's ayah, scheduled at the user's chosen time. Re-run on
/// every app launch (and whenever the settings change) so the week
/// ahead is always covered.
enum DailyReminder {
    private static var defaults: UserDefaults { NoorAppearance.sharedDefaults }
    static let enabledKey = "reminder.dailyAyah.enabled"
    static let hourKey = "reminder.dailyAyah.hour"
    static let minuteKey = "reminder.dailyAyah.minute"

    static var enabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    static var hour: Int {
        get {
            defaults.object(forKey: hourKey) == nil
                ? 7 : defaults.integer(forKey: hourKey)
        }
        set { defaults.set(newValue, forKey: hourKey) }
    }

    static var minute: Int {
        get { defaults.integer(forKey: minuteKey) }
        set { defaults.set(newValue, forKey: minuteKey) }
    }

    private static var identifiers: [String] {
        (0..<7).map { "noor.dailyayah.\($0)" }
    }

    static func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard enabled else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let calendar = Calendar.current
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset,
                                              to: .now) else { continue }
                var components = calendar.dateComponents(
                    [.year, .month, .day], from: day)
                components.hour = hour
                components.minute = minute
                guard let fireDate = calendar.date(from: components),
                      fireDate > .now else { continue }
                let ayah = DailyAyahs.ayah(for: fireDate)
                let content = UNMutableNotificationContent()
                content.title = "Daily Ayah | \(ayah.reference)"
                content.body = "\(ayah.arabic)\n\(ayah.english)"
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "noor.dailyayah.\(offset)",
                    content: content, trigger: trigger)
                center.add(request)
            }
        }
    }
}
