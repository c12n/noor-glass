//
//  NoorAppearance.swift
//  Noor Glass
//
//  Full theming for Noor Glass, modelled on Prayer YEG's proven
//  AppAppearance system (Shared/PrayerModels.swift) and adapted
//  standalone. Unlike Prayer YEG, where the Quran palette was fixed
//  deep green and gold by design, here the theme applies to EVERY
//  surface: library, Now Playing sleeve, lyrics, mini player,
//  Mushaf reader and widgets. Deep green and gold is simply the
//  default preset (Mosque Green), not a hardcode.
//
//  Storage lives in the App Group suite (group.com.c12n.noorglass)
//  so the widget extension reads the same values; when the suite is
//  unavailable (unsigned sideloads before the group is registered
//  in the portal) it falls back to UserDefaults.standard, exactly
//  like Prayer YEG did.
//
//  Target Membership: NoorGlass + NoorGlassWidgets (the store at the
//  bottom is app-only, compiled out for the widget via NOOR_WIDGET).
//
//  Copyright (c) 2026 c12n Apps
//

import Foundation
import SwiftUI
import UIKit
#if !NOOR_WIDGET
import WidgetKit
#endif

// MARK: - UIColor helpers (carried from Prayer YEG)

extension UIColor {
    /// WCAG relative luminance (0 = black, 1 = white).
    var relativeLuminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0 }
        func channel(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    /// WCAG contrast ratio against another color (1...21).
    func contrastRatio(against other: UIColor) -> CGFloat {
        let mine = relativeLuminance
        let theirs = other.relativeLuminance
        return (max(mine, theirs) + 0.05) / (min(mine, theirs) + 0.05)
    }

    /// Blends this color toward `target` in 10% steps until it
    /// reaches the minimum contrast against `background` (or the
    /// target itself). The low-vision guard: a picked color can
    /// never make text unreadable.
    func ensuringContrast(against background: UIColor, minimum: CGFloat,
                          blendToward target: UIColor) -> UIColor {
        if contrastRatio(against: background) >= minimum { return self }
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a),
              target.getRed(&tr, green: &tg, blue: &tb, alpha: &ta) else { return self }
        for step in 1...10 {
            let fraction = CGFloat(step) / 10.0
            let blended = UIColor(
                red: r + (tr - r) * fraction,
                green: g + (tg - g) * fraction,
                blue: b + (tb - b) * fraction,
                alpha: 1)
            if blended.contrastRatio(against: background) >= minimum { return blended }
        }
        return target
    }

    /// HSB lightening (fraction = amount of the way toward full brightness).
    func lightened(by fraction: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h, saturation: s * (1 - fraction * 0.35),
                       brightness: b + (1 - b) * fraction, alpha: 1)
    }

    /// HSB darkening (fraction = amount of the way toward black).
    func darkened(by fraction: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h, saturation: s, brightness: b * (1 - fraction), alpha: 1)
    }

    /// Brighten (in HSB) until the color reads clearly on dark
    /// surfaces: same hue, brightness at least 0.82.
    func adjustedForDarkSurface() -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h, saturation: min(s, 0.9), brightness: max(b, 0.82), alpha: 1)
    }

    /// Deepen (in HSB) until the color reads clearly on white: same
    /// hue, brightness at most 0.42 and saturation at least 0.55.
    func adjustedForLightSurface() -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h, saturation: min(max(s, 0.55), 1.0),
                       brightness: min(b, 0.42), alpha: 1)
    }
}

extension Color {
    /// sRGB hex value of a (solid) color, for persisting picker choices.
    var hexValue: UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (UInt32((r * 255).rounded()) << 16)
            | (UInt32((g * 255).rounded()) << 8)
            | UInt32((b * 255).rounded())
    }
}

// MARK: - Stored appearance

enum NoorAppearance {
    static let appGroupIdentifier = "group.com.c12n.noorglass"

    static let modeKey = "appearance.mode"
    static let accentKey = "appearance.accentHex"
    static let primaryKey = "appearance.primaryHex"
    static let textKey = "appearance.textHex"
    static let presetKey = "appearance.presetId"
    static let iconKey = "appearance.iconName"
    static let widgetColorModeKey = "appearance.widgetColorMode"
    static let widgetHomeThemeKey = "appearance.widgetHomeTheme"

    static let defaultAccentHex: UInt32 = 0xD4AF37
    static let defaultPrimaryHex: UInt32 = 0x0B3D2E
    static let defaultTextHex: UInt32 = 0xFFFFFF

    enum Mode: String, CaseIterable {
        case system, light, dark

        var label: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }

        /// nil = follow the system (no override).
        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static var mode: Mode {
        get { Mode(rawValue: sharedDefaults.string(forKey: modeKey) ?? "") ?? .system }
        set { sharedDefaults.set(newValue.rawValue, forKey: modeKey) }
    }

