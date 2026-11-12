//
//  NoorWidgets.swift
//  Noor Glass Widgets
//
//  Phase-2 widgets (feature 6):
//  - DailyAyahWidget: the day's ayah on the Home Screen (small and
//    medium) and the Lock Screen (rectangular and inline).
//  - ContinueListeningWidget (kind "ContinueListeningWidget", the
//    exact string the player reloads): the last-played surah with
//    its progress, from the App Group snapshot the player writes.
//
//  Colors come from NoorAppearance.effectiveWidgetTheme: the app
//  theme by default ("Match my theme"), or the separate widget
//  palette when the user picks one. Lock Screen widgets are drawn
//  by iOS as a tint, so the accessory views stay monochrome-safe.
//
//  Copyright (c) 2026 c12n Apps
//

import SwiftUI
import WidgetKit

@main
struct NoorWidgets: WidgetBundle {
    var body: some Widget {
        DailyAyahWidget()
        ContinueListeningWidget()
    }
}

// MARK: - Shared colors

/// The widget palette as concrete colors. Home Screen widgets use
/// the dark side of the palette (the card look the app uses for
/// the Daily Ayah card) whatever the phone's appearance.
struct WidgetColors {
    let primary: Color
    let deep: Color
    let accent: Color

    init(_ choice: NoorAppearance.ThemeChoice) {
        let palette = NoorPalette(theme: choice)
        primary = palette.primary
        deep = palette.primaryDarkest
        accent = palette.accent
    }
}

private func currentColors() -> WidgetColors {
    WidgetColors(NoorAppearance.effectiveWidgetTheme)
}

// MARK: - Daily Ayah

struct DailyEntry: TimelineEntry {
    let date: Date
    let ayah: DailyAyah
    let colors: WidgetColors
}

struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: .now, ayah: DailyAyahs.ayah(for: .now),
                   colors: currentColors())
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (DailyEntry) -> Void) {
        completion(DailyEntry(date: .now, ayah: DailyAyahs.ayah(for: .now),
                              colors: currentColors()))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<DailyEntry>) -> Void) {
        let colors = currentColors()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var entries: [DailyEntry] = []
        for offset in 0..<3 {
            if let day = calendar.date(byAdding: .day, value: offset, to: today) {
                entries.append(DailyEntry(date: day,
                                          ayah: DailyAyahs.ayah(for: day),
                                          colors: colors))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct DailyAyahWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Daily Ayah | \(entry.ayah.reference)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Ayah | \(entry.ayah.reference)")
                    .font(.caption2.weight(.bold))
                    .widgetAccentable()
                Text(entry.ayah.english)
                    .font(.caption)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            VStack(alignment: .leading, spacing: 6) {
                header
                Text(entry.ayah.arabic)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                Text(entry.ayah.english)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(3)
            }
            .cardBackground(entry.colors)
        default: // systemSmall
            VStack(alignment: .leading, spacing: 5) {
                header
                Text(entry.ayah.arabic)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                Text(entry.ayah.english)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(4)
                Spacer(minLength: 0)
            }
            .cardBackground(entry.colors)
        }
    }

    private var header: some View {
        HStack {
            Text("Daily Ayah")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(entry.colors.accent)
            Spacer()
            Text(entry.ayah.reference)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

private extension View {
    /// The themed gradient card behind Home Screen widget content.
    func cardBackground(_ colors: WidgetColors) -> some View {
        containerBackground(for: .widget) {
            LinearGradient(colors: [colors.primary, colors.deep],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        }
    }
}

struct DailyAyahWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyAyahWidget", provider: DailyProvider()) {
            DailyAyahWidgetView(entry: $0)
        }
        .configurationDisplayName("Daily Ayah")
        .description("A new ayah every day.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Continue Listening

struct ContinueEntry: TimelineEntry {
    let date: Date
    let has: Bool
    let surah: String
    let arabic: String
    let reciter: String
    let fraction: Double
    let colors: WidgetColors
}

struct ContinueProvider: TimelineProvider {
    private func entry(date: Date) -> ContinueEntry {
        let defaults = NoorAppearance.sharedDefaults
        let duration = defaults.double(forKey: "quran.widget.duration")
        let position = defaults.double(forKey: "quran.widget.position")
        return ContinueEntry(
            date: date,
            has: defaults.bool(forKey: "quran.widget.has"),
            surah: defaults.string(forKey: "quran.widget.surah") ?? "",
            arabic: defaults.string(forKey: "quran.widget.arabic") ?? "",
            reciter: defaults.string(forKey: "quran.widget.reciter") ?? "",
            fraction: duration > 0 ? min(1, max(0, position / duration)) : 0,
            colors: currentColors())
    }

    func placeholder(in context: Context) -> ContinueEntry { entry(date: .now) }

    func getSnapshot(in context: Context,
                     completion: @escaping (ContinueEntry) -> Void) {
        completion(entry(date: .now))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<ContinueEntry>) -> Void) {
        // The app reloads this widget whenever the snapshot changes
        // (WidgetCenter.reloadTimelines in QuranPlayer), so a
        // single entry with no scheduled refresh is right.
        completion(Timeline(entries: [entry(date: .now)], policy: .never))
    }
}

struct ContinueListeningWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ContinueEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Continue Listening")
                    .font(.caption2.weight(.bold))
                    .widgetAccentable()
                if entry.has {
                    Text(entry.surah)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(entry.reciter)
                        .font(.caption2)
                        .lineLimit(1)
                } else {
                    Text("Open Noor Glass and press play")
                        .font(.caption2)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "headphones")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(entry.colors.accent)
                    Text("Continue Listening")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(entry.colors.accent)
                    Spacer()
                }
                if entry.has {
                    Text(entry.arabic)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(1)
                    Text(entry.surah)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(entry.reciter)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                    ProgressView(value: entry.fraction)
                        .tint(entry.colors.accent)
                    if family == .systemMedium {
                        Text("\(Int((entry.fraction * 100).rounded()))% through the surah")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                } else {
                    Text("Nothing played yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Your last surah will wait for you here.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer(minLength: 0)
            }
            .cardBackground(entry.colors)
        }
    }
}

struct ContinueListeningWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ContinueListeningWidget",
                            provider: ContinueProvider()) {
            ContinueListeningWidgetView(entry: $0)
        }
        .configurationDisplayName("Continue Listening")
        .description("Pick up the last surah where you left it.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
