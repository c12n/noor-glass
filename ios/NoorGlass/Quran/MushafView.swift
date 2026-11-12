//
//  MushafView.swift
//  Noor Glass
//
//  Mushaf read mode (phase 2, feature 1): the Quran as printed in
//  the Madani mushaf, page by page (604 pages). Page contents come
//  from MushafData's generated mapping, so a page here holds
//  exactly the ayahs printed on that page. The Arabic flows as
//  continuous mushaf text with ayah-end markers; below it, the
//  page's ayahs are listed with the chosen translation, and tapping
//  one plays its surah from that ayah (estimated seek, like the
//  lyrics view). The last-read page is remembered.
//
//  Copyright (c) 2026 c12n Apps
//

import SwiftUI

struct MushafView: View {
    @EnvironmentObject private var player: QuranPlayer
    @AppStorage("mushaf.page") private var page = 1
    @AppStorage("quran.translation") private var translationRaw =
        QuranTranslation.english.rawValue
    let openPlayer: () -> Void

    private var translation: QuranTranslation {
        QuranTranslation(rawValue: translationRaw) ?? .english
    }

    private var segments: [MushafData.Segment] {
        MushafData.segmentsByPage[page] ?? []
    }

    private var juz: Int? {
        guard let first = segments.first else { return nil }
        return MushafData.juz(surah: first.surah, ayah: first.fromAyah)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pageHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(segments) { segment in
                            segmentView(segment)
                        }
                        if segments.isEmpty {
                            ContentUnavailableView(
                                "Page unavailable",
                                systemImage: "book.closed",
                                description: Text("The mushaf mapping could not be loaded."))
                        }
                    }
                    .padding(18)
                }
                pageControls
            }
            .background(QuranTheme.pageTint)
            .navigationTitle("Mushaf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    jumpMenu
                }
            }
        }
    }

    // MARK: Header & controls

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Page \(page) of \(MushafData.pageCount)")
                    .font(.headline)
                if let juz {
                    Text("Juz \(juz)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.green)
                }
            }
            Spacer()
            Picker("Translation", selection: $translationRaw) {
                ForEach(QuranTranslation.allCases) { option in
                    Text(option.shortLabel).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var pageControls: some View {
        HStack(spacing: 14) {
            Button {
                if page > 1 { page -= 1 }
            } label: {
                Label("Previous", systemImage: "chevron.backward")
            }
            .disabled(page <= 1)
            Slider(
                value: Binding(get: { Double(page) },
                               set: { page = Int($0.rounded()) }),
                in: 1...Double(MushafData.pageCount), step: 1)
            Button {
                if page < MushafData.pageCount { page += 1 }
            } label: {
                Label("Next", systemImage: "chevron.forward")
            }
            .disabled(page >= MushafData.pageCount)
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var jumpMenu: some View {
        Menu {
            Menu("Go to juz") {
                ForEach(1...30, id: \.self) { juzNumber in
                    Button {
                        if let start = MushafData.juzStartPage(juzNumber) {
                            page = start
                        }
                    } label: {
                        let label = MushafData.juzStartLabel(juzNumber) ?? ""
                        Text("Juz \(juzNumber) | \(label)")
                    }
                }
            }
            Menu("Go to surah") {
                ForEach(QuranLibrary.surahs) { surah in
                    Button {
                        if let start = MushafData.page(surah: surah.number, ayah: 1) {
                            page = start
                        }
                    } label: {
                        Text("\(surah.number). \(surah.english)")
                    }
                }
            }
        } label: {
            Label("Go to", systemImage: "bookmark")
        }
    }

    // MARK: Page content

    @ViewBuilder
    private func segmentView(_ segment: MushafData.Segment) -> some View {
        let surah = QuranLibrary.surah(segment.surah)
        let ayahs = (QuranTextData.ayahsBySurah[segment.surah] ?? [])
            .filter { $0.n >= segment.fromAyah && $0.n <= segment.toAyah }
        VStack(alignment: .leading, spacing: 10) {
            if segment.fromAyah == 1, let surah {
                surahHeader(surah)
            }
            // The mushaf flow: continuous Arabic with ﴿n﴾ markers.
            Text(flowingText(ayahs))
                .font(.title3)
                .lineSpacing(10)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            // The same ayahs with translation; tap to play from there.
            ForEach(ayahs, id: \.n) { ayah in
                Button {
                    playFrom(surah: segment.surah, ayah: ayah.n)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(ayah.n)")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(Theme.adaptiveGold)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.adaptiveGold.opacity(0.15), in: Capsule())
                        Text(translation.text(surah: segment.surah, ayah: ayah.n) ?? ayah.en)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(Theme.green)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func surahHeader(_ surah: QuranSurah) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 2) {
                Text(surah.arabic)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(QuranTheme.deepGreen)
                Text("Surah \(surah.english) | \(surah.ayahs) ayahs | \(surah.revelation)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .background(Theme.adaptiveGold.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func flowingText(_ ayahs: [QuranAyahText]) -> String {
        ayahs.map { "\($0.ar) ﴿\($0.n)﴾" }.joined(separator: " ")
    }

    private func playFrom(surah: Int, ayah: Int) {
        player.play(surahNumber: surah,
                    queue: QuranLibrary.surahs.map(\.number),
                    contextLabel: "Mushaf | Page \(page)")
        let ayahs = QuranTextData.ayahsBySurah[surah] ?? []
        if let index = ayahs.firstIndex(where: { $0.n == ayah }) {
            player.seek(to: quranAyahStartTime(ayahs, index: index,
                                               duration: player.duration))
        }
        openPlayer()
    }
}