    private static func hex(forKey key: String, default defaultHex: UInt32) -> UInt32 {
        (sharedDefaults.object(forKey: key) as? NSNumber)?.uint32Value ?? defaultHex
    }

    private static func setHex(_ value: UInt32, forKey key: String) {
        sharedDefaults.set(NSNumber(value: value), forKey: key)
    }

    static func uiColor(forHex hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1)
    }

    static var accentHex: UInt32 {
        get { hex(forKey: accentKey, default: defaultAccentHex) }
        set { setHex(newValue, forKey: accentKey) }
    }

    static var accentUIColor: UIColor { uiColor(forHex: accentHex) }

    static var primaryHex: UInt32 {
        get { hex(forKey: primaryKey, default: defaultPrimaryHex) }
        set { setHex(newValue, forKey: primaryKey) }
    }

    static var primaryUIColor: UIColor { uiColor(forHex: primaryHex) }

    static var textHex: UInt32 {
        get { hex(forKey: textKey, default: defaultTextHex) }
        set { setHex(newValue, forKey: textKey) }
    }

    static var textUIColor: UIColor { uiColor(forHex: textHex) }

    static var presetId: String {
        get { sharedDefaults.string(forKey: presetKey) ?? "preset-mosque" }
        set { sharedDefaults.set(newValue, forKey: presetKey) }
    }

    static var iconName: String? {
        get { sharedDefaults.string(forKey: iconKey) }
        set {
            if let newValue { sharedDefaults.set(newValue, forKey: iconKey) }
            else { sharedDefaults.removeObject(forKey: iconKey) }
        }
    }

    /// The picked text color made safe for its surface (Prayer YEG's
    /// guard, carried verbatim in behaviour): on the deep primary
    /// the default is plain white; a picked color is blended toward
    /// white or black until it reaches ~4.5:1 against its surface.
    static func resolvedTextUIColor(forDarkSurface dark: Bool) -> UIColor {
        let picked = textUIColor
        if dark {
            if sharedDefaults.object(forKey: textKey) == nil { return .white }
            return picked.ensuringContrast(against: primaryUIColor,
                                            minimum: 4.5, blendToward: .white)
        }
        if sharedDefaults.object(forKey: textKey) == nil {
            return primaryUIColor.darkened(by: 0.15)
        }
        if picked.relativeLuminance > 0.75 { return primaryUIColor.darkened(by: 0.15) }
        return picked.ensuringContrast(against: .white, minimum: 4.5, blendToward: .black)
    }

    // MARK: Presets

    /// Accent presets (name, sRGB hex), same swatches as Prayer YEG.
    static let accentPresets: [(name: String, hex: UInt32)] = [
        ("Gold", 0xD4AF37),
        ("Emerald", 0x10B981),
        ("Teal", 0x14B8A6),
        ("Sky", 0x38BDF8),
        ("Blue", 0x3B82F6),
        ("Violet", 0x8B5CF6),
        ("Rose", 0xF43F5E),
        ("Orange", 0xF97316),
    ]

    /// A complete, apply-in-one-tap look: primary + accent + text + mode.
    struct ThemeChoice: Codable, Identifiable, Hashable {
        var id: String
        var name: String
        var primaryHex: UInt32
        var accentHex: UInt32
        var textHex: UInt32
        var modeRaw: String

        var mode: Mode { Mode(rawValue: modeRaw) ?? .system }
    }

    /// The eight Noor Glass presets. Mosque Green is the shipped
    /// default (the Prayer YEG Quran palette, now just one choice).
    static let presetThemes: [ThemeChoice] = [
        ThemeChoice(id: "preset-mosque", name: "Mosque Green",
                    primaryHex: 0x0B3D2E, accentHex: 0xD4AF37,
                    textHex: 0xFFFFFF, modeRaw: "system"),
        ThemeChoice(id: "preset-ocean", name: "Ocean Depths",
                    primaryHex: 0x083344, accentHex: 0x67E8F9,
                    textHex: 0xECFEFF, modeRaw: "dark"),
        ThemeChoice(id: "preset-desert", name: "Desert Dunes",
                    primaryHex: 0x6B4420, accentHex: 0xF2C14E,
                    textHex: 0xFFF8E7, modeRaw: "system"),
        ThemeChoice(id: "preset-emerald", name: "Emerald Night",
                    primaryHex: 0x052E22, accentHex: 0x34D399,
                    textHex: 0xECFDF5, modeRaw: "dark"),
        ThemeChoice(id: "preset-crimson", name: "Crimson Dusk",
                    primaryHex: 0x450A0A, accentHex: 0xFCA5A5,
                    textHex: 0xFEF2F2, modeRaw: "dark"),
        ThemeChoice(id: "preset-sapphire", name: "Sapphire Noor",
                    primaryHex: 0x172554, accentHex: 0x93C5FD,
                    textHex: 0xEFF6FF, modeRaw: "dark"),
        ThemeChoice(id: "preset-plum", name: "Plum Velvet",
                    primaryHex: 0x3B0764, accentHex: 0xF0ABFC,
                    textHex: 0xFAF5FF, modeRaw: "dark"),
        // A true high-contrast theme for low-vision users: pure
        // black surfaces, bright yellow accent, pure white text.
        ThemeChoice(id: "preset-contrast", name: "High Contrast",
                    primaryHex: 0x000000, accentHex: 0xFFD60A,
                    textHex: 0xFFFFFF, modeRaw: "dark"),
    ]

    static func preset(id: String) -> ThemeChoice? {
        presetThemes.first { $0.id == id }
    }

    /// The app's current look as a theme (stable id).
    static var appTheme: ThemeChoice {
        ThemeChoice(
            id: presetId, name: preset(id: presetId)?.name ?? "Custom",
            primaryHex: primaryHex, accentHex: accentHex, textHex: textHex,
            modeRaw: mode.rawValue)
    }

    static func apply(_ theme: ThemeChoice) {
        presetId = theme.id
        primaryHex = theme.primaryHex
        accentHex = theme.accentHex
        textHex = theme.textHex
        mode = theme.mode
    }

    /// Appearance back to the shipped defaults (Mosque Green,
    /// System mode, default icon). Widget color choices are kept.
    static func resetToDefaults() {
        for key in [modeKey, accentKey, primaryKey, textKey, presetKey, iconKey] {
            sharedDefaults.removeObject(forKey: key)
        }
    }

    // MARK: Widget colors

    /// How widget surfaces get their colors: follow the app theme
    /// (default), or wear an independent Home Screen palette. Lock
    /// Screen widgets are rendered by iOS as a tint, so there is no
    /// independent Lock palette: they take the widget accent as
    /// their tint (Settings says this plainly).
    enum WidgetColorMode: String, CaseIterable {
        case match, separate
    }

    static var widgetColorMode: WidgetColorMode {
        get {
            WidgetColorMode(
                rawValue: sharedDefaults.string(forKey: widgetColorModeKey) ?? ""
            ) ?? .match
        }
        set { sharedDefaults.set(newValue.rawValue, forKey: widgetColorModeKey) }
    }

    static var storedWidgetHomeTheme: ThemeChoice? {
        get {
            guard let data = sharedDefaults.data(forKey: widgetHomeThemeKey),
                  let theme = try? JSONDecoder().decode(ThemeChoice.self, from: data)
            else { return nil }
            return theme
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                sharedDefaults.set(data, forKey: widgetHomeThemeKey)
            } else {
                sharedDefaults.removeObject(forKey: widgetHomeThemeKey)
            }
        }
    }

    /// The theme the widgets should wear right now: in Match mode
    /// the app theme; in Separate mode the stored Home theme,
    /// falling back to the app theme until one is picked (so
    /// switching modes never recolors anything on its own).
    static var effectiveWidgetTheme: ThemeChoice {
        switch widgetColorMode {
        case .match: return appTheme
        case .separate: return storedWidgetHomeTheme ?? appTheme
        }
    }
}

