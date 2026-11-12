//
//  NoorTheme.swift
//  Noor Glass
//
//  Standalone theme for Noor Glass, adapted from the color members
//  the Quran player used from Prayer YEG's Theme (Shared/PrayerModels).
//  Only the colors the Quran files reference are carried over; the
//  user-pickable theme system and its AppAppearance store are NOT
//  copied. adaptiveGold here is a fixed dynamic color (deep gold on
//  light surfaces, bright gold on dark surfaces).
//
//  Copyright (c) 2026 c12n Apps
//

import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, opacity: opacity)
    }
}

enum Theme {
    // Phase 2: every value resolves from the current theme
    // (NoorAppearance / NoorPalette). With the default Mosque Green
    // preset these are exactly the phase-1 constants; picking any
    // other preset recolors the whole app, widgets included.
    static var deepGreen: Color { NoorPalette.app.primary }
    static var green: Color {
        Color(uiColor: NoorAppearance.primaryUIColor.lightened(by: 0.14))
    }
    static var gold: Color { NoorPalette.app.accent }
    static var lightGold: Color { NoorPalette.app.accentLight }

    /// Accent that stays readable in both appearances: brightened
    /// on dark surfaces, deepened on light ones (HSB adjustment,
    /// hue preserved, from Prayer YEG's guard logic).
    static var adaptiveGold: Color { NoorPalette.app.accentAdaptive }
}
