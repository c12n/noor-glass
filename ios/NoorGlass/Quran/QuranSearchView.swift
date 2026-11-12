//
//  QuranSearchView.swift
//  Noor Glass
//
//  Full-text search (phase 2, feature 2) over the bundled texts:
//  the Arabic, the Saheeh International English and the Hamidullah
//  French, all offline. Tapping a result plays its surah from that
//  ayah (estimated seek, like the lyrics view).
//
//  Copyright (c) 2026 c12n Apps
//

import SwiftUI

struct QuranSearchView: View {
    @EnvironmentObject private var player: QuranPlayer
    @State private var query = ""
    @State private var scope = Scope.all
    @State private var results: [Hit] = []
    let openPlayer: () -> Void

    enum Scope: String, CaseIterable {
        case all, arabic, english, french
        var label: String {
            switch self {
            case .all: "All"
            case .arabic: "Arabic"
            case .english: "English"
            case .french: "French"
            }
        }
    }

    struct Hit: Identifiable {
        let surah: Int
        let ayah: Int
        let snippet: String
        let arabic: Bool
        var id: String { "\(surah):\(ayah):\(arabic)" }
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).count < 2 {
                    ContentUnavailableView(
                        "Search the Quran",
                        systemImage: "text.magnifyingglass",
                        description: Text("Search the Arabic and the English and French translations."))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results) { hit in
                        Button {
                            play(hit)
                        } label: {
                            row(hit)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search ayahs")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Scope", selection: $scope) {
                        ForEach(Scope.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }
            }
            .onChange(of: query) { runSearch() }
            .onChange(of: scope) { runSearch() }
        }
    }

    private func row(_ hit: Hit) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(QuranLibrary.surah(hit.surah)?.english ?? "") | Ayah \(hit.ayah)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.green)
                Text(hit.snippet)
                    .font(.subheadline)
                    .lineLimit(3)
                    .multilineTextAlignment(hit.arabic ? .trailing : .leading)
                    .frame(maxWidth: .infinity,
                           alignment: hit.arabic ? .trailing : .leading)
            }
            Image(systemName: "play.circle.fill")
                .foregroundStyle(Theme.green)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func runSearch() {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard needle.count >= 2 else { results = []; return }
        let folded = needle.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                    locale: .current)
        var hits: [Hit] = []
        for (surahNumber, ayahs) in QuranTextData.ayahsBySurah.sorted(by: { $0.key < $1.key }) {
            for ayah in ayahs {
                if scope == .all || scope == .arabic,
                   ayah.ar.contains(needle)
                    || ayah.ar.folding(options: [.diacriticInsensitive], locale: .current)
                        .contains(folded) {
                    hits.append(Hit(surah: surahNumber, ayah: ayah.n,
                                    snippet: ayah.ar, arabic: true))
                } else if scope == .all || scope == .english,
                          ayah.en.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                          locale: .current).contains(folded) {
                    hits.append(Hit(surah: surahNumber, ayah: ayah.n,
                                    snippet: ayah.en, arabic: false))
                } else if scope == .all || scope == .french,
                          let french = QuranFrenchData.text(surah: surahNumber, ayah: ayah.n),
                          french.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                         locale: .current).contains(folded) {
                    hits.append(Hit(surah: surahNumber, ayah: ayah.n,
                                    snippet: french, arabic: false))
                }
                if hits.count >= 200 { break }
            }
            if hits.count >= 200 { break }
        }
        results = hits
    }

    private func play(_ hit: Hit) {
        player.play(surahNumber: hit.surah,
                    queue: QuranLibrary.surahs.map(\.number),
                    contextLabel: "Search")
        let ayahs = QuranTextData.ayahsBySurah[hit.surah] ?? []
        if let index = ayahs.firstIndex(where: { $0.n == hit.ayah }) {
            player.seek(to: quranAyahStartTime(ayahs, index: index,
                                               duration: player.duration))
        }
        openPlayer()
    }
}