// MARK: - Resolved palette

/// A resolved color set for themed surfaces, built from a
/// ThemeChoice. Deep surfaces are the primary color family, so text
/// is resolved against the primary with the ~4.5:1 contrast guard.
struct NoorPalette: Equatable {
    let primaryHex: UInt32
    let accentHex: UInt32
    let textHex: UInt32

    init(theme: NoorAppearance.ThemeChoice) {
        primaryHex = theme.primaryHex
        accentHex = theme.accentHex
        textHex = theme.textHex
    }

    static var app: NoorPalette { NoorPalette(theme: NoorAppearance.appTheme) }
    static var widget: NoorPalette {
        NoorPalette(theme: NoorAppearance.effectiveWidgetTheme)
    }

    var primaryUIColor: UIColor { NoorAppearance.uiColor(forHex: primaryHex) }
    var accentUIColor: UIColor { NoorAppearance.uiColor(forHex: accentHex) }

    var primary: Color { Color(uiColor: primaryUIColor) }
    /// Primary lightened for gradient tops and sleeves.
    var primaryBright: Color { Color(uiColor: primaryUIColor.lightened(by: 0.16)) }
    /// Primary mid-step (between bright and base) for sleeve gradients.
    var primaryMid: Color { Color(uiColor: primaryUIColor.lightened(by: 0.07)) }
    /// Primary darkened for gradient feet and deep cards.
    var primaryDeep: Color { Color(uiColor: primaryUIColor.darkened(by: 0.30)) }
    /// The darkest step, for Now Playing gradient feet.
    var primaryDarkest: Color { Color(uiColor: primaryUIColor.darkened(by: 0.52)) }

    /// The accent as picked.
    var accent: Color { Color(uiColor: accentUIColor) }
    /// The accent brightened for deep surfaces (highlights, progress).
    var accentBright: Color {
        Color(uiColor: accentUIColor.adjustedForDarkSurface())
    }
    /// The accent deepened for light surfaces.
    var accentDeep: Color {
        Color(uiColor: accentUIColor.adjustedForLightSurface())
    }
    /// The accent adjusted per appearance: bright on dark surfaces,
    /// deepened on light ones, so it stays readable in both.
    var accentAdaptive: Color {
        let accent = accentUIColor
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? accent.adjustedForDarkSurface()
                : accent.adjustedForLightSurface()
        })
    }
    /// The accent lightened (the old lightGold role).
    var accentLight: Color { Color(uiColor: accentUIColor.lightened(by: 0.25)) }

    /// Text on primary surfaces, contrast-guarded against primary.
    var textOnPrimaryUIColor: UIColor {
        NoorAppearance.uiColor(forHex: textHex)
            .ensuringContrast(against: primaryUIColor, minimum: 4.5,
                              blendToward: .white)
    }
    var onPrimary: Color { Color(uiColor: textOnPrimaryUIColor) }
    var onPrimarySecondary: Color { onPrimary.opacity(0.85) }
    var onPrimaryMuted: Color { onPrimary.opacity(0.72) }

    /// The library page tint: near-white washed with the primary in
    /// Light Mode, the deep primary in Dark Mode.
    var pageTint: Color {
        let primary = primaryUIColor
        return Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return primary.darkened(by: 0.45)
            }
            // Blend 6% primary into white.
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            primary.getRed(&r, green: &g, blue: &b, alpha: &a)
            return UIColor(red: 0.94 + r * 0.06, green: 0.95 + g * 0.06,
                           blue: 0.94 + b * 0.06, alpha: 1)
        })
    }
}

#if !NOOR_WIDGET
// MARK: - App-side store

/// Observable mirror of NoorAppearance for SwiftUI: every change
/// writes through to the shared suite, bumps `revision` (the root
/// view keys itself on it, so a change re-renders every themed
/// surface at once) and reloads the widget timelines.
final class AppThemeStore: ObservableObject {
    @Published private(set) var revision = 0
    @Published private(set) var presetId: String
    @Published private(set) var mode: NoorAppearance.Mode
    @Published private(set) var accentHex: UInt32
    @Published private(set) var primaryHex: UInt32
    @Published private(set) var widgetColorMode: NoorAppearance.WidgetColorMode
    @Published private(set) var iconName: String?

    init() {
        presetId = NoorAppearance.presetId
        mode = NoorAppearance.mode
        accentHex = NoorAppearance.accentHex
        primaryHex = NoorAppearance.primaryHex
        widgetColorMode = NoorAppearance.widgetColorMode
        iconName = NoorAppearance.iconName
    }

    private func changed() {
        presetId = NoorAppearance.presetId
        mode = NoorAppearance.mode
        accentHex = NoorAppearance.accentHex
        primaryHex = NoorAppearance.primaryHex
        widgetColorMode = NoorAppearance.widgetColorMode
        iconName = NoorAppearance.iconName
        revision += 1
        WidgetCenter.shared.reloadAllTimelines()
    }

    func applyPreset(_ theme: NoorAppearance.ThemeChoice) {
        NoorAppearance.apply(theme)
        changed()
    }

    func setMode(_ newMode: NoorAppearance.Mode) {
        NoorAppearance.mode = newMode
        changed()
    }

    /// Accent-only change (preset swatch or the color wheel): the
    /// preset id becomes "custom" unless the hex matches a preset's
    /// accent AND primary still matches that preset.
    func setAccent(hex: UInt32) {
        NoorAppearance.accentHex = hex
        if let match = NoorAppearance.presetThemes.first(where: {
            $0.accentHex == hex && $0.primaryHex == NoorAppearance.primaryHex
        }) {
            NoorAppearance.presetId = match.id
        } else {
            NoorAppearance.presetId = "custom"
        }
        changed()
    }

    func setWidgetColorMode(_ newMode: NoorAppearance.WidgetColorMode) {
        NoorAppearance.widgetColorMode = newMode
        changed()
    }

    func setWidgetHomeTheme(_ theme: NoorAppearance.ThemeChoice) {
        NoorAppearance.storedWidgetHomeTheme = theme
        changed()
    }

    func setIcon(name: String?) {
        NoorAppearance.iconName = name
        changed()
        UIApplication.shared.setAlternateIconName(name) { _ in }
    }

    func resetToDefaults() {
        NoorAppearance.resetToDefaults()
        setIcon(name: nil)
        changed()
    }
}
#endif
